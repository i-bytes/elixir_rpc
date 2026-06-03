#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Client.Registry do
  use GenServer
  require Logger

  @check_interval 30_000
  @initial_check_delay 500
  @retry_check_interval 3_000
  @heartbeat_timeout 15_000
  @max_concurrency 10

  @doc "启动节点注册表进程，接受节点列表"
  def start_link(servers), do: GenServer.start_link(__MODULE__, servers, name: __MODULE__)

  @impl true
  def init(servers) do
    state =
      Map.new(servers, fn {server, nodes} ->
        {server, Map.new(nodes, &{&1, %{healthy: false}})}
      end)

    schedule_check(@initial_check_delay)
    {:ok, state}
  end

  @impl true
  def handle_info(:check_nodes, state) do
    new_state =
      Map.new(state, fn {server, nodes} ->
        {server, check_nodes(nodes)}
      end)

    schedule_check(next_check_interval(new_state))
    {:noreply, new_state}
  end

  defp schedule_check(interval), do: Process.send_after(self(), :check_nodes, interval)

  defp next_check_interval(state) do
    if Enum.any?(state, fn {_server, nodes} -> healthy_nodes_from(nodes) == [] end) do
      @retry_check_interval
    else
      @check_interval
    end
  end

  defp check_nodes(nodes) do
    nodes
    |> Task.async_stream(
      fn {node, info} -> check_heartbeat(node, info) end,
      timeout: @heartbeat_timeout,
      on_timeout: :kill_task,
      max_concurrency: @max_concurrency
    )
    |> Enum.reduce(nodes, fn
      {:ok, {node, updated_info}}, acc ->
        Map.put(acc, node, updated_info)

      {:exit, reason}, acc ->
        Logger.error("[Registry] Heartbeat task failed: #{inspect(reason)}")
        acc
    end)
  end

  defp check_heartbeat(node, %{healthy: old_healthy} = info) do
    healthy =
      case safe_heartbeat(node) do
        {:ok, true} -> true
        _ -> false
      end

    if old_healthy != healthy do
      Logger.warning(
        "[Registry] Node #{inspect(node)} health changed: #{old_healthy} → #{healthy}"
      )
    end

    {node, %{info | healthy: healthy}}
  end

  defp safe_heartbeat(node) do
    try do
      case Bytes.RpcClient.do_call(node, "__internal__", "heartbeat", %{}, %{}) do
        {:ok, %{code: 200}} -> {:ok, true}
        _ -> {:ok, false}
      end
    rescue
      _ -> {:error, :exception}
    catch
      _, _ -> {:error, :throw}
    end
  end

  @doc "返回所有健康的节点名列表"
  def healthy_nodes(server), do: GenServer.call(__MODULE__, {:get_healthy, server})

  def probe_healthy_node(server),
    do: GenServer.call(__MODULE__, {:probe_healthy_node, server}, @heartbeat_timeout + 1_000)

  def probe_healthy_nodes(server),
    do: GenServer.call(__MODULE__, {:probe_healthy_nodes, server}, @heartbeat_timeout + 1_000)

  def mark_node(node, healthy), do: GenServer.cast(__MODULE__, {:mark_node, node, healthy})

  @impl true
  def handle_call({:get_healthy, server}, _from, state) do
    healthy_nodes = Map.get(state, server, %{}) |> healthy_nodes_from()
    {:reply, healthy_nodes, state}
  end

  @impl true
  def handle_call({:probe_healthy_node, server}, _from, state) do
    case Map.fetch(state, server) do
      {:ok, nodes} ->
        updated_nodes = check_nodes(nodes)

        reply =
          case healthy_nodes_from(updated_nodes) do
            [] -> {:error, "No service available"}
            nodes -> {:ok, Enum.random(nodes)}
          end

        {:reply, reply, Map.put(state, server, updated_nodes)}

      :error ->
        {:reply, {:error, "No service available"}, state}
    end
  end

  @impl true
  def handle_call({:probe_healthy_nodes, server}, _from, state) do
    case Map.fetch(state, server) do
      {:ok, nodes} ->
        updated_nodes = check_nodes(nodes)

        reply =
          case healthy_nodes_from(updated_nodes) do
            [] -> {:error, "No service available"}
            nodes -> {:ok, nodes}
          end

        {:reply, reply, Map.put(state, server, updated_nodes)}

      :error ->
        {:reply, {:error, "No service available"}, state}
    end
  end

  @impl true
  def handle_cast({:mark_node, node, healthy}, state) do
    {:noreply, update_node_health(state, node, healthy)}
  end

  defp healthy_nodes_from(nodes) do
    for {node, %{healthy: true}} <- nodes, do: node
  end

  defp update_node_health(state, node, healthy) do
    Map.new(state, fn {server, nodes} ->
      {server,
       if Map.has_key?(nodes, node) do
         Map.update!(nodes, node, fn info ->
           if info.healthy != healthy do
             Logger.warning(
               "[Registry] Node #{inspect(node)} health changed: #{info.healthy} → #{healthy}"
             )
           end

           %{info | healthy: healthy}
         end)
       else
         nodes
       end}
    end)
  end
end

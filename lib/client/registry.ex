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

    send(self(), :check_nodes)
    {:ok, state}
  end

  @impl true
  def handle_info(:check_nodes, state) do
    new_state =
      Map.new(state, fn {server, nodes} ->
        updated_nodes =
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

        {server, updated_nodes}
      end)

    schedule_check()
    {:noreply, new_state}
  end

  defp schedule_check, do: Process.send_after(self(), :check_nodes, @check_interval)

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

  @impl true
  def handle_call({:get_healthy, server}, _from, state) do
    healthy_nodes = for {node, %{healthy: true}} <- Map.get(state, server, %{}), do: node
    {:reply, healthy_nodes, state}
  end
end

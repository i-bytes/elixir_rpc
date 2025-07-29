defmodule Bytes.Client.Registry do
  use GenServer
  require Logger

  @check_interval 30_000
  @heartbeat_timeout 15_000
  @max_concurrency 10

  @doc "启动节点注册表进程，接受节点列表"
  def start_link(nodes), do: GenServer.start_link(__MODULE__, nodes, name: __MODULE__)

  @impl true
  def init(nodes) do
    state = Map.new(nodes, fn node -> {node, %{healthy: false}} end)
    send(self(), :check_nodes)
    {:ok, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_nodes, @check_interval)
  end

  @impl true
  def handle_info(:check_nodes, state) do
    new_state =
      state
      |> Map.to_list()
      |> Task.async_stream(
        fn {node, info} -> check_heartbeat(node, info) end,
        timeout: @heartbeat_timeout,
        on_timeout: :kill_task,
        max_concurrency: @max_concurrency
      )
      |> Enum.reduce(state, fn
        {:ok, {node, updated_info}}, acc ->
          Map.put(acc, node, updated_info)

        {:exit, reason}, acc ->
          Logger.error("[Registry] Heartbeat task failed: #{inspect(reason)}")
          acc
      end)

    schedule_check()
    {:noreply, new_state}
  end

  defp check_heartbeat(node, %{healthy: old_healthy} = info) do
    healthy =
      try do
        case Bytes.RpcClient.call(node, "__internal__", "heartbeat", %{}, %{}) do
          {:ok, %{code: 0}} -> true
          _ -> false
        end
      rescue
        _ -> false
      catch
        _, _ -> false
      end

    if old_healthy != healthy do
      Logger.warning(
        "[Registry] Node #{inspect(node)} health changed: #{old_healthy} → #{healthy}"
      )
    end

    {node, %{info | healthy: healthy}}
  end

  @doc "返回所有健康的节点名列表"
  def healthy_nodes, do: GenServer.call(__MODULE__, :get_healthy)

  @impl true
  def handle_call(:get_healthy, _from, state) do
    healthy_nodes = for {node, %{healthy: true}} <- state, do: node
    {:reply, healthy_nodes, state}
  end
end

defmodule ElixirRpc.TestSupport do
  alias Bytes.Rpc.Context

  @existing_module :sample_rpc_module
  @existing_event :sample_rpc_event
  @raising_event :raising_rpc_event

  def existing_module, do: @existing_module
  def existing_event, do: @existing_event
  def raising_event, do: @raising_event

  defmodule ServiceModule do
    def sample_rpc_event(%Context{}), do: {:ok, %{code: 200, message: "ok"}}
    def raising_rpc_event(%Context{}), do: raise("boom")
  end

  defmodule AddMiddleware do
    def pre(ctx), do: {:ok, Map.update(ctx, :steps, [:pre_add], &(&1 ++ [:pre_add]))}
    def post(_ctx, acc), do: acc ++ [:post_add]
  end

  defmodule StopMiddleware do
    def pre(_ctx), do: {:error, :stopped}
    def post(_ctx, acc), do: acc ++ [:post_stop]
  end

  defmodule RaiseMiddleware do
    def pre(_ctx), do: raise("pre failed")
    def post(_ctx, _acc), do: raise("post failed")
  end

  defmodule EchoGenServer do
    use GenServer

    def start_link(parent), do: GenServer.start_link(__MODULE__, parent)
    def init(parent), do: {:ok, parent}

    def handle_call(msg, _from, parent) do
      send(parent, {:echo_call, msg})
      {:reply, :echo_reply, parent}
    end

    def handle_cast(msg, parent) do
      send(parent, {:echo_cast, msg})
      {:noreply, parent}
    end
  end

  defmodule PoolWorker do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
    def init(opts), do: {:ok, opts}

    def handle_call({:rpc_call, "__internal__", "heartbeat", _header, _body}, _from, state) do
      {:reply, {:ok, %{code: 200}}, state}
    end

    def handle_call({:rpc_call, module, event, header, body}, _from, state) do
      {:reply, {:ok, {module, event, header, body}}, state}
    end

    def handle_cast({:rpc_cast, module, event, header, body}, state) do
      send(self(), {:cast_seen, module, event, header, body})
      {:noreply, state}
    end

    def handle_info(_msg, state), do: {:noreply, state}
  end

  def start_test_pool(node) do
    pool_name = String.to_atom("rpc_pool_#{node}")

    {:ok, pid} =
      :poolboy.start_link(
        [
          name: {:local, pool_name},
          worker_module: PoolWorker,
          size: 1,
          max_overflow: 0
        ],
        to: node,
        host: "localhost",
        port: 1,
        from: "client"
      )

    ExUnit.Callbacks.on_exit(fn -> stop_process(pid) end)

    pool_name
  end

  def free_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  def start_grpc_server do
    port = free_port()
    {:ok, pid, _ref} = GRPC.Server.start(Bytes.Rpc.Server.Dispatcher, port)

    ExUnit.Callbacks.on_exit(fn -> stop_process(pid) end)

    port
  end

  def stop_process(pid) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        1_000 -> Process.demonitor(ref, [:flush])
      end
    end

    :ok
  end
end

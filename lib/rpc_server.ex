#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.RpcServer do
  use GenServer
  require Logger

  alias Bytes.Rpc.Server.{Cache, Dispatcher}

  @name __MODULE__

  @default_middlewares [
    Bytes.Rpc.CodecMiddleware,
    Bytes.Rpc.LoggerMiddleware
  ]

  @default_port 50051

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  ## Server Callbacks

  def init(_opts) do
    config = Application.get_env(:elixir_rpc, __MODULE__, [])

    port = Keyword.get(config, :port, @default_port)
    services = Map.new(Keyword.get(config, :services, []))
    middlewares = Keyword.get(config, :middlewares, @default_middlewares)

    Logger.info("[RpcServer] Starting gRPC server on port #{port}")

    with :ok <- Cache.init_cache(services, middlewares),
         {:ok, pid, _ref} <- GRPC.Server.start(Dispatcher, port) do
      Logger.info("[RpcServer] gRPC server started (PID: #{inspect(pid)})")
      {:ok, %{port: port, pid: pid, services: services, middlewares: middlewares}}
    else
      {:error, reason} ->
        Logger.error("[RpcServer] Failed to start gRPC server: #{inspect(reason)}")
        {:stop, reason}

      _ ->
        Logger.error("[RpcServer] Unknown error during gRPC start")
        {:stop, :unknown}
    end
  end

  def handle_call(:info, _from, state) do
    {:reply, %{port: state.port, pid: state.pid}, state}
  end

  def handle_call(_msg, _from, state), do: {:reply, :ok, state}
  def handle_cast(_msg, state), do: {:noreply, state}

  def terminate(_reason, %{pid: pid}) do
    Logger.info("[RpcServer] Shutting down gRPC server...")
    if Process.alive?(pid), do: Process.exit(pid, :normal)
    :ok
  end
end

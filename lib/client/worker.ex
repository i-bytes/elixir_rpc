#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Client.Worker do
  use GenServer
  require Logger
  alias Bytes.Rpc.{Meta, Request, Response, Json}
  alias Bytes.Rpc.Route.Stub

  @reconnect_interval 3_000

  def rpc_call(pid, service, event, header, body) do
    GenServer.call(pid, {:rpc_call, service, event, header, body})
  end

  def rpc_cast(pid, service, event, header, body) do
    GenServer.cast(pid, {:rpc_cast, service, event, header, body})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    state = %{
      host: Keyword.get(opts, :host),
      port: Keyword.get(opts, :port),
      node: Keyword.get(opts, :node),
      channel: nil,
      connecting: true
    }

    send(self(), :connect)
    {:ok, state}
  end

  def handle_info(:connect, %{connecting: true} = state) do
    close_channel(state.channel)

    case GRPC.Stub.connect("#{state.host}:#{state.port}") do
      {:ok, channel} ->
        Logger.info("[RpcWorker:#{state.node}] Connected to #{state.host}:#{state.port}")
        {:noreply, %{state | channel: channel, connecting: false}}

      {:error, reason} ->
        Logger.error(
          "[RpcWorker:#{state.node}] Connection failed: #{inspect(reason)}. Retrying in #{@reconnect_interval}ms"
        )

        Process.send_after(self(), :connect, @reconnect_interval)
        {:noreply, %{state | channel: nil}}
    end
  end

  def handle_info({:gun_down, _, _, :closed, []}, state) do
    Logger.warning("[RpcWorker:#{state.node}] Disconnected from server, scheduling reconnect...")
    {:noreply, maybe_schedule_connect(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_call(_, _from, %{channel: nil} = state) do
    {:reply, {:error, :not_connected}, maybe_schedule_connect(state)}
  end

  def handle_call(
        {:rpc_call, module, event, header, body},
        _from,
        %{channel: channel, node: node} = state
      ) do
    request = %Request{
      meta: %Meta{module: module, event: event, node: node},
      header: Json.encode(header),
      body: Json.encode(body)
    }

    case Stub.dispatcher(channel, request) do
      {:ok, %Response{code: code, message: msg, data: data}} ->
        {:reply, {:ok, %{code: code, message: msg, data: Json.decode!(data)}}, state}

      {:error, reason} ->
        Logger.warning("[RpcWorker:#{node}] RPC failed: #{inspect(reason)}")
        {:reply, {:error, reason}, maybe_schedule_connect(state)}
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, {:error, :unknown}, state}
  end

  def handle_cast(_, %{channel: nil} = state) do
    {:noreply, maybe_schedule_connect(state)}
  end

  def handle_cast(
        {:rpc_cast, module, event, header, body},
        %{channel: channel, node: node} = state
      ) do
    request = %Request{
      meta: %Meta{module: module, event: event, node: node},
      header: Json.encode(header),
      body: Json.encode(body)
    }

    Task.start(fn ->
      try do
        Stub.dispatcher(channel, request)
      rescue
        err -> Logger.error("[RpcWorker:#{node}] Cast failed: #{inspect(err)}")
      end
    end)

    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    close_channel(state.channel)
    :ok
  end

  defp maybe_schedule_connect(%{connecting: true} = state), do: state

  defp maybe_schedule_connect(state) do
    send(self(), :connect)
    %{state | connecting: true}
  end

  defp close_channel(nil), do: :ok

  defp close_channel(channel) do
    try do
      GRPC.Stub.disconnect(channel)
    rescue
      _ -> :ok
    end
  end
end

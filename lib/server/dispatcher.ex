#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Server.Dispatcher do
  require Logger

  use GRPC.Server, service: Bytes.Rpc.Route.Service
  alias Bytes.Rpc.{Context, Response, Request}
  alias Bytes.Rpc.Server.{Middleware, Cache}

  @spec dispatcher(Request.t(), GRPC.Server.Stream.t()) :: Response.t()
  def dispatcher(%Request{meta: %{service: "__internal__", event: "heartbeat"}}, _stream) do
    %Response{code: 200}
  end

  def dispatcher(%Request{} = req, _stream) do
    case Middleware.process_request(req) do
      {:ok, %Context{meta: %{service: s, event: event}} = ctx} ->
        service = Cache.get_module(s)

        result =
          try do
            apply(service, event, [ctx])
          rescue
            error ->
              Logger.error("""
              [RpcDispatcher] Exception in #{service}.#{event}:
              #{Exception.format(:error, error, __STACKTRACE__)}
              """)

              %Response{code: 501, message: "Event not supported"}
          end

        Middleware.process_response(ctx, result)

      {:error, reason} ->
        Logger.warning("[RpcDispatcher] Middleware rejected request: #{inspect(reason)}")
        %Response{code: 400, message: "Bad Request"}
    end
  end
end

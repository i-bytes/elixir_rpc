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

  @ok %Response{code: 0}
  @error %Response{code: 500, message: "Internal Server Error"}
  @bad_request %Response{code: 400, message: "Bad Request"}
  @not_supported %Response{code: 501, message: "Event not supported"}

  @spec dispatcher(Request.t(), GRPC.Server.Stream.t()) :: Response.t()
  def dispatcher(%Request{meta: %{module: "__internal__", event: "heartbeat"}}, _stream),
    do: @ok

  def dispatcher(%Request{} = req, _stream) do
    with {:ok, %Context{meta: %{module: name, event: event}} = ctx} <-
           Middleware.process_request(req),
         module when not is_nil(module) <- Cache.get_module(name) do
      result =
        try do
          apply(module, event, [ctx])
        rescue
          error ->
            Logger.error("""
            [RpcDispatcher] Exception in #{module}.#{event}:
            #{Exception.format(:error, error, __STACKTRACE__)}
            """)

            @error
        end

      Middleware.process_response(ctx, result)
    else
      {:error, reason} ->
        Logger.warning("[RpcDispatcher] Middleware rejected request: #{inspect(reason)}")
        @bad_request

      nil ->
        @not_supported
    end
  end
end

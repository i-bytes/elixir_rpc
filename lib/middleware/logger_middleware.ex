#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.LoggerMiddleware do
  @behaviour Bytes.Rpc.Middleware

  require Logger
  alias Bytes.Rpc.{Context}

  def pre(%Context{header: header, body: body} = ctx) do
    trace_id = extract_or_generate_trace_id(header)
    start_time = System.monotonic_time()
    %{module: module, event: event, node: node} = ctx.meta

    Task.start(fn ->
      Logger.info(%{
        action: :rpc_request,
        id: trace_id,
        from: node,
        module: module,
        event: event,
        header: header,
        request: body
      })
    end)

    {:ok, %Context{ctx | request_time: start_time, trace_id: trace_id}}
  end

  def pre(_), do: {:error, :invalid_request}

  def post(ctx, resp) do
    log_response(ctx, resp)
    resp
  end

  defp log_response(%Context{meta: %{module: module, event: event, node: node}} = ctx, data) do
    trace_id = ctx.trace_id
    start_time = ctx.request_time || System.monotonic_time()
    duration = System.monotonic_time() - start_time

    Task.start(fn ->
      Logger.info(%{
        action: :rpc_response,
        id: trace_id,
        to: node,
        module: module,
        event: event,
        response: data,
        time: "#{duration}μs"
      })
    end)
  end

  defp extract_or_generate_trace_id(headers) when is_map(headers) do
    case Map.get(headers, "trace_id") do
      id when is_binary(id) -> id
      _ -> generate_trace_id()
    end
  end

  defp extract_or_generate_trace_id(_), do: generate_trace_id()

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end

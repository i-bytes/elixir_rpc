#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Middleware do
  @moduledoc "gRPC RPC中间件行为定义"

  @callback pre(map()) :: {:ok, any()} | {:error, any()}
  @callback post(map(), {:ok, any()} | {:error, any()}) :: {:ok, any()} | {:error, any()}

  defmacro __using__(_) do
    quote do
      @behaviour Bytes.Rpc.Middleware

      @impl true
      def pre(ctx), do: {:ok, ctx}
      @impl true
      def post(ctx, result), do: result
      defoverridable pre: 1
      defoverridable post: 2
    end
  end
end

#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Server.Middleware do
  @moduledoc """
  Handles middleware execution for RPC request and response.

  - `process_request/1`: Applies `pre/1` in order, short-circuit on error.
  - `process_response/2`: Applies `post/2` in reverse order.
  """

  require Logger
  alias Bytes.Rpc.Server.Cache

  @spec process_request(map()) :: {:ok, map()} | {:error, any()}
  def process_request(ctx) do
    Cache.get_middlewares(:asc)
    |> Enum.reduce_while({:ok, ctx}, fn middleware, {:ok, ctx} ->
      try do
        case middleware.pre(ctx) do
          {:ok, new_ctx} ->
            {:cont, {:ok, new_ctx}}

          {:error, reason} ->
            Logger.warning("[Middleware] #{inspect(middleware)} pre/1 failed: #{inspect(reason)}")
            {:halt, {:error, reason}}
        end
      rescue
        error ->
          Logger.error(
            "[Middleware] Exception in #{inspect(middleware)} pre/1: #{Exception.format(:error, error, __STACKTRACE__)}"
          )

          {:halt, {:error, :middleware_exception}}
      end
    end)
  end

  @spec process_response(map(), any()) :: any()
  def process_response(ctx, result) do
    Cache.get_middlewares(:desc)
    |> Enum.reduce(result, fn middleware, acc ->
      try do
        middleware.post(ctx, acc)
      rescue
        error ->
          Logger.error(
            "[Middleware] Exception in #{inspect(middleware)} post/2: #{Exception.format(:error, error, __STACKTRACE__)}"
          )

          acc
      end
    end)
  end
end

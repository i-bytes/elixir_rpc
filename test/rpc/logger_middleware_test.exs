defmodule Bytes.Rpc.LoggerMiddlewareTest do
  use ExUnit.Case

  alias Bytes.Rpc.{Context, Response}

  @existing_module ElixirRpc.TestSupport.existing_module()
  @existing_event ElixirRpc.TestSupport.existing_event()

  test "pre accepts context and post returns response unchanged" do
    ctx = %Context{
      meta: %{module: @existing_module, event: @existing_event, node: "client"},
      header: %{"trace_id" => "trace-1"},
      body: %{code: 200}
    }

    assert {:ok, new_ctx} = Bytes.Rpc.LoggerMiddleware.pre(ctx)
    assert new_ctx.trace_id == "trace-1"
    assert is_integer(new_ctx.request_time)

    resp = %Response{code: 200}
    assert ^resp = Bytes.Rpc.LoggerMiddleware.post(new_ctx, resp)
  end

  test "pre rejects invalid context and generates trace id when missing" do
    assert {:error, :invalid_request} = Bytes.Rpc.LoggerMiddleware.pre(%{})

    ctx = %Context{
      meta: %{module: @existing_module, event: @existing_event, node: "client"},
      header: %{},
      body: %{}
    }

    assert {:ok, new_ctx} = Bytes.Rpc.LoggerMiddleware.pre(ctx)
    assert byte_size(new_ctx.trace_id) == 32
  end
end

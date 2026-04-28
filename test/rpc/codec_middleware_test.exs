defmodule Bytes.Rpc.CodecMiddlewareTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Bytes.Rpc.{CodecMiddleware, Json, Meta, Request, Response}

  @existing_module ElixirRpc.TestSupport.existing_module()
  @existing_event ElixirRpc.TestSupport.existing_event()

  test "keeps compatible string module and event names when atoms already exist" do
    req = %Request{
      meta: %Meta{
        module: Atom.to_string(@existing_module),
        event: Atom.to_string(@existing_event),
        node: "client"
      },
      header: Jason.encode!(%{"trace_id" => "abc"}),
      body: Jason.encode!(%{"code" => 200})
    }

    assert {:ok, ctx} = CodecMiddleware.pre(req)
    assert ctx.meta.module == @existing_module
    assert ctx.meta.event == @existing_event
    assert ctx.meta.node == "client"
    assert ctx.header.trace_id == "abc"
    assert ctx.body.code == 200
  end

  test "rejects unknown module atoms without creating them" do
    unknown_module = "rpc_unknown_module_#{System.unique_integer([:positive])}"

    req = %Request{
      meta: %Meta{
        module: unknown_module,
        event: Atom.to_string(@existing_event),
        node: "client"
      },
      header: "{}",
      body: "{}"
    }

    log =
      capture_log(fn ->
        assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_module) end
        assert {:error, :unknown_atom} = CodecMiddleware.pre(req)
        assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_module) end
      end)

    assert log =~ "decode failed"
  end

  test "normalizes supported response tuples" do
    assert %Response{code: 200, message: "success"} = CodecMiddleware.post(%{}, :ok)

    assert %Response{code: 200, data: data} = CodecMiddleware.post(%{}, {:ok, %{code: 200}})
    assert Json.decode!(data).code == 200

    assert %Response{code: 1, message: "bad"} = CodecMiddleware.post(%{}, {:error, :bad})
    assert %Response{code: 200} = CodecMiddleware.post(%{}, :other)
  end

  test "rejects invalid request format" do
    assert {:error, :invalid_format} = CodecMiddleware.pre(%{})
  end

  test "rejects non string and non atom module or event values" do
    req = %Request{
      meta: %{module: @existing_module, event: 123, node: "client"},
      header: "{}",
      body: "{}"
    }

    assert {:error, :invalid_atom} = CodecMiddleware.pre(req)
  end
end

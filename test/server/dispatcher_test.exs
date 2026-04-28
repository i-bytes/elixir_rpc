defmodule Bytes.Rpc.Server.DispatcherTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Bytes.Rpc.Server.Cache
  alias Bytes.Rpc.{CodecMiddleware, Json, Meta, Request, Response}
  alias ElixirRpc.TestSupport.ServiceModule

  @existing_module ElixirRpc.TestSupport.existing_module()
  @existing_event ElixirRpc.TestSupport.existing_event()
  @raising_event ElixirRpc.TestSupport.raising_event()

  test "responds to heartbeat without middleware setup" do
    req = %Request{meta: %Meta{module: "__internal__", event: "heartbeat"}}

    assert %Response{code: 200} = Bytes.Rpc.Server.Dispatcher.dispatcher(req, nil)
  end

  test "dispatches supported service events through middleware" do
    Cache.init_cache(%{@existing_module => ServiceModule}, [CodecMiddleware])

    req = request(@existing_module, @existing_event)

    assert %Response{code: 200, data: data} = Bytes.Rpc.Server.Dispatcher.dispatcher(req, nil)
    assert Json.decode!(data).code == 200
    assert Json.decode!(data).message == "ok"
  end

  test "returns not supported for unknown module and bad request for invalid request" do
    Cache.init_cache(%{}, [CodecMiddleware])

    assert %Response{code: 501} =
             Bytes.Rpc.Server.Dispatcher.dispatcher(
               request(@existing_module, @existing_event),
               nil
             )

    invalid_req = %Request{
      meta: %Meta{
        module: "unknown_module_#{System.unique_integer([:positive])}",
        event: Atom.to_string(@existing_event),
        node: "client"
      },
      header: "{}",
      body: "{}"
    }

    assert %Response{code: 400} = Bytes.Rpc.Server.Dispatcher.dispatcher(invalid_req, nil)
  end

  test "converts service exceptions to error response" do
    Cache.init_cache(%{@existing_module => ServiceModule}, [CodecMiddleware])

    log =
      capture_log(fn ->
        assert %Response{code: 500} =
                 Bytes.Rpc.Server.Dispatcher.dispatcher(
                   request(@existing_module, @raising_event),
                   nil
                 )
      end)

    assert log =~ "Exception in"
  end

  defp request(module, event) do
    %Request{
      meta: %Meta{
        module: Atom.to_string(module),
        event: Atom.to_string(event),
        node: "client"
      },
      header: "{}",
      body: "{}"
    }
  end
end

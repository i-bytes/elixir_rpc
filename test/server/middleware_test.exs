defmodule Bytes.Rpc.Server.MiddlewareTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Bytes.Rpc.Server.{Cache, Middleware}
  alias ElixirRpc.TestSupport.{AddMiddleware, RaiseMiddleware, StopMiddleware}

  test "process_request runs middleware in order" do
    Cache.init_cache(%{}, [AddMiddleware, AddMiddleware])

    assert {:ok, %{steps: [:pre_add, :pre_add]}} = Middleware.process_request(%{})
  end

  test "process_request stops on middleware error" do
    Cache.init_cache(%{}, [AddMiddleware, StopMiddleware, AddMiddleware])

    log =
      capture_log(fn ->
        assert {:error, :stopped} = Middleware.process_request(%{})
      end)

    assert log =~ "pre/1 failed"
  end

  test "process_request converts middleware exceptions to middleware_exception" do
    Cache.init_cache(%{}, [RaiseMiddleware])

    log =
      capture_log(fn ->
        assert {:error, :middleware_exception} = Middleware.process_request(%{})
      end)

    assert log =~ "Exception in"
  end

  test "process_response runs middleware in reverse order and keeps accumulator after exception" do
    Cache.init_cache(%{}, [AddMiddleware, RaiseMiddleware, StopMiddleware])

    log =
      capture_log(fn ->
        assert [:start, :post_stop, :post_add] = Middleware.process_response(%{}, [:start])
      end)

    assert log =~ "Exception in"
  end
end

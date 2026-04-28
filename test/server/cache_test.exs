defmodule Bytes.Rpc.Server.CacheTest do
  use ExUnit.Case

  alias Bytes.Rpc.Server.Cache
  alias ElixirRpc.TestSupport.{AddMiddleware, ServiceModule, StopMiddleware}

  @existing_module ElixirRpc.TestSupport.existing_module()

  test "stores modules and middleware order" do
    Cache.init_cache(%{@existing_module => ServiceModule}, [AddMiddleware, StopMiddleware])

    assert Cache.get_module(@existing_module) == ServiceModule
    assert Cache.get_module(:missing_module) == nil
    assert Cache.get_middlewares(:asc) == [AddMiddleware, StopMiddleware]
    assert Cache.get_middlewares(:desc) == [StopMiddleware, AddMiddleware]
  end
end

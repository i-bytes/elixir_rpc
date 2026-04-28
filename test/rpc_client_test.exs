defmodule Bytes.RpcClientTest do
  use ExUnit.Case

  alias Bytes.Client.Registry

  @existing_module ElixirRpc.TestSupport.existing_module()
  @existing_event ElixirRpc.TestSupport.existing_event()

  test "call and cast use direct node after registry marks it healthy" do
    node = "unit_client_node"

    start_supervised!({Registry, ws: [node]})
    ElixirRpc.TestSupport.start_test_pool(node)

    Registry.mark_node(node, true)

    assert {:ok, {@existing_module, @existing_event, %{}, %{}}} =
             Bytes.RpcClient.call(:ws, @existing_module, @existing_event, %{}, %{})

    assert :ok = Bytes.RpcClient.cast(:ws, @existing_module, @existing_event, %{}, %{})
  end

  test "do_call and do_cast use the configured node pool directly" do
    node = "unit_direct_node"
    ElixirRpc.TestSupport.start_test_pool(node)

    assert {:ok, {@existing_module, @existing_event, %{}, %{}}} =
             Bytes.RpcClient.do_call(node, @existing_module, @existing_event, %{}, %{})

    assert :ok = Bytes.RpcClient.do_cast(node, @existing_module, @existing_event, %{}, %{})
  end

  test "do_call uses configured timeout for pool transaction and worker call" do
    node = "unit_timeout_node"
    ElixirRpc.TestSupport.start_test_pool(node)

    with_client_config([timeout: 250, servers: []], fn ->
      assert {:ok, {@existing_module, @existing_event, %{}, %{}}} =
               Bytes.RpcClient.do_call(node, @existing_module, @existing_event, %{}, %{})
    end)
  end

  test "init builds supervisor children from configured servers" do
    with_client_config(
      [
        name: "client",
        servers: [ws: [{"ws1", "localhost", 50051}], live: []],
        pool_size: 2,
        max_overflow: 1,
        timeout: 750
      ],
      fn ->
        assert {:ok, {_flags, children}} = Bytes.RpcClient.init([])
        assert length(children) == 2
      end
    )
  end

  test "start_link can start with empty server configuration" do
    with_client_config(
      [
        name: "client",
        servers: [],
        pool_size: 1,
        max_overflow: 0
      ],
      fn ->
        assert {:ok, pid} = Bytes.RpcClient.start_link([])
        assert Process.alive?(pid)
        Supervisor.stop(pid)
      end
    )
  end

  test "broadcast returns ok when there are no healthy nodes" do
    start_supervised!({Registry, ws: ["ws1"]})

    assert :ok = Bytes.RpcClient.broadcast(:ws, @existing_module, @existing_event, %{}, %{})
  end

  test "broadcast starts cast tasks for healthy nodes" do
    node = "unit_broadcast_node"

    start_supervised!({Registry, ws: [node]})
    ElixirRpc.TestSupport.start_test_pool(node)
    Registry.mark_node(node, true)

    assert :ok = Bytes.RpcClient.broadcast(:ws, @existing_module, @existing_event, %{}, %{})
    Process.sleep(20)
  end

  defp with_client_config(config, fun) do
    old_config = Application.get_env(:elixir_rpc, Bytes.RpcClient)

    Application.put_env(:elixir_rpc, Bytes.RpcClient, config)

    try do
      fun.()
    after
      if old_config do
        Application.put_env(:elixir_rpc, Bytes.RpcClient, old_config)
      else
        Application.delete_env(:elixir_rpc, Bytes.RpcClient)
      end
    end
  end
end

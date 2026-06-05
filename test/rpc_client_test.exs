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

  test "call_all calls every healthy node in a server group" do
    nodes = ["unit_call_all_node_1", "unit_call_all_node_2"]

    start_supervised!({Registry, ws: nodes})
    Enum.each(nodes, &ElixirRpc.TestSupport.start_test_pool/1)
    Enum.each(nodes, &Registry.mark_node(&1, true))

    assert {:ok, results} =
             Bytes.RpcClient.call_all(:ws, @existing_module, @existing_event, %{}, %{})

    assert Map.new(results) ==
             Map.new(nodes, fn node ->
               {node, {:ok, {@existing_module, @existing_event, %{}, %{}}}}
             end)
  end

  test "call_all probes and calls every reachable node when registry has no healthy nodes" do
    nodes = ["unit_call_all_probe_node_1", "unit_call_all_probe_node_2"]

    start_supervised!({Registry, ws: nodes})
    Enum.each(nodes, &ElixirRpc.TestSupport.start_test_pool/1)

    assert {:ok, results} =
             Bytes.RpcClient.call_all(:ws, @existing_module, @existing_event, %{}, %{})

    assert Map.keys(Map.new(results)) |> Enum.sort() == nodes
  end

  test "cast_all casts every healthy node in a server group" do
    nodes = ["unit_cast_all_node_1", "unit_cast_all_node_2"]

    start_supervised!({Registry, ws: nodes})
    Enum.each(nodes, &ElixirRpc.TestSupport.start_test_pool/1)
    Enum.each(nodes, &Registry.mark_node(&1, true))

    assert :ok = Bytes.RpcClient.cast_all(:ws, @existing_module, @existing_event, %{}, %{})
    Process.sleep(20)
  end

  test "call_all and cast_all preserve the no-service error shape" do
    start_supervised!({Registry, ws: ["unit_missing_all_node"]})

    assert {:error, "No service available"} =
             Bytes.RpcClient.call_all(:ws, @existing_module, @existing_event, %{}, %{})

    assert {:error, "No service available"} =
             Bytes.RpcClient.cast_all(:ws, @existing_module, @existing_event, %{}, %{})
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

defmodule Bytes.Client.RegistryTest do
  use ExUnit.Case

  alias Bytes.Client.{Dispatcher, Registry}

  @existing_module ElixirRpc.TestSupport.existing_module()
  @existing_event ElixirRpc.TestSupport.existing_event()

  setup do
    start_supervised!({Registry, ws: ["ws1", "ws2"], live: ["live1"]})
    :ok
  end

  test "mark_node updates only configured nodes" do
    assert Registry.healthy_nodes(:ws) == []
    assert Registry.healthy_nodes(:live) == []

    Registry.mark_node("ws1", true)

    assert Registry.healthy_nodes(:ws) == ["ws1"]
    assert Registry.healthy_nodes(:live) == []

    Registry.mark_node("missing", true)

    assert Registry.healthy_nodes(:ws) == ["ws1"]
    assert Registry.healthy_nodes(:live) == []

    Registry.mark_node("ws1", false)

    assert Registry.healthy_nodes(:ws) == []
  end

  test "probe_healthy_node preserves the public error shape when no node is reachable" do
    assert {:error, "No service available"} = Registry.probe_healthy_node(:ws)
  end

  test "scheduled health check keeps unreachable nodes unhealthy" do
    state = %{ws: %{"missing_pool" => %{healthy: true}}}

    assert {:noreply, new_state} = Registry.handle_info(:check_nodes, state)
    assert new_state.ws["missing_pool"].healthy == false
  end

  test "scheduled health check marks reachable heartbeat nodes healthy" do
    node = "unit_heartbeat_node"
    ElixirRpc.TestSupport.start_test_pool(node)

    state = %{ws: %{node => %{healthy: false}}}

    assert {:noreply, new_state} = Registry.handle_info(:check_nodes, state)
    assert new_state.ws[node].healthy == true
  end

  test "RpcClient.call falls back to direct probing when registry has no healthy nodes" do
    assert {:error, "No service available"} =
             Bytes.RpcClient.call(:ws, @existing_module, @existing_event, %{}, %{})
  end

  test "dispatcher chooses healthy nodes and preserves no-service error" do
    assert {:error, "No service available"} = Dispatcher.choose_node(:random, :ws)

    Registry.mark_node("ws2", true)

    assert {:ok, "ws2"} = Dispatcher.choose_node(:random, :ws)
    assert {:error, "No service available"} = Dispatcher.choose_node(:random, :unknown)
  end
end

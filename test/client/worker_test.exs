defmodule Bytes.Client.WorkerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Bytes.Client.Worker
  alias ElixirRpc.TestSupport.EchoGenServer

  test "public rpc_call and rpc_cast send the expected GenServer messages" do
    {:ok, pid} = EchoGenServer.start_link(self())

    assert :echo_reply = Worker.rpc_call(pid, :service, :event, %{h: 1}, %{b: 2})
    assert_receive {:echo_call, {:rpc_call, :service, :event, %{h: 1}, %{b: 2}}}

    assert :echo_reply = Worker.rpc_call(pid, :service, :event, %{h: 1}, %{b: 2}, 500)
    assert_receive {:echo_call, {:rpc_call, :service, :event, %{h: 1}, %{b: 2}}}

    assert :ok = Worker.rpc_cast(pid, :service, :event, %{h: 1}, %{b: 2})
    assert_receive {:echo_cast, {:rpc_cast, :service, :event, %{h: 1}, %{b: 2}}}
  end

  test "start_link initializes state and schedules connection" do
    assert {:ok, state} =
             Worker.init(host: "localhost", port: 50051, to: "node1", from: "client")

    assert state.host == "localhost"
    assert state.port == 50051
    assert state.to == "node1"
    assert state.from == "client"
    assert state.channel == nil
    assert state.connecting == true
    assert_receive :connect
  end

  test "failed connect keeps channel nil and schedules retry" do
    state = %{
      host: "localhost",
      port: 1,
      to: "node1",
      from: "client",
      channel: nil,
      connecting: true
    }

    log =
      capture_log(fn ->
        assert {:noreply, new_state} = Worker.handle_info(:connect, state)
        assert new_state.channel == nil
        assert new_state.connecting == true
      end)

    assert log =~ "Connection failed"
  end

  test "connects to grpc server and dispatches call and cast requests" do
    port = ElixirRpc.TestSupport.start_grpc_server()

    state = %{
      host: "localhost",
      port: port,
      to: "node1",
      from: "client",
      channel: nil,
      connecting: true
    }

    assert {:noreply, connected_state} = Worker.handle_info(:connect, state)
    assert connected_state.channel != nil
    assert connected_state.connecting == false

    assert {:reply, {:ok, %{code: 200, message: "", data: ""}}, ^connected_state} =
             Worker.handle_call(
               {:rpc_call, "__internal__", "heartbeat", %{}, %{}},
               self(),
               connected_state
             )

    assert {:noreply, ^connected_state} =
             Worker.handle_cast(
               {:rpc_cast, "__internal__", "heartbeat", %{}, %{}},
               connected_state
             )

    assert :ok = Worker.terminate(:normal, connected_state)
  end

  test "schedules reconnect for any gun_down reason" do
    state = %{
      host: "localhost",
      port: 50051,
      to: "node1",
      from: "client",
      channel: nil,
      connecting: false
    }

    {result, log} =
      with_log(fn ->
        Worker.handle_info({:gun_down, self(), :http2, {:error, :timeout}, [:stream]}, state)
      end)

    assert {:noreply, new_state} = result
    assert new_state.channel == nil
    assert new_state.connecting == true
    assert_receive :connect
    assert log =~ "Scheduling reconnect"
  end

  test "handles nil channel calls and casts without a registry process" do
    state = base_state(false)

    assert {:reply, {:error, :not_connected}, call_state} =
             Worker.handle_call(:anything, self(), state)

    assert call_state.connecting == true
    assert_receive :connect

    assert {:noreply, cast_state} = Worker.handle_cast(:anything, state)
    assert cast_state.connecting == true
    assert_receive :connect
  end

  test "does not reschedule reconnect when already connecting" do
    state = base_state(true)

    assert {:reply, {:error, :not_connected}, ^state} =
             Worker.handle_call(:anything, self(), state)
  end

  test "handles unknown messages and terminate with nil channel" do
    state = base_state(false)

    assert {:noreply, ^state} = Worker.handle_info(:ignored, state)
    assert :ok = Worker.terminate(:normal, state)

    state_with_channel = %{state | channel: :fake_channel}

    assert {:reply, {:error, :unknown}, ^state_with_channel} =
             Worker.handle_call(:ignored, self(), state_with_channel)

    assert {:noreply, ^state_with_channel} =
             Worker.handle_cast(:ignored, state_with_channel)
  end

  defp base_state(connecting) do
    %{
      host: "localhost",
      port: 50051,
      to: "node1",
      from: "client",
      channel: nil,
      connecting: connecting
    }
  end
end

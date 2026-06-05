defmodule Bytes.RpcServerTest do
  use ExUnit.Case

  test "handle_call and handle_cast return stable responses" do
    server_pid = spawn(fn -> Process.sleep(:infinity) end)
    state = %{port: 50051, pid: server_pid}

    assert {:reply, %{port: 50051, pid: ^server_pid}, ^state} =
             Bytes.RpcServer.handle_call(:info, self(), state)

    assert {:reply, :ok, ^state} = Bytes.RpcServer.handle_call(:unknown, self(), state)
    assert {:noreply, ^state} = Bytes.RpcServer.handle_cast(:unknown, state)

    assert :ok = Bytes.RpcServer.terminate(:normal, state)
    ElixirRpc.TestSupport.stop_process(server_pid)
  end
end

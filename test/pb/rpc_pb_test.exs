defmodule Bytes.Rpc.ProtobufTest do
  use ExUnit.Case

  alias Bytes.Rpc.{Meta, Request, Response}

  test "encode and decode request and response messages" do
    meta = %Meta{node: "client", module: "mod", event: "event"}
    request = %Request{meta: meta, header: "{}", body: ~s({"code":200})}
    response = %Response{code: 200, message: "ok", data: "{}"}

    assert %Meta{node: "client", module: "mod", event: "event"} =
             meta |> Meta.encode() |> Meta.decode()

    assert %Request{meta: %Meta{node: "client"}, header: "{}", body: ~s({"code":200})} =
             request |> Request.encode() |> Request.decode()

    assert %Response{code: 200, message: "ok", data: "{}"} =
             response |> Response.encode() |> Response.decode()

    assert %Meta{} = struct(Meta)
    assert %Request{} = struct(Request)
    assert %Response{} = struct(Response)
  end

  test "service metadata exposes dispatcher rpc" do
    assert [{:Dispatcher, {Bytes.Rpc.Request, false}, {Bytes.Rpc.Response, false}, %{}}] =
             Bytes.Rpc.Route.Service.__rpc_calls__()

    assert "bytes.rpc.Route" = Bytes.Rpc.Route.Service.__meta__(:name)
  end
end

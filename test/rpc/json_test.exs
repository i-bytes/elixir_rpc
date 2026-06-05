defmodule Bytes.Rpc.JsonTest do
  use ExUnit.Case

  alias Bytes.Rpc.Json

  test "passes through scalar encodes and invalid json decodes" do
    assert "plain" = Json.encode("plain")
    assert {:ok, "not-json"} = Json.decode("not-json")
    assert 123 = Json.decode!("123")
    assert {:ok, [%{code: 200}]} = Json.decode(~s([{"code":200}]))
  end

  test "decodes existing JSON keys as atoms without creating new atoms" do
    unknown_key = "rpc_unknown_key_#{System.unique_integer([:positive])}"
    payload = Jason.encode!(%{"code" => 200, unknown_key => %{"message" => "ok"}})

    assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end

    assert {:ok, decoded} = Json.decode(payload)

    assert decoded.code == 200
    assert %{message: "ok"} = Map.fetch!(decoded, unknown_key)
    assert_raise ArgumentError, fn -> String.to_existing_atom(unknown_key) end
  end
end

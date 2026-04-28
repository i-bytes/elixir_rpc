#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Json do
  def encode(data) when is_map(data) or is_list(data), do: Jason.encode!(data)
  def encode(data), do: data

  def decode(payload) do
    case Jason.decode(payload) do
      {:ok, data} -> {:ok, atomize_existing_keys(data)}
      _ -> {:ok, payload}
    end
  end

  def decode!(payload) do
    case Jason.decode(payload) do
      {:ok, data} -> atomize_existing_keys(data)
      {:error, _reason} -> payload
    end
  end

  defp atomize_existing_keys(data) when is_map(data) do
    Map.new(data, fn {key, value} ->
      {existing_atom_or_key(key), atomize_existing_keys(value)}
    end)
  end

  defp atomize_existing_keys(data) when is_list(data),
    do: Enum.map(data, &atomize_existing_keys/1)

  defp atomize_existing_keys(data), do: data

  defp existing_atom_or_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end
end

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
    case Jason.decode(payload, keys: :atoms) do
      {:ok, data} -> {:ok, data}
      _ -> {:ok, payload}
    end
  end

  def decode!(payload) do
    case Jason.decode(payload, keys: :atoms) do
      {:ok, data} -> data
      {:error, _reason} -> payload
    end
  end
end

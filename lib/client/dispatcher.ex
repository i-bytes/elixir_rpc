#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Client.Dispatcher do
  def choose_node(:random, server) do
    Bytes.Client.Registry.healthy_nodes(server)
    |> Enum.random()
  end
end

#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.InternalService do
  alias Bytes.Rpc.Context

  def heartbeat(%Context{} = _ctx) do
    {:ok, %{message: "Pong"}}
  end

  def rpc(%Context{} = _ctx) do
    {:ok, %{message: "Welcome to Elixir Rpc"}}
  end
end

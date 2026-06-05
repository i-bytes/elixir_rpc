#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Server.Cache do
  @moduledoc false

  @key __MODULE__

  def init_cache(modules, middlewares) do
    :persistent_term.put(@key, %{
      modules: modules,
      middlewares_asc: middlewares,
      middlewares_desc: Enum.reverse(middlewares)
    })
  end

  def get_module(name) do
    Map.get(:persistent_term.get(@key).modules, name)
  end

  def get_middlewares(:asc),
    do: Map.get(:persistent_term.get(@key), :middlewares_asc, [])

  def get_middlewares(:desc),
    do: Map.get(:persistent_term.get(@key), :middlewares_desc, [])
end

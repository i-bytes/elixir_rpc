#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.RpcClient do
  use Supervisor

  alias Bytes.Client.{Worker, Registry, Dispatcher}

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    config = Application.get_env(:elixir_rpc, __MODULE__, [])
    nodes = Keyword.get(config, :server_nodes, [])
    pool_size = Keyword.get(config, :pool_size, 5)
    max_overflow = Keyword.get(config, :max_overflow, 2)

    registry = {Registry, Enum.map(nodes, fn {node, _, _} -> node end)}

    pools =
      Enum.map(nodes, fn {node, host, port} ->
        :poolboy.child_spec(
          pool_name(node),
          [
            name: {:local, pool_name(node)},
            worker_module: Worker,
            size: pool_size,
            max_overflow: max_overflow
          ],
          node: node,
          host: host,
          port: port
        )
      end)

    children = [registry] ++ pools
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp pool_name(node), do: String.to_atom("rpc_pool_#{node}")

  def call(service, event, header \\ %{}, body \\ %{}) do
    node = Dispatcher.choose_node(:random)
    call(node, service, event, header, body)
  end

  def call(node, service, event, header, body) do
    :poolboy.transaction(
      pool_name(node),
      fn worker ->
        Worker.rpc_call(worker, service, event, header, body)
      end,
      10_000
    )
  end

  def cast(service, event, header \\ %{}, body \\ %{}) do
    node = Dispatcher.choose_node(:random)
    cast(node, service, event, header, body)
  end

  def cast(node, service, event, header, body) do
    :poolboy.transaction(pool_name(node), fn worker ->
      Worker.rpc_cast(worker, service, event, header, body)
    end)
  end

  def broadcast(service, event, header \\ %{}, body \\ %{}) do
    for node <- Registry.healthy_nodes() do
      Task.start(fn -> cast(node, service, event, header, body) end)
    end

    :ok
  end
end

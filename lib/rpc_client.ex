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
    servers = Keyword.get(config, :servers, [])
    pool_size = Keyword.get(config, :pool_size, 5)
    max_overflow = Keyword.get(config, :max_overflow, 2)
    from_name = Keyword.get(config, :name, "")

    server_nodes = servers |> Keyword.values() |> List.flatten()

    server_names =
      Enum.map(servers, fn {key, servers} ->
        names = Enum.map(servers, fn {name, _host, _port} -> name end)
        {key, names}
      end)

    registry = {Registry, server_names}

    pools =
      Enum.map(server_nodes, fn {node, host, port} ->
        :poolboy.child_spec(
          pool_name(node),
          [
            name: {:local, pool_name(node)},
            worker_module: Worker,
            size: pool_size,
            max_overflow: max_overflow
          ],
          to: node,
          host: host,
          port: port,
          from: from_name
        )
      end)

    children = pools ++ [registry]
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp pool_name(node), do: String.to_atom("rpc_pool_#{node}")

  def call(server, module, event, header \\ %{}, body \\ %{}) do
    case Dispatcher.choose_node(:random, server) do
      {:ok, node} -> do_call(node, module, event, header, body)
      {:error, reason} -> {:error, reason}
    end
  end

  def do_call(node, module, event, header, body) do
    :poolboy.transaction(
      pool_name(node),
      fn worker ->
        Worker.rpc_call(worker, module, event, header, body)
      end,
      10_000
    )
  end

  def cast(server, module, event, header \\ %{}, body \\ %{}) do
    case Dispatcher.choose_node(:random, server) do
      {:ok, node} -> do_cast(node, module, event, header, body)
      {:error, reason} -> {:error, reason}
    end
  end

  def do_cast(node, module, event, header, body) do
    :poolboy.transaction(pool_name(node), fn worker ->
      Worker.rpc_cast(worker, module, event, header, body)
    end)
  end

  def broadcast(server, module, event, header \\ %{}, body \\ %{}) do
    for node <- Registry.healthy_nodes(server) do
      Task.start(fn -> do_cast(node, module, event, header, body) end)
    end

    :ok
  end
end

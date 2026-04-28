# Elixir RPC

`elixir_rpc` is a small gRPC-based RPC wrapper for Elixir services. It provides:

- `Bytes.RpcServer` for exposing configured RPC modules over gRPC.
- `Bytes.RpcClient` for pooled client calls, casts, broadcasts, node health checks, and reconnect handling.
- Middleware hooks for request decoding, logging, and response encoding.

## Installation

Add the dependency to `mix.exs`:

```elixir
def deps do
  [
    {:elixir_rpc, github: "i-bytes/elixir_rpc"}
  ]
end
```

## Supervision

Start the server and/or client in your application supervision tree. The library reads runtime configuration from `Application.get_env/3`; it does not automatically start both sides for you.

```elixir
def start(_type, _args) do
  children = [
    Bytes.RpcServer,
    Bytes.RpcClient
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

If an application only acts as a client, start only `Bytes.RpcClient`. If it only exposes RPC endpoints, start only `Bytes.RpcServer`.

## Server Configuration

Configure the server port, exposed modules, and middleware pipeline:

```elixir
import Config

config :elixir_rpc, Bytes.RpcServer,
  port: 50051,
  modules: [
    user: MyApp.Rpc.UserService,
    order: MyApp.Rpc.OrderService
  ],
  middlewares: [
    Bytes.Rpc.CodecMiddleware,
    Bytes.Rpc.LoggerMiddleware
  ]
```

Each key in `modules` is the RPC module name used by the client. Each value is the Elixir module that implements the RPC events.

Example service module:

```elixir
defmodule MyApp.Rpc.UserService do
  alias Bytes.Rpc.Context

  def get_user(%Context{body: body}) do
    {:ok, %{id: body.id, name: "Jane"}}
  end

  def update_user(%Context{body: body}) do
    # perform update
    {:ok, %{id: body.id, updated: true}}
  end
end
```

The configured service module is called with `apply(module, event, [ctx])`, so the event function must exist with arity `1`.

## Client Configuration

Configure the client name, server groups, pool size, overflow, and timeout:

```elixir
import Config

config :elixir_rpc, Bytes.RpcClient,
  name: "client-a",
  servers: [
    user: [
      {"user-1", "127.0.0.1", 50051},
      {"user-2", "127.0.0.1", 50052}
    ],
    order: [
      {"order-1", "127.0.0.1", 50061}
    ]
  ],
  timeout: 5_000,
  pool_size: 3,
  max_overflow: 2
```

`servers` is grouped by logical service name. Each node tuple is `{node_name, host, port}`.

`timeout` is used for synchronous calls and pool checkout:

- `Bytes.RpcClient.do_call/5` uses it as the `:poolboy.transaction/3` timeout.
- `Bytes.Client.Worker.rpc_call/6` uses it as the `GenServer.call/3` timeout.

The public API remains:

```elixir
Bytes.RpcClient.call(server, module, event, header \\ %{}, body \\ %{})
Bytes.RpcClient.cast(server, module, event, header \\ %{}, body \\ %{})
Bytes.RpcClient.broadcast(server, module, event, header \\ %{}, body \\ %{})
Bytes.RpcClient.do_call(node, module, event, header, body)
Bytes.RpcClient.do_cast(node, module, event, header, body)
```

## Calling RPCs

Synchronous call:

```elixir
Bytes.RpcClient.call(:user, :user, :get_user, %{"trace_id" => "abc"}, %{id: 123})
```

Example response:

```elixir
{:ok, %{code: 200, message: "", data: %{id: 123, name: "Jane"}}}
```

Fire-and-forget cast:

```elixir
Bytes.RpcClient.cast(:user, :user, :update_user, %{}, %{id: 123, name: "Jane"})
```

`cast/5` returns when the local worker accepts the task. It does not mean the remote server processed the message. Network or remote failures are logged.

Broadcast to all currently healthy nodes in a server group:

```elixir
Bytes.RpcClient.broadcast(:user, :user, :refresh_cache, %{}, %{scope: "all"})
```

Direct node call:

```elixir
Bytes.RpcClient.do_call("user-1", :user, :get_user, %{}, %{id: 123})
```

Direct calls bypass service-group node selection but still use the configured pool for the node.

## Health Checks And Reconnects

The client registry tracks healthy nodes per service group.

- Workers mark their node healthy after a successful gRPC connection.
- Workers mark their node unhealthy after connection failures, RPC failures, nil-channel calls, and `:gun_down` events.
- Initial health checking is delayed briefly so workers have time to connect.
- If a service group has no healthy nodes, registry checks retry with a shorter interval.
- If `call/5` or `cast/5` sees no healthy node, the client performs one direct health probe before returning `{:error, "No service available"}`.

The internal heartbeat RPC uses:

```elixir
module: "__internal__"
event: "heartbeat"
```

and returns code `200` when the server is reachable.

## Middleware

Middleware modules implement:

```elixir
@callback pre(map()) :: {:ok, any()} | {:error, any()}
@callback post(map(), {:ok, any()} | {:error, any()}) :: {:ok, any()} | {:error, any()}
```

Default middleware:

- `Bytes.Rpc.CodecMiddleware` decodes request JSON into `%Bytes.Rpc.Context{}` and encodes common response tuples into `%Bytes.Rpc.Response{}`.
- `Bytes.Rpc.LoggerMiddleware` logs request and response metadata with a trace id.

Request middleware runs in configured order. Response middleware runs in reverse order.

## JSON And Atom Safety

Request and response JSON keys are decoded conservatively:

- Existing atom keys are converted back to atoms for compatibility with existing code such as `ctx.body.id`.
- Unknown keys remain strings.
- Unknown keys are not converted with `String.to_atom/1`, so external input cannot grow the atom table.

RPC `module` and `event` strings are converted with `String.to_existing_atom/1`. This means normal calls to existing modules/events continue to work, while unknown names are rejected without creating new atoms.

## Important Semantics

- `call/5` is synchronous and returns the remote response or an error tuple.
- `cast/5` is fire-and-forget. `:ok` means the local cast task was accepted.
- `broadcast/5` sends casts to currently healthy nodes only.
- `module` and `event` must correspond to existing atoms on the server node.
- Node names in client config should be a fixed, finite set. Pool names are derived from node names.

## Development

Run checks:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix test --cover
```

Coverage excludes `Bytes.RpcServer` because it is a thin gRPC/Ranch startup wrapper. Its callbacks are still tested; listener startup is better validated by integration tests because Ranch listener lifecycle is global within the VM.

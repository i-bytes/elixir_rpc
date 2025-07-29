#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
import Config

config :elixir_rpc, Bytes.RpcServer,
  port: 50051,
  services: [
    internal: Bytes.Rpc.InternalService
  ],
  middlewares: [
    Bytes.Rpc.CodecMiddleware,
    Bytes.Rpc.LoggerMiddleware
  ]

config :elixir_rpc, Bytes.RpcClient,
  server_nodes: [
    {"node1", "localhost", 50051},
    {"node2", "localhost", 50051}
  ],
  pool_size: 5,
  max_overflow: 2

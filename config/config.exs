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
  modules: [],
  middlewares: [
    Bytes.Rpc.CodecMiddleware,
    Bytes.Rpc.LoggerMiddleware
  ]

config :elixir_rpc, Bytes.RpcClient,
  servers: [
    {:ws, [{"ws1", "localhost", 50051}, {"ws2", "localhost", 50051}]},
    {:live, [{"live1", "localhost", 50051}]}
  ],
  timeout: 5000,
  pool_size: 3,
  max_overflow: 2

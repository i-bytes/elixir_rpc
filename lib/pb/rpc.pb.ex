#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Meta do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:node, 1, type: :string)
  field(:service, 2, type: :string)
  field(:event, 3, type: :string)
end

defmodule Bytes.Rpc.Request do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:meta, 1, type: Bytes.Rpc.Meta)
  field(:header, 3, type: :string)
  field(:body, 4, type: :string)
end

defmodule Bytes.Rpc.Response do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:code, 1, type: :int32)
  field(:message, 2, type: :string)
  field(:data, 3, type: :string)
end

defmodule Bytes.Rpc.Route.Service do
  @moduledoc false

  use GRPC.Service, name: "bytes.rpc.Route", protoc_gen_elixir_version: "0.14.1"

  rpc(:Dispatcher, Bytes.Rpc.Request, Bytes.Rpc.Response)
end

defmodule Bytes.Rpc.Route.Stub do
  @moduledoc false

  use GRPC.Stub, service: Bytes.Rpc.Route.Service
end

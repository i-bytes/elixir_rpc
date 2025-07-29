#  +----------------------------------------------------------------------
#  | Elixir Rpc [ WE CAN DO IT MORE SIMPLE ]
#  +----------------------------------------------------------------------
#  | Copyright (c) 2025 http://www.bytes.net.cn/ All rights reserved.
#  +----------------------------------------------------------------------
#  | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
#  +---------------------------------------------------------------------
#  | Author: dangyuzhang <develop@bytes.net.cn>
#  +----------------------------------------------------------------------
defmodule Bytes.Rpc.Context do
  @moduledoc """
  RPC 请求上下文，包含元信息、headers、body、以及 tracing 和计时信息。
  """

  @type t :: %__MODULE__{
          meta: Bytes.Rpc.Meta.t() | nil,
          header: map(),
          body: map(),
          request_time: integer(),
          trace_id: String.t() | nil
        }

  defstruct meta: nil,
            header: %{},
            body: %{},
            request_time: 0,
            trace_id: nil
end

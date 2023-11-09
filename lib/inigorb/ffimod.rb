require 'ffi'

module Inigo
  class Config < FFI::Struct
      layout :debug, :bool,
              :name, :pointer,
              :service, :pointer,
              :token, :pointer,
              :schema, :pointer,
              :runtime, :pointer,
              :egress_url, :pointer,
              :gateway, :u_int64_t,
              :disable_response_data, :bool
  end
end

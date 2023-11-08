require 'json'

require 'inigorb/ffimod'

module Inigo
  # made to simplify user experience. just prepend Inigo::Data to your channel and it will work.
  module Data
    attr_accessor :querydata

    def unsubscribed
      if @querydata
        Inigo.disposeHandle(@querydata.handle)
      end
      super
    end
  end

  class Query
    attr_reader :handle

    def initialize(instance, request)
      @handle = 0
      @instance = instance
      @request = request
    end

    def process_request(headers)
      resp_input = FFI::MemoryPointer.from_string(@request)

      output_ptr = FFI::MemoryPointer.new(:pointer)
      output_len = FFI::MemoryPointer.new(:int)

      status_ptr = FFI::MemoryPointer.new(:pointer)
      status_len = FFI::MemoryPointer.new(:int)

      headers_ptr = FFI::MemoryPointer.from_string(headers.to_s)
      headers_len = headers.to_s.length

      @handle = Inigo.process_request(
        1,
        headers_ptr, headers_len,
        resp_input, @request.length,
        output_ptr, output_len,
        status_ptr, status_len
      )

      resp_dict = {}
      req_dict = {}

      output_len_value = output_len.read_int
      if output_len_value > 0
        output_data = output_ptr.read_pointer.read_string(output_len_value)
        resp_dict = JSON.parse(output_data)
      end

      status_len_value = status_len.read_int
      if status_len_value > 0
        status_data = status_ptr.read_pointer.read_string(status_len_value)
        req_dict = JSON.parse(status_data)
      end

      Inigo.disposeMemory(output_ptr.read_pointer)
      Inigo.disposeMemory(status_ptr.read_pointer)

      [resp_dict, req_dict]
    end

    def process_response(resp_body, is_initial_subscription: false, copy: false)
      return nil if @handle.zero?

      output_ptr = FFI::MemoryPointer.new(:pointer)
      output_len = FFI::MemoryPointer.new(:int)

      handle = @handle
      if copy
        # if it is subscription and not initial request - reuse existing querydata
        handle = Inigo.copy_querydata(@handle)
      end

      Inigo.process_response(
        @instance,
        handle,
        FFI::MemoryPointer.from_string(resp_body), resp_body.length,
        output_ptr, output_len
      )

      output_data = output_ptr.read_pointer.read_string(output_len.read_int)

      Inigo.disposeMemory(output_ptr.read_pointer)

      # if it is initial subscription request - do not dispose handle
      if !is_initial_subscription
        Inigo.disposeHandle(handle)
      end

      output_data
    end
  end
end

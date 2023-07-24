require 'json'
require_relative 'ffimod'

module Inigo
  class Query
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
        @instance,
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

    def process_response(resp_body)
      return nil if @handle.zero?

      output_ptr = FFI::MemoryPointer.new(:pointer)
      output_len = FFI::MemoryPointer.new(:int)

      Inigo.process_response(
        @instance,
        @handle,
        FFI::MemoryPointer.from_string(resp_body), resp_body.length,
        output_ptr, output_len
      )

      output_dict = {}

      output_len_value = output_len.read_int
      if output_len_value > 0
        output_data = output_ptr.read_pointer.read_string(output_len_value)
        output_dict = JSON.parse(output_data)
      end

      Inigo.disposeMemory(output_ptr.read_pointer)
      Inigo.disposeHandle(@handle)

      output_dict
    end
  end
end
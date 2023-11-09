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

  class Library
    module TEST 
      pp "HI FROMT TEST"
    end
    
    def initialize
      
      def self.get_arch(system_name)
        machine = RbConfig::CONFIG['target_cpu'].downcase
        if system_name == 'darwin'
          return 'amd64' if machine == 'x86_64'
          return 'arm64' if machine == 'arm64'
        end
      
        if system_name == 'linux'
          if machine == 'aarch64'
            return 'arm64'
          # 32 bits systems bindings support is on the way
          # elsif RUBY_PLATFORM.match?(/(i\d86|x\d86)/)
          #   return '386'
          elsif machine == 'x86_64'
            return 'amd64'
          elsif machine.start_with?('arm') # armv7l
            return 'arm'
          end
        end
      
        if system_name == 'windows'
          return 'amd64' if ['x86_64', 'universal'].include?(RbConfig::CONFIG['host_cpu'])
        end
      
        machine
      end
  
      def self.get_ext(system_name)
        return '.dll' if system_name == 'windows'
        return '.dylib' if system_name == 'darwin'
  
        '.so'
      end
  
      system_name = RbConfig::CONFIG['host_os']
      
      supported_systems = /(linux|darwin|mingw|mswin|cygwin)/
      
      unless supported_systems.match?(system_name)
        raise RuntimeError, "Only Windows, macOS (darwin), and Linux systems are supported. RUBY_PLATFORM: #{RUBY_PLATFORM}, RUBY_ENGINE: #{RUBY_ENGINE}, HOST_OS: #{system_name}"
      end
      
      system_name = 'windows' if system_name =~ /(mingw|mswin|cygwin)/
      system_name = 'darwin' if system_name =~ /darwin/i
      system_name = 'linux' if system_name =~ /linux/i
      
      filename = "inigo-#{system_name}-#{get_arch(system_name)}#{get_ext(system_name)}"

      begin
        pp "load inigo library files"

        extend FFI::Library
        ffi_lib File.join(File.dirname(__FILE__), filename)

        attach_function :create, [:u_int64_t], :u_int64_t
        attach_function :process_request, [
            :u_int64_t,  # instance
            :pointer, :int,  # header
            :pointer, :int,  # input
            :pointer, :pointer,  # output
            :pointer, :pointer  # status
        ], :u_int64_t
        attach_function :process_response, [
            :u_int64_t,  # instance
            :u_int64_t,  # request handler
            :pointer, :int,  # input
            :pointer, :pointer  # output
        ], :void
        attach_function :get_version, [], :string
        attach_function :disposeHandle, [:u_int64_t], :void
        attach_function :disposeMemory, [:pointer], :void
        attach_function :check_lasterror, [], :string
        attach_function :copy_querydata, [:u_int64_t], :u_int64_t
      rescue LoadError => e
        raise ::RuntimeError, "Unable to open Inigo shared library.\n\nPlease get in touch with us for support:\nemail: support@inigo.io\nslack: https://slack.inigo.io\n\nPlease share the below info with us:\nerror:    #{e.to_s}\nuname:    #{RbConfig::CONFIG['host_os']}\narch:     #{RbConfig::CONFIG['host_cpu']}"
      end
    end
  end  
end

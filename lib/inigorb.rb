require 'json'
require 'ffi'
require_relative 'ffimod'
require_relative 'query'

module Inigo
  class Middleware
    @@instance = 0
    @@initialized = false
    @@path = ''
    @@schema = ''

    def self.instance
      @@instance
    end

    def self.instance=(value)
      @@instance = value
    end

    def self.initialized
      @@initialized
    end

    def self.initialized=(value)
      @@initialized = value
    end

    def self.path
      @@path
    end

    def self.path=(value)
      @@path = value
    end

    def self.schema
      @@schema
    end

    def self.schema=(value)
      @@schema = value
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      # Ignore execution if Inigo is not initialized
      if self.class.instance == 0
        return @app.call(env)
      end

      request = Rack::Request.new(env)

      # 'path' guard -> /graphql
      if request.path != self.class.path
        return @app.call(env)
      end

      # GraphiQL request
      if request.get? && request.accept.include?('text/html')
        return @app.call(env)
      end

      # Support only POST and GET requests
      if !request.post? && !request.get?
        return @app.call(env)
      end

      # Parse request
      gReq = ''
      if request.post?
        # Read request from body
        request.body.each { |chunk| gReq += chunk }
        request.body.rewind
      elsif request.get?
        # Read request from query param
        gReq = JSON.dump({ 'query' => request.params['query'] })
      end

      q = Query.new(self.class.instance, gReq)

      # Inigo: process request
      resp, req = q.process_request(headers(request))

      # Introspection query
      if resp.any?
        return respond(resp)
      end

      # Modify query if required
      if req.any?
        if request.post?
          body = JSON.parse(request.body.read)
          body.merge!(
            'query' => req['query'],
            'operationName' => req['operationName'],
            'variables' => req['variables']
          )
          request.body = Rack::Utils.build_nested_query(body)
        elsif request.get?
          params = request.params
          params['query'] = req['query']
          request.update_param(params)
        end
      end

      # Forward to request handler
      response = @app.call(env)

      # Inigo: process response
      processed_response = q.process_response(response[2].body.to_s)
      if processed_response
        return respond(processed_response)
      end

      response
    end

    private

    def self.initialize_middleware(schema = nil)
      return if @@initialized

      if schema
        @@schema = schema
      end
      # get all the inigo settings from env
      settings = ENV.select { |k, v| k.start_with?('INIGO') }

      if settings.fetch("INIGO_ENABLE", "").to_s.downcase == "false"
        @@initialized = true #not to get to this method ever again
        puts 'Inigo is disabled. Skipping middleware.'
        return
      end

      config = Inigo::Config.new

      if settings.fetch("INIGO_DEBUG", "false").to_s.downcase == "true"
        config[:debug] = true
      else
        config[:debug] = false
      end

      config[:token] = FFI::MemoryPointer.from_string(settings.fetch('INIGO_SERVICE_TOKEN', '').to_s.encode('UTF-8'))

      schema = nil
      if @@schema
        schema = @@schema
      elsif settings.fetch('INIGO_SCHEMA_PATH', '') != ''
        path = settings.fetch('INIGO_SCHEMA_PATH')
        if File.exist?(path)
          schema = File.read(path)
        end
      end

      config[:schema] = FFI::MemoryPointer.from_string(schema.to_s.encode('UTF-8')) if schema

      @@path = settings.fetch('INIGO_PATH', '/query')

      # Create Inigo instance
      @@instance = Inigo.create(config.pointer.address)

      error = Inigo.check_lasterror
      if error.length != 0
        puts "INIGO: #{error.read_string}"
      end

      if @@instance == 0
        puts 'INIGO: error, instance cannot be created'
      end

      @@initialized = true
    end

    def headers(request)
      headers = {}
    
      request.env.each do |key, value|
        if key.start_with?('HTTP_')
          header_name = key[5..].split('_').map(&:capitalize).join('-')
          headers[header_name] = value.split(',').map(&:strip)
        elsif key == 'CONTENT_TYPE' || key == 'REMOTE_ADDR'
          headers[key] = value.split(',').map(&:strip)
        end
      end
    
      JSON.dump(headers)
    end

    def respond(data)
      response = Rack::Response.new
      response_hash = {}
      response_hash['data'] = data['data'] if data['data']
      response_hash['errors'] = data['errors'] if data['errors']
      response_hash['extensions'] = data['extensions'] if data['extensions']
      response.write(JSON.dump(response_hash))
      response.finish
    end

  end  
end
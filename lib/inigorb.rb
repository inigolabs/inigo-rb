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
    @@operation_store = nil

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

    def self.operation_store
      @@operation_store
    end

    def self.operation_store=(value)
      @@operation_store = value
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

      path = self.class.path
      path += "/" unless path.end_with?("/")
      # 'path' guard -> /graphql, /graphql/whatever
      if request.path != self.class.path && !request.path.start_with?(path)
        return @app.call(env)
      end

      # GraphiQL request
      if request.get? && env['HTTP_ACCEPT'].include?('text/html')
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

        if self.class.operation_store.present? && has_operation_id?(gReq) && !has_query?(gReq)
          parsed = JSON.parse(gReq)
          operationId = get_operation_id(parsed)

          if !operationId
            request.body.rewind
            return @app.call(env)
          end

          parts = operationId.split('/')
          # Query can't be resolved
          if parts.length != 2
            request.body.rewind
            return @app.call(env)
          end
          data = self.class.operation_store.get(client_name: parts[0], operation_alias: parts[1])
          # Query can't be resolved
          if !data
            request.body.rewind
            return @app.call(env)
          end
          if data.name
            parsed.merge!('operationName' => data.name)
          end
  
          if data.body
            parsed.merge!('query' => data.body)
          end

          gReq = ''
          gReq = JSON.dump(parsed)
          env['rack.input'] = StringIO.new(gReq)
          env['CONTENT_LENGTH'] = gReq.length.to_s
          env['CONTENT_TYPE'] = 'application/json'
        end
        request.body.rewind
      elsif request.get?
        operation_id = get_operation_id(request.params)
        if operation_id && self.class.operation_store && !request.params['query']
            parts = operation_id.split('/')
            # Query can't be resolved
            if parts.length != 2
              return @app.call(env)
            end
            data = self.class.operation_store.get(client_name: parts[0], operation_alias: parts[1])
            # Query can't be resolved
            if !data
              return @app.call(env)
            end

            if data.name
              request.params['operationName'] = data.name
            end
    
            if data.body
              request.params['query'] = data.body
            end

            # Update the env with the modified query string
            env['QUERY_STRING'] = Rack::Utils.build_nested_query(request.params)
        end

        # Read request from query param
        gReq = JSON.dump(request.params)
      end

      q = Query.new(self.class.instance, gReq)

      # Inigo: process request
      resp, req = q.process_request(headers(request))

      # Introspection query
      if resp.any?
        return respond(200, { 'Content-Type' => 'application/json'}, resp)
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
      status, headers, response = @app.call(env)
      headers.delete("Content-Length")
      # Inigo: process response
      response = q.process_response(response.body.to_s)
      [status, headers, [response]]
    end

    private

    def self.initialize_middleware(schema = nil, operation_store = nil)
      return if @@initialized

      if schema
        @@schema = schema
      end

      if operation_store
        @@operation_store = operation_store
      end

      # get all the inigo settings from env
      settings = ENV.select { |k, v| k.start_with?('INIGO') }

      if settings.fetch("INIGO_ENABLE", "").to_s.downcase == "false"
        @@initialized = true #not to get to this method ever again
        puts 'Inigo is disabled. Skipping middleware.'
        return
      end

      config = Inigo::Config.new
      config[:disable_response_data] = false
      config[:name] = FFI::MemoryPointer.from_string("inigo-rb".to_s.encode('UTF-8'))
      config[:runtime] = FFI::MemoryPointer.from_string("ruby".concat(RUBY_VERSION[/\d+\.\d+/]).to_s.encode('UTF-8'))

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

      @@path = settings.fetch('INIGO_PATH', '/graphql')

      # Create Inigo instance
      @@instance = Inigo.create(config.pointer.address)

      error = Inigo.check_lasterror
      if error.length != 0
        puts "INIGO: #{error}"
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

    def respond(status, headers, data)      
      response_hash = {}
      response_hash['data'] = data['data'] if data['data']
      response_hash['errors'] = data['errors'] if data['errors']
      response_hash['extensions'] = data['extensions'] if data['extensions']

      [status, headers, [JSON.dump(response_hash)]]
    end

    # operates with string data not to parse the request body unnecessary
    def has_operation_id?(str_data)
      # Relay / Apollo 1.x and Apollo Link have the same field just in different places.
      str_data.include?('operationId')
    end

    def has_query?(str_data)
      return str_data.include?('"query":') && str_data.match(/"query"\s*:\s*"\S+"/)
    end

    # extracts operation id from parsed body hash
    def get_operation_id(json_data)
      # Relay / Apollo 1.x
      if json_data.include?('operationId')
        json_data['operationId']
      # Apollo Link
      elsif json_data.include?('extensions') && json_data['extensions'].include?('operationId')
        json_data['extensions']['operationId']
      else
        nil
      end
    end

  end  
end

require 'json'
require 'ffi'
require 'graphql'

require 'inigorb/ffimod'
require 'inigorb/query'

module Inigo
  class Tracer < GraphQL::Tracing::PlatformTracing
    @@instance = nil

    def self.instance
      @@instance
    end

    def self.instance=(value)
      @@instance = value
    end

    def initialize(options = {})
      super(options)
      # add options like logger logic
    end

    def self.use(schema, **kwargs)
      @@schema = schema
      super
    end

    self.platform_keys = {
      'lex' => 'lex',
      'parse' => 'parse',
      'validate' => 'validate',
      'analyze_query' => 'analyze_query',
      'analyze_multiplex' => 'analyze_multiplex',
      'execute_multiplex' => 'execute_multiplex',
      'execute_query' => 'execute_query',
      'execute_query_lazy' => 'execute_query_lazy'
    }

    def platform_trace(platform_key, key, data)
      # Ignore execution if Inigo is not initialized
      if self.class.instance == 0
        return yield
      end

      if platform_key != "execute_multiplex"
        return yield
      end

      if !data[:multiplex] || !data[:multiplex].queries || data[:multiplex].queries.length == 0
        return yield
      end

      queries = []
      modified_responses = {}

      data[:multiplex].queries.each_with_index do |query, index|
        # no single source of the whole query data
        gReq = {
          :query => query.query_string,
          :operation_name => query.operation_name,
          :variables => query.variables.to_h,
        }

        q = Query.new(self.class.instance, JSON.dump(gReq))

        # TODO no options to return early response. query will be executed anyways
        resp, req = q.process_request(headers(query.context['request']))

        # Introspection query
        if resp.any?
          modified_responses[index]  = resp
        end

        # Modify query if required
        if req.any?
          modified_query = GraphQL::Query.new(@@schema, req['query'], context: query.context, operation_name: req['operationName'], variables: req['variables'])
          modified_query.multiplex = query.multiplex
        end

        queries.append(q)
      end

      responses = yield

      responses.each_with_index do |response, index|
        if modified_responses[index]
          # process_response is not called in this case
          responses[index] = GraphQL::Query::Result.new(query: data[:multiplex].queries[index], values: modified_responses[index])
          next
        end

        processed_response = queries[index].process_response(response.to_json)
        responses[index] = GraphQL::Query::Result.new(query: data[:multiplex].queries[index], values: processed_response)
      end

      responses
    end

    # compat
    def platform_authorized_key(type)
      "#{type.graphql_name}.authorized.graphql"
    end

    # compat
    def platform_resolve_type_key(type)
      "#{type.graphql_name}.resolve_type.graphql"
    end

    # compat
    def platform_field_key(type, field)
      "graphql.#{type.name}.#{field.name}"
    end
    
    private

    def self.initialize_tracer(schema)
      @@schema = schema

      # get all the inigo settings from env
      settings = ENV.select { |k, v| k.start_with?('INIGO') }

      if settings.fetch("INIGO_ENABLE", "").to_s.downcase == "false"
        @@initialized = true #not to get to this method ever again
        puts 'Inigo is disabled. Skipping middleware.'
        return
      end

      config = Inigo::Config.new

      config[:debug] = settings.fetch("INIGO_DEBUG", "false").to_s.downcase == "true"
      config[:token] = FFI::MemoryPointer.from_string(settings.fetch('INIGO_SERVICE_TOKEN', '').to_s.encode('UTF-8'))
      config[:schema] = FFI::MemoryPointer.from_string(schema.to_s.encode('UTF-8'))
      config[:name] = FFI::MemoryPointer.from_string("inigo-rb".to_s.encode('UTF-8'))
      config[:runtime] = FFI::MemoryPointer.from_string("ruby".concat(RUBY_VERSION[/\d+\.\d+/]).to_s.encode('UTF-8'))

      # Create Inigo instance
      @@instance = Inigo.create(config.pointer.address)

      error = Inigo.check_lasterror
      if error.length != 0
        puts "INIGO: #{error}"
      end

      if error.length == 0 && @@instance == 0
        puts 'INIGO: error, instance cannot be created'
      end
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

  end
end
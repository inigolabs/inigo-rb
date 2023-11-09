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
      subscription_queries = {}
      initial_subscriptions = {}
      modified_responses = {}
      cached_queries = {}

      data[:multiplex].queries.each_with_index do |query, index|
        is_subscription = query.context[:channel] != nil
        is_init_subscription = is_subscription && !query.context[:subscription_id]

        if is_subscription && !is_init_subscription
          # retrieve querydata stored after initial subscription request
          subscription_queries[index] = query.context[:channel].querydata
          queries.append(query.context[:channel].querydata)
          # no need to process request again, it will be copied
          next
        end

        gReq = {
          'query' => query.query_string,
        }

        gReq['operationName'] = query.operation_name if query.operation_name && query.operation_name != ''
        gReq['variables'] = query.variables.to_h if query.variables

        q = Query.new(self.class.instance, JSON.dump(gReq))

        incoming_request = query.context['request']
        if is_subscription
          incoming_request = ActionDispatch::Request.new(query.context[:channel].connection.env)
        end

        resp, req = q.process_request(headers(incoming_request))

        # Introspection or blocked query
        if resp.any?
          modified_responses[index]  = resp
          cached_queries[index] = query

          # trick not to execute actual query. we can't remove query from multiplex at all but we can fool it by modifying the query executed on the schema.
          modified_query = GraphQL::Query.new(query.schema, 'query IntrospectionQuery { __schema { queryType { name } } }', context: query.context, operation_name: 'IntrospectionQuery')
          modified_query.multiplex = query.multiplex
          # TODO - verify works in all the cases. During the testing it works, simulate multiple queries at the same time to verify.
          data[:multiplex].queries[index] = modified_query

          queries.append(q)
          next
        end

        # Modify query if required
        if req.any?
          modified_query = GraphQL::Query.new(query.schema, req['query'], context: query.context, operation_name: req['operationName'], variables: req['variables'])
          modified_query.multiplex = query.multiplex
          # TODO - verify works in all the cases. During the testing it works, simulate multiple queries at the same time to verify.
          data[:multiplex].queries[index] = modified_query
        end

        if is_subscription
          query.context[:channel].querydata = q
          initial_subscriptions[index] = true
        end

        queries.append(q)
      end

      responses = yield

      responses.each_with_index do |response, index|
        if modified_responses[index]
          # process_response is not called in this case
          responses[index] = GraphQL::Query::Result.new(query: cached_queries[index], values: modified_responses[index])
          next
        end

        # take a copy of the initial subscription request if it is subscription
        needs_copy = subscription_queries[index] != nil
        is_initial_subscription = initial_subscriptions[index] != nil
        resp = {
          'errors' => response['errors'],
          'response_size' => 0,
          'response_body_counts' => count_response_fields(response.to_h)
        }
        processed_response = queries[index].process_response(JSON.dump(resp), is_initial_subscription: is_initial_subscription, copy: needs_copy)
        responses[index] = GraphQL::Query::Result.new(query: data[:multiplex].queries[index], values: mod_response(response.to_h, JSON.parse(processed_response)))
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

    def count_response_fields(resp)
      counts = {}

      if resp['data']
        count_response_fields_recursive(counts, 'data', resp['data'])
      end

      counts['data'] ||= 1
      counts['errors'] = resp['errors'] ? resp['errors'].length : 0
      counts
    end

    def count_response_fields_recursive(hm, prefix, val)
      return unless val.is_a?(Hash) || val.is_a?(Array)

      incr = lambda do |key, value|
        unless count_response_fields_recursive(hm, key, value)
          hm[key] = (hm[key] || 0) + 1
        end
      end

      if val.is_a?(Array)
        val.each do |item|
          incr.call(prefix, item)
        end

        return true
      end

      val.each do |k, v|
        incr.call("#{prefix}.#{k}", v)
      end

      return false
    end

    private

    def self.initialize_tracer(schema)
      @@schema = schema

      lib_instance = Inigo::Library.new

      # get all the inigo settings from env
      settings = ENV.select { |k, v| k.start_with?('INIGO') }

      if settings.fetch("INIGO_ENABLE", "").to_s.downcase == "false"
        @@initialized = true #not to get to this method ever again
        puts 'Inigo is disabled. Skipping middleware.'
        return
      end

      config = Inigo::Config.new

      config[:disable_response_data] = false
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

    def mod_response(response, extended)
      if extended['extensions']
        response['extensions'] ||= {}
        response['extensions'].merge!(extended['extensions'])
      end
    
      if extended['errors']
        response['errors'] ||= []
        response['errors'].concat(extended['errors'])
      end

      response
    end

  end
end
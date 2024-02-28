require 'json'
require 'ffi'
require 'graphql'

require 'inigorb/ffimod'
require 'inigorb/query'

module Inigo
  module Tracer
    @@instance = nil

    def initialize(options = {})
      # add options like logger logic
    end

    def execute_multiplex(multiplex:)
      # Ignore execution if Inigo is not initialized
      if @@instance == 0
        return yield
      end

      if !multiplex || !multiplex.queries || multiplex.queries.length == 0
        return yield
      end

      queries = []
      subscription_queries = {}
      initial_subscriptions = {}
      modified_responses = {}
      cached_queries = {}

      multiplex.queries.each_with_index do |query, index|
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
        # when operation registry is enabled and query string is absent query.variables is empty property as
        # there is an error on query that query string is missing.
        # query.variables is basically a method that provides a hash of variables provided and query default variables.
        # in case with operation registry we don't have a string and should use only provided vars.
        gReq['variables'] = query.provided_variables if query.query_string.nil? || query.query_string.empty?
        gReq['extensions'] = query.context[:extensions] if query.context[:extensions]

        q = Query.new(@@instance, JSON.dump(gReq))

        headers_obj = query.context[:headers] if query.context[:headers]
        headers_obj = query.context['request'].headers if headers_obj == nil && query.context['request']
        headers_obj = query.context[:request].headers if headers_obj == nil && query.context[:request]
        if is_subscription
          headers_obj = ActionDispatch::Http::Headers.from_hash(query.context[:channel].connection.env)
        end

        resp, req = q.process_request(headers(headers_obj))

        # Introspection or blocked query
        if resp.any?
          modified_responses[index]  = resp
          cached_queries[index] = query

          # trick not to execute actual query. we can't remove query from multiplex at all but we can fool it by modifying the query executed on the schema.
          modified_query = GraphQL::Query.new(query.schema, 'query IntrospectionQuery { __schema { queryType { name } } }', context: query.context, operation_name: 'IntrospectionQuery')
          modified_query.multiplex = query.multiplex
          # TODO - verify works in all the cases. During the testing it works, simulate multiple queries at the same time to verify.
          multiplex.queries[index] = modified_query

          queries.append(q)
          next
        end

        # Modify query if required
        if req.any?
          modified_query = GraphQL::Query.new(query.schema, req['query'], context: query.context, operation_name: req['operationName'], variables: req['variables'])
          modified_query.multiplex = query.multiplex
          # TODO - verify works in all the cases. During the testing it works, simulate multiple queries at the same time to verify.
          multiplex.queries[index] = modified_query
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
        responses[index] = GraphQL::Query::Result.new(query: multiplex.queries[index], values: mod_response(response.to_h, JSON.parse(processed_response)))
      end

      responses
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

      # get all the inigo settings from env
      settings = ENV.select { |k, v| k.start_with?('INIGO') }

      if settings.fetch("INIGO_ENABLE", "").to_s.downcase == "false"
        puts 'Inigo is disabled. Skipping middleware.'
        return
      end

      Inigo::load
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

    def headers(headers_obj)
      headers = {}

      headers_obj.env.each do |key, value|
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
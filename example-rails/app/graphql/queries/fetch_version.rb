module Queries
  class FetchVersion < Queries::BaseQuery

    type [Types::VersionType], null: false

    def resolve
      version = {
        :name => 'This is a value',
        :version => '123123'
      }
    end
  end

  class FetchMiddlewareVersion < Queries::BaseQuery

    type [Types::MiddlewareVersionType], null: false

    def resolve
      version = {
        :path => 'This is a value',
        :version => '123123'
      }
    end
  end
end
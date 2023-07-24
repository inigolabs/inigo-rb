module Types
  class VersionType < Types::BaseObject
    field :name, String, null: false
    field :version, String, null: false
    field :commit, String, null: false
    field :date, String, null: false
  end

  class MiddlewareVersionType < Types::BaseObject
    field :path, String, null: false
    field :version, String, null: false
  end
end

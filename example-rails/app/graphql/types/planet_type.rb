module Types
  class PlanetType < Types::BaseObject
    field :id, ID, null: false
    field :climate, String, null: false
    field :diameter, Integer, null: true
    field :gravity, String, null: false
    field :name, String, null: false
    field :orbitalPeriod, String, null: false
    field :population, Integer, null: true
    field :rotationPeriod, String, null: false
    field :surfaceWater, String, null: false
    field :terrain, String, null: false
  end
end

module Types
  module Input
    class PlanetInputType < Types::BaseInputObject
      argument :climate, String, required: true
      argument :diameter, Integer, required: false
      argument :gravity, String, required: true
      argument :name, String, required: true
      argument :orbitalPeriod, String, required: true
      argument :population, GraphQL::Types::BigInt, required: false
      argument :rotationPeriod, String, required: true
      argument :surfaceWater, String, required: true
      argument :terrain, String, required: true
    end
  end
end

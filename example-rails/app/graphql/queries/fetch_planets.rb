module Queries
  class FetchPlanets < Queries::BaseQuery

    type [Types::PlanetType], null: false

    def resolve
      DataLoader.data['planet'].map.with_index { |x, i| 
        x['id'] = i.to_s
        x
      }
    end
  end
end
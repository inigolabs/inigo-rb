module Queries
  class FetchStarships < Queries::BaseQuery

    type [Types::StarshipType], null: false

    def resolve
      DataLoader.data['starship'].map.with_index { |x, i| 
        x['id'] = i.to_s
        x['hyperdriveRating'] = x['hyperdrive_rating']
        x
      }
    end
  end
end
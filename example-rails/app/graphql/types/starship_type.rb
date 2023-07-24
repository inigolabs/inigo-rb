module Types
  class StarshipType < Types::BaseObject
    field :id, ID, null: false
    field :cargoCapacity, Integer, null: true
    field :class, String, null: true
    field :consumables, String, null: false
    field :costInCredits, Integer, null: false
    field :crew, String, null: false
    field :hyperdriveRating, String, null: false
    field :length, Float, null: false
    field :manufacturer, String, null: false
    field :maxAtmospheringSpeed, String, null: false
    field :maximumMegalights, String, null: true
    field :model, String, null: false
    field :name, String, null: false
    field :passengerCapacity, Integer, null: true
    field :piloted_by, [Types::PersonType], null: false

    def piloted_by
      result = []
      DataLoader.data['person'].each_with_index { |p, index|
        piloted_starships = p.dig('edges', 'piloted_starship')

        if (piloted_starships && piloted_starships.include?(object['id'].to_i))
          p['id'] = index.to_s
          result.append(p)
        end
      }
      result
    end
  end
end

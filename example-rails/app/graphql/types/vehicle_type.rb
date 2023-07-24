module Types
  class VehicleType < Types::BaseObject
    field :id, ID, null: false
    field :cargoCapacity, Integer, null: true
    field :consumables, String, null: false
    field :costInCredits, Integer, null: false
    field :crew, String, null: false
    field :length, Float, null: true
    field :manufacturer, String, null: false
    field :maxAtmospheringSpeed, String, null: false
    field :model, String, null: false
    field :name, String, null: false
    field :passengerCapacity, Integer, null: true
    field :piloted_by, [Types::PersonType], null: false

    def piloted_by
      result = []
      DataLoader.data['person'].each_with_index { |p, index|
        piloted_vehicle = p.dig('edges', 'piloted_vehicle')
        if (piloted_vehicle && piloted_vehicle.include?(object['id'].to_i))
          p['id'] = index.to_s
          result.append(p)
        end
      }
      result
    end
  end
end

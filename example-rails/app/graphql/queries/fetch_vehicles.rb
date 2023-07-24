module Queries
  class FetchVehicles < Queries::BaseQuery

    type [Types::VehicleType], null: false

    def resolve
      DataLoader.data['vehicle'].map.with_index { |x, i| 
        x['id'] = i.to_s
        x
      }
    end
  end
end
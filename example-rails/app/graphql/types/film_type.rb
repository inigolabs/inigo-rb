module Types
  class FilmType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :director, String, null: false
    field :episode_id, Integer, null: false
    field :openingCrawl, String, null: false
    field :producer, String, null: false, deprecation_reason: "deprecated"
    field :characters, [Types::PersonType], null: false
    field :species, [Types::SpeciesType], null: true
    field :starships, [Types::StarshipType], null: true
    field :vehicles, [Types::VehicleType], null: true
    field :planets, [Types::PlanetType], null: false

    def vehicles
      result = []
      if (object['edges'] && object['edges']['has_vehicle'])
        object['edges']['has_vehicle'].each_with_index { |item, index|
          v = DataLoader.data['vehicle'][item]
          v['id'] = item.to_s
          result.append(v)
        }
      end
      result
    end

    def characters
      result = []
      if (object['edges'] && object['edges']['has_person'])
        object['edges']['has_person'].each_with_index { |item, index|
          v = DataLoader.data['person'][item]
          v['id'] = item.to_s
          v['hairColor'] = v['hair_color']
          result.append(v)
        }
      end
      result
    end

    def planets
      result = []
      if (object['edges'] && object['edges']['has_planet'])
        object['edges']['has_planet'].each_with_index { |item, index|
          v = DataLoader.data['planet'][item]
          v['id'] = item.to_s
          v['orbitalPeriod'] = v['orbital_period']
          v['rotationPeriod'] = v['rotation_period']
          v['surfaceWater'] = v['surface_water']
          result.append(v)
        }
      end
      result
    end
  end
end

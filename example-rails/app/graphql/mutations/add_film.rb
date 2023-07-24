module Mutations
  class AddFilm < Mutations::BaseMutation
    type String, null: true

    argument :title, String, required: true
    argument :input, Types::Input::FilmInputType, required: true

    def resolve(title:, input:)
      planetsIds = []

      if (input.planets)
          input.planets.each_with_index {|val, index| 
            planetsIds.append(DataLoader.data['planet'].length())

            DataLoader.data['planet'].append({
                "climate" => val.climate,
                "diameter" => val.diameter ? val.diameter : 0,
                "gravity"=> val.gravity,
                "name"=> val.name,
                "orbital_period"=> val.orbitalPeriod,
                "population"=> val.population ? val.population : 0,
                "rotation_period"=> val.rotationPeriod,
                "surface_water"=> val.surfaceWater,
                "terrain"=> val.terrain
            })
          }              
      end

      DataLoader.data['film'].append({
          "title"=> title,
          "director"=> input.director,
          "episode_id"=> input.episodeId,
          "opening_crawl"=> input.openingCrawl,
          "producer"=> input.producer,
          "edges"=> {
              "has_planet"=> planetsIds
          }
      })

      return title
    end
  end
end
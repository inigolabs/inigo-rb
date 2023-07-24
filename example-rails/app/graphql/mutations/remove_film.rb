module Mutations
  class RemoveFilm < Mutations::BaseMutation
    type Int, null: true

    argument :title, String, required: true
    argument :removePlanets, Boolean, required: false

    def resolve(args)
      planets_indexes = []
      removed_objects = 0

      film = DataLoader.data['film'].detect {|f| f['title'] == args[:title] }
      if (film)
        idx = DataLoader.data['film'].index(film)
        if (film.dig('edges','has_planet'))
          planets_indexes = film.dig('edges','has_planet')
        end

        DataLoader.data['film'].delete_at(idx)

        removed_objects += 1
      end

      if args[:removePlanets] && planets_indexes.length() > 0
        planets_indexes.reverse!
        planets_indexes.each { |x|
          DataLoader.data['planet'].delete_at(x)
          removed_objects += 1
        }
      end

      removed_objects
    end
  end
end
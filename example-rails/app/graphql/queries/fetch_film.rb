module Queries
  class FetchFilm < Queries::BaseQuery

    type Types::FilmType, null: false

    argument :title, String, required: true

    def resolve(args)
      film = DataLoader.data['film'].detect {|f| f['title'] == args[:title] }
      if (film)
        film['id'] = 0.to_s
        film
      end
    end
  end

  class FetchFilms < Queries::BaseQuery

    type [Types::FilmType], null: false

    def resolve()
      DataLoader.data['film'].map.with_index { |x, i| 
        x['id'] = i.to_s
        x
      }
    end
  end
end
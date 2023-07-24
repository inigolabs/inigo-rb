module Types
  class PersonType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :ssn, String, null: false
    field :birthYear, String, null: false
    field :eyeColor, String, null: false
    field :gender, String, null: false
    field :hairColor, String, null: false
    field :height, Integer, null: false
    field :mass, Float, null: true
    field :skinColor, String, null: true
    field :appeared_in, [Types::FilmType], null: false
    field :piloted_starship, [Types::StarshipType], null: false

    def appeared_in
      result = []
      
      DataLoader.data['film'].each_with_index { |f, index|
        persons = f.dig('edges', 'has_person')

        if (persons && persons.include?(object['id'].to_i))
          f['id'] = index.to_s
          result.append(f)
        end
      }
      result
    end

    def piloted_starship
      result = []

      if (object['edges'] && object['edges']['piloted_starship'])
        object['edges']['piloted_starship'].each_with_index { |f, index|
          s = DataLoader.data['starship'][f]
          s['id'] = index.to_s
          result.append(s)
        }
      end

      result
    end
  end
end

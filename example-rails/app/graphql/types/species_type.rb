module Types
  class SpeciesType < Types::BaseObject
    field :id, ID, null: false
    field :averageHeight, Integer, null: false
    field :averageLifespan, String, null: false
    field :classification, String, null: false
    field :designation, String, null: false
    field :name, String, null: false
    field :skinColor, String, null: false
    field :eyeColor, String, null: false
    field :hairColor, String, null: false
    field :language, String, null: false
  end
end

module Types
  class MutationType < Types::BaseObject
    field :filmAdd, mutation: Mutations::AddFilm
    field :filmRemove, mutation: Mutations::RemoveFilm
  end
end

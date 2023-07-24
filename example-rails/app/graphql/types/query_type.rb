module Types
  class QueryType < Types::BaseObject
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    field :version, Types::VersionType, resolver: Queries::FetchVersion
    field :planets, [Types::PlanetType], resolver: Queries::FetchPlanets
    
    field :login, String, resolver: Queries::FetchLogin
    field :logout, Boolean, resolver: Queries::FetchLogout

    field :film, Types::FilmType, resolver: Queries::FetchFilm
    field :films, [Types::FilmType], resolver: Queries::FetchFilms
    
    field :starships, [Types::StarshipType], resolver: Queries::FetchStarships
    field :vehicles, [Types::VehicleType], resolver: Queries::FetchVehicles
  end
end

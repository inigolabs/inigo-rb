module Types
  module Input
    class FilmInputType < Types::BaseInputObject
      argument :director, String, required: true
      argument :producer, String, required: true
      argument :episodeId, Integer, required: true
      argument :openingCrawl, String, required: true
      argument :planets, [PlanetInputType], required: true
    end
  end
end

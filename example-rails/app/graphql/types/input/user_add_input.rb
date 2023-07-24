module Types
  module Input
    class UserAddInputType < Types::BaseInputObject
      argument :username, String, required: true
      argument :password, String, required: true
      argument :name, String, required: true
      argument :profile, String, required: true
      argument :roles, [String], required: true
    end
  end
end

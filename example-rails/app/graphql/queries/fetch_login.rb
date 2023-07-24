require 'date'

module Queries
  class FetchLogin < Queries::BaseQuery
    type String, null: true

    argument :username, String, required: true
    argument :password, String, required: true

    def resolve(args)
      user = DataLoader.data['user'].detect {|u| u['username'] == args[:username] && u['password'] == args[:password]}
      if (user)
        now = Integer(Time.now.strftime("%Y%m%d%H%M%S"))
        iat = now/1000.floor
        exp = iat + (60 * 60 * 24)
        payload={
          iat: iat,
          exp: exp,
          user_profile: user['profile'],
          user_roles: user['roles'],
          user_id: user['id'],
          user_name: user['username'],
          token: "12121212-12121-12121-12121-1212121212",
        }
        JWT.encode(payload, 'SecretPassword!', 'HS256')
      end
    end
  end

  class FetchLogout < Queries::BaseQuery
    type Boolean, null: false

    def resolve(args)
      true
    end
  end
end
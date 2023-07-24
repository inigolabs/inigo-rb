Rails.application.config.after_initialize do
  require 'inigorb'
  Inigo::Middleware.initialize_middleware(InigoRorSchema.to_definition)
end

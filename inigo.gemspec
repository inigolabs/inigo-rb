Gem::Specification.new do |s|
  s.name        = "inigorb"
  s.version     = File.read(File.join(File.dirname(__FILE__), 'VERSION'))
  s.platform    = Gem::Platform::RUBY

  s.summary     = "Inigo GraphQL plugin for Ruby"

  s.authors     = ["Inigo"]
  s.email       = "eitan@inigo.io"
  s.files       = Dir['lib/*.rb', 'lib/*.so', 'lib/*.dylib', 'lib/*.dll', 'README.md']
  s.homepage    = "https://inigo.io"
  s.license     = "MIT"
  s.metadata = {
    "documentation_uri" => "https://docs.inigo.io",
    "homepage_uri"      => "https://inigo.io",
    "source_code_uri"   => "https://github.com/inigolabs/inigo-rb/blob/master",
  }

  s.add_dependency('jwt', '~> 2.7.1', '>= 2.7.1')
  s.add_dependency('ffi', '~> 1.15.5', '>= 1.15.5')

  s.required_ruby_version = ">= 3.1.0"
end

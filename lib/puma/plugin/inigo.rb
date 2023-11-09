require 'puma'
require 'puma/plugin'

module Puma
  class Plugin
    module InigoPlugin
      class Error < StandardError; end

      class << self
        attr_writer :config

        def config
          @config ||= Config.new
        end

        def configure
          yield(config)
        end
      end

      # Contents of actual Puma Plugin
      #
      module PluginInstanceMethods
        def start(launcher)
          launcher.events.on_booted do
            if launcher.options[:workers] == 0
              Inigo::Tracer.initialize_tracer(Puma::Plugin::InigoPlugin.config.schema_class.to_definition)
            end
          end
        end
    
        def config(c)
          c.on_worker_boot {
            Inigo::Tracer.initialize_tracer(Puma::Plugin::InigoPlugin.config.schema_class.to_definition) 
          }
        end
      end

      class Config
        attr_accessor :schema_class

        def initialize
          @schema_class = nil
        end
      end
    end
  end
end

Puma::Plugin.create do
  include Puma::Plugin::InigoPlugin::PluginInstanceMethods
end
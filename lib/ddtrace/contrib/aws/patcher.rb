module Datadog
  module Contrib
    module Aws
      COMPATIBLE_WITH = Gem::Version.new('2.0.0')
      SERVICE = 'aws'.freeze
      AGENT = 'aws-sdk-ruby'.freeze
      RESOURCE = 'aws.command'.freeze
      APP = 'aws'.freeze

      module Patcher
        @patched = false

        extend self

        def patch
          return @patched if patched? || !compatible?

          require 'ddtrace/ext/app_types'
          require 'ddtrace/contrib/aws/parsed_context'
          require 'ddtrace/contrib/aws/instrumentation'

          add_pin
          add_plugin(Seahorse::Client::Base, *loaded_constants)

          @patched = true
        rescue => e
          Datadog::Tracer.log.error("Unable to apply AWS integration: #{e}")
          @patched
        end

        def patched?
          @patched
        end

        private

        def compatible?
          return unless defined?(::Aws::VERSION)

          Gem::Version.new(::Aws::VERSION) >= COMPATIBLE_WITH
        end

        def add_pin
          Pin.new(SERVICE, app: APP, app_type: Ext::AppTypes::EXTERNAL).tap do |pin|
            pin.onto(::Aws)
          end
        end

        def add_plugin(*targets)
          targets.each { |klass| klass.add_plugin(Instrumentation) }
        end

        def loaded_constants
          ::Aws::SERVICE_MODULE_NAMES
            .reject { |klass| ::Aws.autoload?(klass) }
            .map { |klass| ::Aws.const_get(klass) }
        end
      end
    end
  end
end

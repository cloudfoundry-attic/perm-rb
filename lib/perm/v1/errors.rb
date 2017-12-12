# frozen_string_literal: true

module CloudFoundry
  module Perm
    module V1
      module Errors
        class StandardError < ::StandardError
        end

        class InvalidCertificateAuthorities < StandardError
        end

        class TransportError < StandardError
          def initialize(msg, original_error)
            @original_error = original_error
            super(msg)
          end

          attr_reader :original_error

          def metadata
            original_error.metadata
          end

          def code
            original_error.code
          end

          def details
            original_error.details
          end

          def to_status
            original_error.to_status
          end
        end
      end
    end
  end
end

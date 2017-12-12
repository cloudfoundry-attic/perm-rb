# frozen_string_literal: true

module CloudFoundry
  module Perm
    module V1
      module Errors
        def self.from_grpc_error(e)
          case e
          when GRPC::AlreadyExists
            AlreadyExists.new(e.code, e.details, e.metadata)
          when GRPC::NotFound
            NotFound.new(e.code, e.details, e.metadata)
          when GRPC::BadStatus
            BadStatus.new(e.code, e.details, e.metadata)
          else
            e
          end
        end

        class StandardError < ::StandardError; end

        class InvalidCertificateAuthorities < StandardError; end

        class BadStatus < ::StandardError
          attr_reader :code, :details, :metadata

          def initialize(code, details = 'unknown cause', metadata = {})
            super("#{code}:#{details}")
            @code = code
            @details = details
            @metadata = metadata
          end
        end

        class AlreadyExists < BadStatus; end
        class NotFound < BadStatus; end
      end
    end
  end
end

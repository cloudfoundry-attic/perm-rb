# frozen_string_literal: true

module CloudFoundry
  module Perm
    module V1
      module Errors
        class Error < StandardError
        end

        class InvalidCertificateAuthorities < Error
        end
      end
    end
  end
end

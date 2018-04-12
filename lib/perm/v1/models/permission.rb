# frozen_string_literal: true

module CloudFoundry
  module Perm
    module V1
      module Models
        class Permission < BaseModel
          attr_reader :action, :resource_pattern

          def initialize(action:, resource_pattern:)
            @action = action
            @resource_pattern = resource_pattern
          end
        end
      end
    end
  end
end

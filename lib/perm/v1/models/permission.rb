module CloudFoundry
  module Perm
    module V1
      module Models
        class Permission < BaseModel
          attr_reader :name, :resource_pattern

          def initialize(name:, resource_pattern:)
            @name = name
            @resource_pattern = resource_pattern
          end
        end
      end
    end
  end
end

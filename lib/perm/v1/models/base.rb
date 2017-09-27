# frozen_string_literal: true

module CloudFoundry
  module Perm
    module V1
      module Models
        class BaseModel
          # Based on https://stackoverflow.com/a/25606643
          def ==(other)
            self.class == other.class && instance_variables.all? do |v|
              instance_variable_get(v) == other.instance_variable_get(v)
            end
          end
        end
      end
    end
  end
end

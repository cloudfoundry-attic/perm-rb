require 'perm/protos'

module CloudFoundry
  module Perm
    module V1
      class Client
        attr_accessor :host

        def initialize(host)
          @host = host
        end

        def assign_role(actor, role, context)
          c = Protos::RoleService::Stub.new(self.host, :this_channel_is_insecure)

          request = Protos::AssignRoleRequest.new(actor: actor, role: role, context: Protos::Context.new(context: context))

          c.assign_role(request)
        end

        def has_role?(actor, role, context)
          c = Protos::RoleService::Stub.new(self.host, :this_channel_is_insecure)

          request = Protos::HasRoleRequest.new(actor: actor, role: role, context: Protos::Context.new(context: context))

          response = c.has_role(request)
          response.hasRole
        end
      end
    end
  end
end

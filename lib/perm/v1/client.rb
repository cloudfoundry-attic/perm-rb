require 'perm/protos'

module CloudFoundry
  module Perm
    module V1
      class Client
        attr_accessor :host

        def initialize(host)
          @host = host
        end

        def create_role(role_name)
          request = Protos::CreateRoleRequest.new(name: role_name)

          response = grpc_client.create_role(request)

          yield response.role
        end

        def assign_role(actor, role_id)
          request = Protos::AssignRoleRequest.new(actor: actor, role_id: role_id)

          grpc_client.assign_role(request)

          nil
        end

        def has_role?(actor, role_id)
          request = Protos::HasRoleRequest.new(actor: actor, role_id: role_id)

          response = grpc_client.has_role(request)
          response.has_role
        end

        private

        def grpc_client
          Protos::RoleService::Stub.new(self.host, :this_channel_is_insecure)
        end
      end
    end
  end
end

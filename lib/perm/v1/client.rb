# frozen_string_literal: true

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

          response.role
        end

        def assign_role(actor, role_name)
          request = Protos::AssignRoleRequest.new(actor: actor, role_name: role_name)

          grpc_client.assign_role(request)

          nil
        end

        # rubocop:disable Naming/PredicateName
        def has_role?(actor, role_name)
          request = Protos::HasRoleRequest.new(actor: actor, role_name: role_name)

          response = grpc_client.has_role(request)
          response.has_role
        end

        def list_actor_roles(actor)
          request = Protos::ListActorRolesRequest.new(actor: actor)

          response = grpc_client.list_actor_roles(request)
          response.roles
        end

        def get_role(name)
          request = Protos::GetRoleRequest.new(name: name)

          response = grpc_client.get_role(request)
          response.role
        end

        private

        def grpc_client
          Protos::RoleService::Stub.new(host, :this_channel_is_insecure)
        end
      end
    end
  end
end

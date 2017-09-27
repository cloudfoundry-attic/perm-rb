# frozen_string_literal: true

require 'perm/protos'

module CloudFoundry
  module Perm
    module V1
      class Client
        attr_accessor :url

        def initialize(url:)
          @url = url
        end

        def create_role(name)
          request = Protos::CreateRoleRequest.new(name: name)

          response = grpc_client.create_role(request)

          response.role
        end

        def get_role(name)
          request = Protos::GetRoleRequest.new(name: name)

          response = grpc_client.get_role(request)
          response.role
        end

        def delete_role(name)
          request = Protos::DeleteRoleRequest.new(name: name)

          grpc_client.delete_role(request)

          nil
        end

        def assign_role(actor:, role_name:)
          request = Protos::AssignRoleRequest.new(actor: actor, role_name: role_name)

          grpc_client.assign_role(request)

          nil
        end

        def unassign_role(actor:, role_name:)
          request = Protos::UnassignRoleRequest.new(actor: actor, role_name: role_name)

          grpc_client.unassign_role(request)

          nil
        end

        # rubocop:disable Naming/PredicateName
        def has_role?(actor:, role_name:)
          request = Protos::HasRoleRequest.new(actor: actor, role_name: role_name)

          response = grpc_client.has_role(request)
          response.has_role
        end

        def list_actor_roles(actor:)
          request = Protos::ListActorRolesRequest.new(actor: actor)

          response = grpc_client.list_actor_roles(request)
          response.roles
        end

        private

        def grpc_client
          Protos::RoleService::Stub.new(url, :this_channel_is_insecure)
        end
      end
    end
  end
end

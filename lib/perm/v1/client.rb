# frozen_string_literal: true

require 'perm/protos'
require 'perm/v1/errors'

module CloudFoundry
  module Perm
    module V1
      class Client
        attr_reader :hostname, :port

        def initialize(hostname:, port: 6283, trusted_cas:, timeout: 15)
          raise ArgumentError, 'trusted_cas cannot be empty' if trusted_cas.empty?

          @hostname = hostname
          @port = port
          @url = "#{hostname}:#{port}"
          @trusted_cas = trusted_cas
          @timeout = timeout
        end

        def create_role(role_name:, permissions: [])
          permission_protos = permissions.map do |p|
            Protos::Permission.new(action: p.action, resource_pattern: p.resource_pattern)
          end
          request = Protos::CreateRoleRequest.new(name: role_name, permissions: permission_protos)

          response = grpc_role_service.create_role(request)
          role = response.role

          Models::Role.new(name: role.name)
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def delete_role(name)
          request = Protos::DeleteRoleRequest.new(name: name)

          grpc_role_service.delete_role(request)

          nil
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def assign_role(role_name:, actor_id:, namespace:)
          actor = Protos::Actor.new(id: actor_id, namespace: namespace)
          request = Protos::AssignRoleRequest.new(actor: actor, role_name: role_name)

          grpc_role_service.assign_role(request)

          nil
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def unassign_role(role_name:, actor_id:, namespace:)
          actor = Protos::Actor.new(id: actor_id, namespace: namespace)
          request = Protos::UnassignRoleRequest.new(actor: actor, role_name: role_name)

          grpc_role_service.unassign_role(request)

          nil
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def assign_role_to_group(role_name:, group_id:)
          group = Protos::Group.new(id: group_id)
          request = Protos::AssignRoleToGroupRequest.new(group: group, role_name: role_name)

          grpc_role_service.assign_role_to_group(request)

          nil
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        # rubocop:disable Naming/PredicateName
        def has_role?(role_name:, actor_id:, namespace:)
          actor = Protos::Actor.new(id: actor_id, namespace: namespace)
          request = Protos::HasRoleRequest.new(actor: actor, role_name: role_name)

          response = grpc_role_service.has_role(request)
          response.has_role
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def has_role_for_group?(role_name:, group_id:)
          group = Protos::Group.new(id: group_id)
          request = Protos::HasRoleForGroupRequest.new(group: group, role_name: role_name)

          response = grpc_role_service.has_role_for_group(request)
          response.has_role
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def list_actor_roles(actor_id:, namespace:)
          actor = Protos::Actor.new(id: actor_id, namespace: namespace)
          request = Protos::ListActorRolesRequest.new(actor: actor)

          response = grpc_role_service.list_actor_roles(request)
          roles = response.roles

          roles.map do |role|
            Models::Role.new(name: role.name)
          end
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def list_role_permissions(role_name:)
          request = Protos::ListRolePermissionsRequest.new(role_name: role_name)

          response = grpc_role_service.list_role_permissions(request)
          permissions = response.permissions

          permissions.map do |permission|
            Models::Permission.new(action: permission.action, resource_pattern: permission.resource_pattern)
          end
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def has_permission?(actor_id:, namespace:, action:, resource:)
          actor = Protos::Actor.new(id: actor_id, namespace: namespace)
          request = Protos::HasPermissionRequest.new(
            actor: actor,
            action: action,
            resource: resource
          )

          response = grpc_permission_service.has_permission(request)
          response.has_permission
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        def list_resource_patterns(actor_id:, namespace:, action:)
          actor = Protos::Actor.new(id: actor_id, namespace: namespace)
          request = Protos::ListResourcePatternsRequest.new(
            actor: actor,
            action: action
          )

          response = grpc_permission_service.list_resource_patterns(request)

          response.resource_patterns
        rescue GRPC::BadStatus => e
          raise Errors.from_grpc_error(e)
        end

        private

        attr_reader :url, :trusted_cas, :timeout

        def tls_credentials
          @tls_credentials ||= GRPC::Core::ChannelCredentials.new(trusted_cas.join("\n"))
        end

        def grpc_role_service
          @grpc_role_service ||= Protos::RoleService::Stub.new(url, tls_credentials, timeout: timeout)
        end

        def grpc_permission_service
          @grpc_permission_service ||= Protos::PermissionService::Stub.new(url, tls_credentials, timeout: timeout)
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'securerandom'
require 'perm_test_helpers'

describe 'Perm' do
  perm_server = nil

  let(:role1_name) { 'role1' }
  let(:role2_name) { 'role2' }
  let(:role3_name) { 'role3' }

  let(:hostname) { perm_server.hostname.clone }
  let(:port) { perm_server.port.clone }

  let(:trusted_cas) { [perm_server.tls_ca.clone] }

  subject(:client) { CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: trusted_cas) }

  before(:all) do
    perm_server = CloudFoundry::PermTestHelpers::ServerRunner.new
    perm_server.start
  end

  after(:all) do
    perm_server.stop
  end

  attr_reader :role1, :role2

  before do
    @role1 = client.create_role(role_name: role1_name)
    @role2 = client.create_role(role_name: role2_name)
    client.create_role(role_name: role3_name)
  end

  after do
    client.delete_role(role1_name)
    client.delete_role(role2_name)
    client.delete_role(role3_name)
  end

  describe 'TLS' do
    let(:cert_path) { File.join(File.dirname(__FILE__), 'support', 'fixtures') }
    let(:extra_ca1) { File.open(File.join(cert_path, 'extra-ca1.crt')).read }
    let(:extra_ca2) { File.open(File.join(cert_path, 'extra-ca2.crt')).read }

    it 'accepts multiple CAs' do
      trusted_cas.unshift(extra_ca1)
      trusted_cas.push(extra_ca2)

      client = CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: trusted_cas)

      expect { client.list_role_permissions(role_name: role1.name) }.not_to raise_error
    end

    it 'accepts concatenated certs' do
      ca_string = [extra_ca1, trusted_cas, extra_ca2].join("\n")

      client = CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: [ca_string])

      expect { client.list_role_permissions(role_name: role1.name) }.not_to raise_error
    end

    it 'errors if there are no CAs' do
      expect do
        CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: [])
      end.to raise_error ArgumentError
    end

    it "errors if no CAs match the server's certificate" do
      trusted_cas = [extra_ca1, extra_ca2]
      client = CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: trusted_cas)

      expect { client.list_role_permissions(role_name: role1.name) }.to raise_error CloudFoundry::Perm::V1::Errors::BadStatus
    end
  end

  describe 'when the server has a keepalive that is less than the amount of time between requests to different services' do
    server_with_short_keepalive = nil

    before(:all) do
      opts = { keepalive: '1ns' }
      server_with_short_keepalive = CloudFoundry::PermTestHelpers::ServerRunner.new(opts)
      server_with_short_keepalive.start
    end

    after(:all) do
      server_with_short_keepalive.stop
    end

    it 'successfully handles GOAWAY messages' do
      client = CloudFoundry::Perm::V1::Client.new(
        hostname: server_with_short_keepalive.hostname,
        port: server_with_short_keepalive.port,
        trusted_cas: trusted_cas
      )

      expect do
        client.has_permission?(actor_id: SecureRandom.uuid, namespace: SecureRandom.uuid, action: 'action-1', resource: 'resource-pattern-1')
        sleep 0.1
        client.create_role(role_name: SecureRandom.uuid, permissions: [])
        client.has_permission?(actor_id: SecureRandom.uuid, namespace: SecureRandom.uuid, action: 'action-1', resource: 'resource-pattern-1')
      end.not_to raise_error
    end
  end

  describe 'creating a role' do
    after do
      client.delete_role('test-role')
    end

    it 'saves the permissions associated with the role' do
      role_name = 'test-role'

      permission1 = CloudFoundry::Perm::V1::Models::Permission.new(
        action: 'action-1',
        resource_pattern: 'resource-pattern-1'
      )
      permission2 = CloudFoundry::Perm::V1::Models::Permission.new(
        action: 'action-2',
        resource_pattern: 'resource-pattern-2'
      )

      role = client.create_role(role_name: role_name, permissions: [permission1, permission2])
      expect(role.name).to eq(role_name)
      expect(role.name).to be_a(String)

      retrieved_permissions = client.list_role_permissions(role_name: role_name)

      expect(retrieved_permissions).to contain_exactly(permission1, permission2)
    end
  end

  describe 'assigning a role to an actor' do
    let(:actor1) { 'test-actor1' }
    let(:actor2) { 'test-actor2' }
    let(:namespace) { 'https://test.example.com' }

    after do
      client.unassign_role(role_name: role1.name, actor_id: actor1, namespace: namespace)
    end

    it 'calls to the external service, assigning the role' do
      client.assign_role(role_name: role1.name, actor_id: actor1, namespace: namespace)

      expect(client.has_role?(role_name: role1.name, actor_id: actor1, namespace: namespace)).to be true

      expect(client.has_role?(role_name: role1.name, actor_id: actor2, namespace: namespace)).to be false
      expect(client.has_role?(role_name: role2.name, actor_id: actor1, namespace: namespace)).to be false
      expect(client.has_role?(role_name: SecureRandom.uuid, actor_id: actor1, namespace: namespace)).to be false
    end
  end

  describe 'assigning a role to a group' do
    let(:group1) { 'test-group1' }
    let(:group2) { 'test-group2' }

    after do
      client.unassign_role_from_group(role_name: role1.name, group_id: group1)
    end

    it 'calls to the external service, assigning the role' do
      client.assign_role_to_group(role_name: role1.name, group_id: group1)

      expect(client.has_role_for_group?(role_name: role1.name, group_id: group1)).to be true

      expect(client.has_role_for_group?(role_name: role1.name, group_id: group2)).to be false
      expect(client.has_role_for_group?(role_name: role2.name, group_id: group1)).to be false
      expect(client.has_role_for_group?(role_name: SecureRandom.uuid, group_id: group1)).to be false
    end
  end

  describe 'asking if someone has a permission' do
    let(:actor) { 'test-actor' }
    let(:actor2) { 'test-actor-2' }
    let(:group) { 'test-group' }
    let(:namespace) { 'https://test.example.com' }
    let(:role_name) { 'test-role' }
    let(:permission1) do
      CloudFoundry::Perm::V1::Models::Permission.new(
        action: 'action-1',
        resource_pattern: 'resource-pattern-1'
      )
    end
    let(:permission2) do
      CloudFoundry::Perm::V1::Models::Permission.new(
        action: 'action-2',
        resource_pattern: 'resource-pattern-2'
      )
    end

    after do
      client.delete_role(role_name)
    end

    it 'checks for any role assignments for roles with permissions that match the given permission and resource identifier' do
      client.create_role(role_name: role_name, permissions: [permission1, permission2])
      client.assign_role(role_name: role_name, actor_id: actor, namespace: namespace)

      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-1', resource: 'resource-pattern-1')).to be true
      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-2', resource: 'resource-pattern-2')).to be true

      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-1', resource: 'resource-pattern-2')).to be false
      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-2', resource: 'resource-pattern-1')).to be false

      expect(client.has_permission?(actor_id: actor2, namespace: namespace, action: 'action-2', resource: 'resource-pattern-1')).to be false

      client.unassign_role(role_name: role_name, actor_id: actor, namespace: namespace)
    end

    it 'checks if the groups are assigned to roles with or without permission' do
      client.create_role(role_name: role_name, permissions: [permission1, permission2])
      client.assign_role_to_group(role_name: role_name, group_id: group)

      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-1', resource: 'resource-pattern-1', group_ids: [group])).to be true
      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-2', resource: 'resource-pattern-2', group_ids: [group])).to be true

      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-1', resource: 'resource-pattern-2', group_ids: [group])).to be false
      expect(client.has_permission?(actor_id: actor, namespace: namespace, action: 'action-2', resource: 'resource-pattern-1', group_ids: [group])).to be false

      client.unassign_role_from_group(role_name: role_name, group_id: group)
    end
  end

  describe 'listing the resource patterns an actor has a particular permission for' do
    let(:actor) { 'test-actor' }
    let(:namespace) { 'https://test.example.com' }
    let(:role_name) { 'test-role' }
    let(:group_role_name) { 'group-role-name' }
    let(:action) { 'action' }
    let(:groups) { ['group'] }
    let(:resource_pattern) { SecureRandom.uuid }
    let(:group_resource_pattern) { SecureRandom.uuid }
    let(:permission) do
      CloudFoundry::Perm::V1::Models::Permission.new(
        action: action,
        resource_pattern: resource_pattern
      )
    end
    let(:group_permission) do
      CloudFoundry::Perm::V1::Models::Permission.new(
        action: action,
        resource_pattern: group_resource_pattern
      )
    end

    before do
      client.create_role(role_name: role_name, permissions: [permission])
      client.assign_role(role_name: role_name, actor_id: actor, namespace: namespace)
    end

    after do
      client.delete_role(role_name)
    end

    it 'returns the list of resource patterns' do
      returned_resources = client.list_resource_patterns(
        actor_id: actor,
        namespace: namespace,
        action: action
      )

      expect(returned_resources).to eq([resource_pattern])
    end

    it 'returns the list of resource patterns for groups if they are specified' do
      client.create_role(role_name: group_role_name, permissions: [group_permission])
      client.assign_role_to_group(role_name: group_role_name, group_id: 'group')

      returned_roles = client.list_resource_patterns(
        actor_id: actor,
        namespace: namespace,
        action: action,
        group_ids: groups
      )
      expect(returned_roles).to eq([resource_pattern, group_resource_pattern])
    end
  end
end

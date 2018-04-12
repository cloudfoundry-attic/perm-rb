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

      expect { client.get_role(role1.name) }.not_to raise_error
    end

    it 'accepts concatenated certs' do
      ca_string = [extra_ca1, trusted_cas, extra_ca2].join("\n")

      client = CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: [ca_string])

      expect { client.get_role(role1.name) }.not_to raise_error
    end

    it 'errors if there are no CAs' do
      expect do
        CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: [])
      end.to raise_error ArgumentError
    end

    it "errors if no CAs match the server's certificate" do
      trusted_cas = [extra_ca1, extra_ca2]
      client = CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port, trusted_cas: trusted_cas)

      expect { client.get_role(role1.name) }.to raise_error CloudFoundry::Perm::V1::Errors::BadStatus
    end
  end

  describe 'creating a role' do
    after do
      client.delete_role('test-role')
    end

    it 'saves the role' do
      role_name = 'test-role'
      role = client.create_role(role_name: role_name)

      expect(role.name).to eq(role_name)
      expect(role.name).to be_a(String)

      retrieved_role = client.get_role(role_name)

      expect(role).to eq(retrieved_role)
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

      client.create_role(role_name: role_name, permissions: [permission1, permission2])

      retrieved_permissions = client.list_role_permissions(role_name: role_name)

      expect(retrieved_permissions).to contain_exactly(permission1, permission2)
    end
  end

  describe 'assigning a role' do
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

  describe 'listing roles for an actor' do
    let(:actor) { 'test-actor' }
    let(:namespace) { 'https://test.example.com' }

    after do
      client.unassign_role(role_name: role1.name, actor_id: actor, namespace: namespace)
      client.unassign_role(role_name: role2.name, actor_id: actor, namespace: namespace)
    end

    it 'lists all roles assigned to the actor' do
      roles = client.list_actor_roles(actor_id: actor, namespace: namespace)

      expect(roles).to be_empty

      client.assign_role(role_name: role1.name, actor_id: actor, namespace: namespace)
      client.assign_role(role_name: role2.name, actor_id: actor, namespace: namespace)

      roles = client.list_actor_roles(actor_id: actor, namespace: namespace)

      expect(roles).to contain_exactly(role1, role2)
    end
  end

  describe 'asking if someone has a permission' do
    let(:actor) { 'test-actor' }
    let(:actor2) { 'test-actor-2' }
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
      client.unassign_role(role_name: role_name, actor_id: actor, namespace: namespace)
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
    end
  end

  describe 'listing the resource patterns an actor has a particular permission for' do
    let(:actor) { 'test-actor' }
    let(:namespace) { 'https://test.example.com' }
    let(:role_name) { 'test-role' }
    let(:action) { 'action' }
    let(:resource_pattern) { SecureRandom.uuid }
    let(:permission) do
      CloudFoundry::Perm::V1::Models::Permission.new(
        action: action,
        resource_pattern: resource_pattern
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
      returned_roles = client.list_resource_patterns(
        actor_id: actor,
        namespace: namespace,
        action: action
      )

      expect(returned_roles).to eq([resource_pattern])
    end
  end
end

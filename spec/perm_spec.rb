# frozen_string_literal: true

require 'securerandom'

describe 'Perm' do
  let(:role1_name) { 'role1' }
  let(:role2_name) { 'role2' }
  let(:role3_name) { 'role3' }

  let(:hostname) { ENV.fetch('PERM_RPC_HOST') { 'localhost' } }
  let(:port) { ENV.fetch('PERM_RPC_PORT') { '6283' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(hostname: hostname, port: port) }

  attr_reader :role1, :role2
  before do
    @role1 = client.create_role(role1_name)
    @role2 = client.create_role(role2_name)
    client.create_role(role3_name)
  end

  after do
    client.delete_role(role1_name)
    client.delete_role(role2_name)
    client.delete_role(role3_name)
  end

  describe 'creating a role' do
    it 'saves the role' do
      role_name = 'test-role'
      role = client.create_role(role_name)

      expect(role.name).to eq(role_name)
      expect(role.name).to be_a(String)
      expect(role.id).not_to be_empty

      retrieved_role = client.get_role(role_name)

      expect(role).to eq(retrieved_role)
    end

    after do
      client.delete_role('test-role')
    end
  end

  describe 'assigning a role' do
    let(:actor1) { 'test-actor1' }
    let(:actor2) { 'test-actor2' }
    let(:issuer) { 'https://test.example.com' }

    after do
      client.unassign_role(role_name: role1.name, actor_id: actor1, issuer: issuer)
    end

    it 'calls to the external service, assigning the role' do
      client.assign_role(role_name: role1.name, actor_id: actor1, issuer: issuer)

      expect(client.has_role?(role_name: role1.name, actor_id: actor1, issuer: issuer)).to be true

      expect(client.has_role?(role_name: role1.name, actor_id: actor2, issuer: issuer)).to be false
      expect(client.has_role?(role_name: role2.name, actor_id: actor1, issuer: issuer)).to be false
      expect(client.has_role?(role_name: SecureRandom.uuid, actor_id: actor1, issuer: issuer)).to be false
    end
  end

  describe 'listing roles for an actor' do
    let(:actor) { 'test-actor' }
    let(:issuer) { 'https://test.example.com' }

    after do
      client.unassign_role(role_name: role1.name, actor_id: actor, issuer: issuer)
      client.unassign_role(role_name: role2.name, actor_id: actor, issuer: issuer)
    end

    it 'lists all roles assigned to the actor' do
      roles = client.list_actor_roles(actor_id: actor, issuer: issuer)

      expect(roles).to be_empty

      client.assign_role(role_name: role1.name, actor_id: actor, issuer: issuer)
      client.assign_role(role_name: role2.name, actor_id: actor, issuer: issuer)

      roles = client.list_actor_roles(actor_id: actor, issuer: issuer)

      expect(roles).to contain_exactly(role1, role2)
    end
  end
end

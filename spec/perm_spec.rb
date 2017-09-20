# frozen_string_literal: true

require 'securerandom'

describe 'Perm' do
  let(:role1_name) { 'role1' }
  let(:role2_name) { 'role2' }
  let(:role3_name) { 'role3' }

  let(:host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:6283' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(host) }

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
    it 'calls to the external service, assigning the role' do
      actor1 = CloudFoundry::Perm::V1::Models::Actor.new(id: 'test-actor1', issuer: 'https://test.example.com')
      actor2 = CloudFoundry::Perm::V1::Models::Actor.new(id: 'test-actor2', issuer: 'https://test.example.com')

      client.assign_role(actor1, role1.name)

      expect(client.has_role?(actor1, role1.name)).to be true

      expect(client.has_role?(actor2, role1.name)).to be false
      expect(client.has_role?(actor1, role2.name)).to be false
      expect(client.has_role?(actor1, SecureRandom.uuid)).to be false
    end
  end

  describe 'listing roles for an actor' do
    it 'lists all roles assigned to the actor' do
      actor = CloudFoundry::Perm::V1::Models::Actor.new(id: 'test-actor', issuer: 'https://test.example.com')

      roles = client.list_actor_roles(actor)

      expect(roles).to be_empty

      client.assign_role(actor, role1.name)
      client.assign_role(actor, role2.name)

      roles = client.list_actor_roles(actor)

      expect(roles).to contain_exactly(role1, role2)
    end
  end
end

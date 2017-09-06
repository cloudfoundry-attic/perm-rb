require 'securerandom'

describe 'Perm' do
  let(:host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:8888' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(host)  }

  attr_reader :role1, :role2
  before do
    @role1 = client.create_role('role1')
    @role2 = client.create_role('role2')
    client.create_role('role3')
  end

  describe 'assigning a role' do
    it 'calls to the external service, assigning the role' do
      client.assign_role('test-actor', role1.id)

      expect(client.has_role?('test-actor', role1.id)).to be true

      expect(client.has_role?('test-actor2', role1.id)).to be false
      expect(client.has_role?('test-actor', role2.id)).to be false
      expect(client.has_role?('test-actor', SecureRandom.uuid)).to be false
    end
  end

  describe 'listing roles for an actor' do
    it 'lists all roles assigned to the actor' do
      actor = 'list-roles-actor'

      roles = client.list_actor_roles(actor)

      expect(roles).to be_empty

      client.assign_role(actor, role1.id)
      client.assign_role(actor, role2.id)

      roles = client.list_actor_roles(actor)

      expect(roles).to contain_exactly(role1, role2)
    end
  end
end

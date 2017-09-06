require 'securerandom'

describe 'Perm' do
  let(:host) { ENV.fetch('PERM_RPC_HOST') { 'localhost:8888' } }
  let(:client) { CloudFoundry::Perm::V1::Client.new(host)  }
  describe 'assigning a role' do
    it 'calls to the external service, assigning the role' do
      client.create_role('test-role') do |role|
        expect(role).not_to be_nil

        client.assign_role('test-actor', role.id)

        expect(client.has_role?('test-actor', role.id)).to be true

        expect(client.has_role?('test-actor2', role.id)).to be false
        expect(client.has_role?('test-actor', SecureRandom.uuid)).to be false
      end
    end
  end

  describe 'listing roles for an actor' do
    it 'lists all roles assigned to the actor' do
      actor = 'list-roles-actor'
      captured_role1 = nil
      captured_role2 = nil

      client.create_role('role1') { |role| captured_role1 = role }
      client.create_role('role2') { |role| captured_role2 = role }
      client.create_role('role3')

      roles = client.list_actor_roles(actor)

      expect(roles).to be_empty

      client.assign_role(actor, captured_role1.id)
      client.assign_role(actor, captured_role2.id)

      roles = client.list_actor_roles(actor)

      expect(roles).to contain_exactly(captured_role1, captured_role2)
    end
  end
end

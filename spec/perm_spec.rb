require 'securerandom'

describe 'Perm' do
  describe 'assigning a role' do
    it 'calls to the external service, assigning the role' do
      host = ENV.fetch('PERM_RPC_HOST') { 'localhost:8888' }
      client = CloudFoundry::Perm::V1::Client.new(host)

      client.create_role('test-role') do |role|
        expect(role).not_to be_nil

        client.assign_role('test-actor', role.id)

        expect(client.has_role?('test-actor', role.id)).to be true

        expect(client.has_role?('test-actor2', role.id)).to be false
        expect(client.has_role?('test-actor', SecureRandom.uuid)).to be false
      end
    end
  end
end

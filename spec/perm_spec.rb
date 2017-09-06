describe 'Perm' do
  describe 'assigning a role' do
    it 'calls to the external service, assigning the role' do
      host = ENV.fetch('PERM_RPC_HOST') { 'localhost:8888' }
      client = CloudFoundry::Perm::V1::Client.new(host)

      client.assign_role('test-actor', 'test-role', {'foo' => 'bar'})

      expect(client.has_role?('test-actor', 'test-role', {'foo' => 'bar'})).to be true

      expect(client.has_role?('test-actor2', 'test-role', {'foo' => 'bar'})).to be false
      expect(client.has_role?('test-actor', 'test-role2', {'foo' => 'bar'})).to be false
      expect(client.has_role?('test-actor', 'test-role', {'foo' => 'baz'})).to be false
    end
  end
end

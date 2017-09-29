# frozen_string_literal: true

require 'socket'
require 'subprocess'

module CloudFoundry
  module PermTestHelpers
    class ServerRunner
      attr_reader :hostname, :port, :tls_cas

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength
      def initialize(opts = {})
        cwd = File.dirname(__FILE__)
        cert_path = File.join(cwd, '..', 'fixtures', 'certs')

        @hostname = opts[:hostname] || ENV['PERM_TEST_HOSTNAME'] || 'localhost'
        @port = opts[:port] || ENV['PERM_TEST_PORT'] || random_port
        @perm_path = opts[:perm_path] || ENV['PERM_TEST_PATH'] || 'perm'
        @log_level = opts[:log_level] || ENV['PERM_TEST_LOG_LEVEL'] || 'fatal'
        @tls_cert = opts[:tls_cert_path] || ENV['PERM_TEST_TLS_CERT_PATH'] || File.join(cert_path, 'tls.crt')
        @tls_key = opts[:tls_key_path] || ENV['PERM_TEST_TLS_KEY_PATH'] || File.join(cert_path, 'tls.key')
        tls_ca = opts[:tls_cas] || ENV['PERM_TEST_TLS_CAS'] || File.join(cert_path, 'tls_ca.crt')
        @tls_cas = tls_ca.split(',').map { |f| File.open(f).read }
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength

      def start
        @process ||= start_perm
      end

      def stop
        @process&.terminate
        @process = nil
      end

      private

      attr_writer :port
      attr_reader :perm_path, :log_level, :process, :tls_cert, :tls_key

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def start_perm
        retries = 0
        process = nil

        begin
          listen_port = port || random_port
          cmd = [
            perm_path,
            '--listen-hostname', hostname,
            '--listen-port', listen_port.to_s,
            '--log-level', log_level,
            '--tls-certificate', tls_cert,
            '--tls-key', tls_key
          ]

          process = Subprocess.popen(cmd)
          wait_for_server(process.pid)
          @port = listen_port

          process
        rescue Errno::ESRCH => e
          # Retry in case the random port is taken
          retries += 1
          process.terminate

          retry if retries < 3
          raise e
        rescue Errno::ENOENT
          raise 'perm_path must point to server executable'
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def random_port
        rand(65_000 - 1024) + 1024
      end

      # Wait for the server to actually start accepting connections
      def wait_for_server(pid)
        time_waited = 0

        begin
          Process.getpgid(pid)

          TCPSocket.new(hostname, port).close
        rescue Errno::ECONNREFUSED
          time_waited += 0.1

          raise 'Perm server not running after 5 seconds' if time_waited >= 5

          sleep 0.1
          retry
        end
      end
    end
  end
end

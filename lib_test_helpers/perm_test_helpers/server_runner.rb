# frozen_string_literal: true

require 'mysql'
require 'securerandom'
require 'socket'
require 'subprocess'

module CloudFoundry
  module PermTestHelpers
    class ServerRunner
      attr_reader :hostname, :port, :tls_ca, :tls_ca_path

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def initialize(opts = {})
        cwd = File.dirname(__FILE__)
        cert_path = File.join(cwd, '..', 'fixtures', 'certs')

        options = Options.new(opts)

        @hostname = options.attr(:hostname, 'PERM_TEST_HOSTNAME', 'localhost')
        @port = options.attr(:port, 'PERM_TEST_PORT', random_port)
        @perm_path = options.attr(:perm_path, 'PERM_TEST_PATH', 'perm')
        @log_level = options.attr(:log_level, 'PERM_TEST_LOG_LEVEL', 'fatal')
        @tls_cert = options.attr(:tls_cert_path, 'PERM_TEST_TLS_CERT_PATH', File.join(cert_path, 'tls.crt'))
        @tls_key = options.attr(:tls_key_path, 'PERM_TEST_TLS_KEY_PATH', File.join(cert_path, 'tls.key'))
        @tls_ca_path = options.attr(:tls_ca_path, 'PERM_TEST_TLS_CA_PATH', File.join(cert_path, 'tls_ca.crt'))
        @audit_file_path = options.attr(:audit_file_path, 'PERM_TEST_AUDIT_FILE_PATH', '/dev/null')
        @tls_ca = File.open(tls_ca_path).read
        @keepalive = options.attr(:keepalive, 'PERM_TEST_KEEPALIVE', '10s')

        @stdout = options.attr(:stdout, 'PERM_TEST_STDOUT_PATH', STDOUT)
        @stderr = options.attr(:stderr, 'PERM_TEST_STDERR_PATH', STDERR)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def start
        @process ||= start_perm
      end

      def stop
        @process&.terminate
        @process = nil
      end

      private

      class Options
        def initialize(opts)
          @opts = opts
        end

        def attr(key, env, default)
          @opts[key] || ENV[env] || default
        end
      end

      attr_writer :port
      attr_reader :perm_path, :log_level, :process, :tls_cert, :tls_key, :audit_file_path, :keepalive
      attr_reader :stdout, :stderr

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def start_perm
        retries = 0
        process = nil

        begin
          cmd = [
            perm_path,
            'serve',
            '--listen-hostname', hostname,
            '--listen-port', port.to_s,
            '--log-level', log_level,
            '--tls-certificate', tls_cert,
            '--tls-key', tls_key,
            '--db-driver', 'in-memory',
            '--audit-file-path', audit_file_path,
            '--max-connection-idle', @keepalive
          ]

          process = Subprocess.popen(cmd, stdout: stdout, stderr: stderr)
          wait_for_server(process.pid)

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
        rescue Errno::ECONNREFUSED, Errno::EAFNOSUPPORT
          time_waited += 0.1

          raise 'Perm server not running after 5 seconds' if time_waited >= 5

          sleep 0.1
          retry
        end
      end
    end
  end
end

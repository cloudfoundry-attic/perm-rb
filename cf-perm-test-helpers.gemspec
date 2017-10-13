# frozen_string_literal: true

lib = File.expand_path('../lib_test_helpers/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'perm_test_helpers/version'

Gem::Specification.new do |s|
  s.name = 'cf-perm-test-helpers'
  s.version = CloudFoundry::PermTestHelpers::VERSION
  s.author = 'CloudFoundry Permissions Team'
  s.summary = 'Test helpers for CloudFoundry Permissions'

  s.files = Dir.glob('{bin,lib}/**/*')
  s.files += %w[LICENSE NOTICE README.md]
  s.license = 'Apache-2.0'

  s.require_paths = ['lib_test_helpers']

  s.add_dependency 'subprocess', '~> 1'
  s.add_dependency 'ruby-mysql', '~> 2.9.14'
end

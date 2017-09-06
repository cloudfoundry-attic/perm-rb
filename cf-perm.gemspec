lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'perm/version'

Gem::Specification.new do |s|
  s.name = 'cf-perm'
  s.version = CloudFoundry::Perm::VERSION
  s.author = 'CloudFoundry Permissions Team'
  s.summary = 'Ruby client for CloudFoundry Permissions'

  s.files = Dir.glob('{bin,lib}/**/*')
  s.files += %w[LICENSE NOTICE README.md]
  s.license = 'Apache-2.0'

  s.require_paths = ['lib']

  # Do this so that any generated protobuf code can use `require 'other_file'`
  # and work automatically
  # See https://github.com/ruby-protobuf/protobuf/issues/240
  s.require_paths << 'lib/perm/protos'

  s.add_dependency 'grpc', '~> 1.0'

  s.add_development_dependency 'rspec', '~> 3.6.0'
end

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'perm/version'

Gem::Specification.new do |s|
  s.name = 'cf-perm'
  s.version = CF::Perm::VERSION
  s.author = 'CF Permissions Team'
  s.summary = 'Ruby client for CF Permissions'

  s.files = Dir.glob('{bin,lib}/**/*')
  s.files += %w[LICENSE NOTICE README.md]
  s.license = 'Apache-2.0'

  s.require_paths = ['lib']

  s.add_development_dependency 'rspec', '~> 3.6.0'
end

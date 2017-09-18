# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new

  require 'rubocop/rake_task'
  RuboCop::RakeTask.new do |task|
    task.options = %w[--display-cop-names]
  end

  task default: %i[spec rubocop]
# rubocop:disable Lint/HandleExceptions
rescue LoadError
end

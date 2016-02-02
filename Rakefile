
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec)

task :default => [:spec, :test]

Rake::TestTask.new do |t|
  t.pattern = "test/**/*_test.rb"
end

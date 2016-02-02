# from https://github.com/redis-store/redis-activesupport/blob/master/test/test_helper.rb
require 'bundler/setup'
require 'minitest/autorun'
require 'mocha/setup'
require 'active_support'
require 'active_support/cache/redis_store'

#puts "Testing against ActiveSupport v.#{ActiveSupport::VERSION::STRING}"

require 'encrypted_store'
require 'encrypted_store/initialize'

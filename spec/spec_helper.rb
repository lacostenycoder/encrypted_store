$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

ENV["RAILS_ENV"] ||= 'test'

require 'rubygems'

# Only the parts of rails we want to use
# if you want everything, use "rails/all"
#require "rails/all"
require "action_controller/railtie"
require 'action_view/railtie'
require "rails/test_unit/railtie"

require 'encrypted_store'
require 'encrypted_store/initialize'

root = File.expand_path(File.dirname(__FILE__))

require 'rspec/rails'

RSpec.configure do |config|
  config.infer_base_class_for_anonymous_controllers = false
end

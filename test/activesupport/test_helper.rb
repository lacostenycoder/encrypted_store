# Only the parts of rails we want to use
# if you want everything, use "rails/all"
#require "rails/all"
require "action_controller/railtie"
require 'action_view/railtie'
require "rails/test_unit/railtie"

root = File.expand_path(File.dirname(__FILE__))

require 'rails/test_help'

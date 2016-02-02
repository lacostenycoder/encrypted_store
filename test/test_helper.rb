$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../activesupport', __FILE__)
$LOAD_PATH.unshift File.expand_path('../redis-activesupport', __FILE__)

ENV["RAILS_ENV"] ||= 'test'

require 'rubygems'

# try to separate out all the tests i pulled in from other projects
require_relative './activesupport/test_helper'
require_relative './redis-activesupport/test_helper'

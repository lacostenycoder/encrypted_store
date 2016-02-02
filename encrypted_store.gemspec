# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'encrypted_store/version'

Gem::Specification.new do |spec|
  spec.name          = "encrypted_store"
  spec.version       = EncryptedStore::VERSION
  spec.authors       = ["jonathan schatz"]
  spec.email         = ["modosc@users.noreply.github.com"]

  spec.summary       = %q{Adds transparent encryption to the Rails cache.}
#  spec.description   = %q{Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/modosc/encrypted_store"


  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "~> 4.0"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-rails"
  spec.add_development_dependency "rails", "~> 4.0"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "dalli"
  spec.add_development_dependency "redis-activesupport", '~> 4.0'
  spec.add_development_dependency "connection_pool"
end

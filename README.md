# EncryptedStore

This gem adds transparent encryption to the Rails cache. It supports the following cache stores:

* [FileStore](http://api.rubyonrails.org/classes/ActiveSupport/Cache/FileStore.html)
* [MemCacheStore](http://api.rubyonrails.org/classes/ActiveSupport/Cache/MemCacheStore.html)
* [MemoryStore](http://api.rubyonrails.org/classes/ActiveSupport/Cache/MemoryStore.html)
* [NullStore](http://api.rubyonrails.org/classes/ActiveSupport/Cache/NullStore.html)
* [RedisStore](https://github.com/redis-store/redis-activesupport)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'encrypted_store'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install encrypted_store

## Usage

### Rails
By default optional encryption using your application's `secret_key_base` is enabled for all stores.

To encrypt a specific key pass in the `encrypt: true` option to your cache call:

    Rails.cache.fetch 'a-key', encrypt: true do
      {a: 1, b: 2, c: 3}
    end

To make encryption the default behavior:

    config.cache_store = :mem_cache_store, 'localhost', encrypt: true

To use a custom encryption key:

    config.cache_store = :mem_cache_store, 'localhost', encryption_key: ENV['ANOTHER_KEY']

This will work fine with compression - when both options are enabled a value is compressed first and then encrypted (compressing an encrypted value will result in insignificant savings at best).

All other cache options / functionality should still work.

I haven't tested it yet but this _should_ work with [ActionDispatch::Session::CacheStore](http://api.rubyonrails.org/classes/ActionDispatch/Session/CacheStore.html).


### No Rails
You will need to manually initialize `encrypted_store` before you create your cache:

    require 'encrypted_store/initialize'

`encryption_key` is required since there's no `secret_key_base` to fall back on:

    CACHE = ActiveSupport::Cache.lookup_store :mem_cache_store, 'localhost', encrypt: true, encryption_key: ENV['MY_KEY']

Usage is otherwise identical to the `Rails` section above:

    CACHE.fetch 'a-key', encrypt: true do
      {a: 1, b: 2, c: 3}
    end

### Encryption Key
`EncryptedStore` uses a single global encryption key. This is to avoid storing the encryption key inside of the serialized [ActiveSupport::Cache::Entry](http://apidock.com/rails/ActiveSupport/Cache/Entry) that's directly stored in the cache store (and thus defeating the purpose of this gem).

`EncryptedStore` uses [ActiveSupport::MessageEncryptor](http://api.rubyonrails.org/classes/ActiveSupport/MessageEncryptor.html)  under the hood for encryption which (apparently) [uses the `aes-256-cbc` cipher by default](http://www.monkeyandcrow.com/blog/reading_rails_how_does_message_encryptor_work/).

To generate an appropriate key:

    2.3.0 :001> SecureRandom.hex(64)
    => "1e1514226155cf1f98356cac25498f461ac224e79557caaeea8dc2827910d3b64a5c1daf741ef72d35676c6534c6eb5dcf59c86d96e
## Future

* support for ([DalliStore](https://github.com/petergoldstein/dalli) (if you need `memcached` support you can use the built-in `MemCacheStore` which uses `dalli` under the hood anyway)
* add tests/support for [ActionDispatch::Session::CacheStore](http://api.rubyonrails.org/classes/ActionDispatch/Session/CacheStore.html)

## Development

After checking out the repo, run `bundle` to install dependencies.

The test suite contains several disparate pieces:

1. `test/activesupport` contains the [caching tests](https://github.com/rails/rails/blob/4-2-stable/activesupport/test/caching_test.rb) from the most current stable version of `rails`
2. `test/redis-activesupport` contains the [tests](https://github.com/redis-store/redis-activesupport/blob/master/test/active_support/cache/redis_store_test.rb) from the most current version of `redis-activesupport`
3. `spec/*` contains gem specific tests

Both of the externally sourced tests are modified to run twice, once with default encryption disabled and once with it enabled. There are more combinations we could test but for now this seems to be enough.

To run the test suite you will need:

1. an instance of [memcached](http://memcached.org/) listening on port 11121
2. two instances of [redis](http://redis.io/) listening on 6379 and 6380
Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

The default `rake` task will run all of the tests. To run only the external tests use `rake test` and to run the gem specific tests use `rake spec`

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/modosc/encrypted_store.


## License

`encrypted_store` is released under the [MIT License](http://www.opensource.org/licenses/MIT).

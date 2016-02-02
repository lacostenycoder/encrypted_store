require_relative '../test_helper'
require 'ostruct'
require 'connection_pool'

describe ActiveSupport::Cache::RedisStore do
  def setup
    @store  = ActiveSupport::Cache::RedisStore.new
    @dstore = ActiveSupport::Cache::RedisStore.new "redis://127.0.0.1:6379/5", "redis://127.0.0.1:6379/6"
    @pool_store  = ActiveSupport::Cache::RedisStore.new("redis://127.0.0.1:6379/2", pool_size: 5, pool_timeout: 10)
    @external_pool_store = ActiveSupport::Cache::RedisStore.new(pool: ::ConnectionPool.new(size: 1, timeout: 1) { ::Redis::Store::Factory.create("redis://127.0.0.1:6379/3") })

    @pool_store.data.class.must_equal ::ConnectionPool
    @pool_store.data.instance_variable_get(:@size).must_equal 5
    @external_pool_store.data.class.must_equal ::ConnectionPool
    @external_pool_store.data.instance_variable_get(:@size).must_equal 1


    @rabbit = OpenStruct.new :name => "bunny"
    @white_rabbit = OpenStruct.new :color => "white"

    with_store_management do |store|
      store.write "rabbit", @rabbit
      store.delete "counter"
      store.delete "rub-a-dub"
    end
  end

  it "connects using an hash of options" do
    address = { host: '127.0.0.1', port: '6380', db: '1' }
    store = ActiveSupport::Cache::RedisStore.new(address.merge(pool_size: 5, pool_timeout: 10))
    redis = Redis.new(url: "redis://127.0.0.1:6380/1")
    redis.flushall

    store.data.class.must_equal(::ConnectionPool)
    store.data.instance_variable_get(:@size).must_equal(5)
    store.data.instance_variable_get(:@timeout).must_equal(10)

    store.write("rabbit", 0)

    redis.exists("rabbit").must_equal(true)
  end

  it "connects using an string of options" do
    address = "redis://127.0.0.1:6380/1"
    store = ActiveSupport::Cache::RedisStore.new(address, pool_size: 5, pool_timeout: 10)
    redis = Redis.new(url: address)
    redis.flushall

    store.data.class.must_equal(::ConnectionPool)
    store.data.instance_variable_get(:@size).must_equal(5)
    store.data.instance_variable_get(:@timeout).must_equal(10)

    store.write("rabbit", 0)

    redis.exists("rabbit").must_equal(true)
  end

  it "raises an error if :pool isn't a pool" do
    assert_raises(RuntimeError, 'pool must be an instance of ConnectionPool') do
      ActiveSupport::Cache::RedisStore.new(pool: 'poolio')
    end
  end

  it "namespaces all operations" do
    address = "redis://127.0.0.1:6380/1/cache-namespace"
    store   = ActiveSupport::Cache::RedisStore.new(address)
    redis   = Redis.new(url: address)

    store.write("white-rabbit", 0)

    redis.exists('cache-namespace:white-rabbit').must_equal(true)
  end

  it "creates a normal store when given no addresses" do
    underlying_store = instantiate_store
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a normal store when given options only" do
    underlying_store = instantiate_store(:expires_in => 1.second)
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a normal store when given a single address" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1")
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a normal store when given a single address and options" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1",
                                         { :expires_in => 1.second})
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a distributed store when given multiple addresses" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1",
                                         "redis://127.0.0.1:6381/1")
    underlying_store.must_be_instance_of(::Redis::DistributedStore)
  end

  it "creates a distributed store when given multiple address and options" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1",
                                         "redis://127.0.0.1:6381/1",
                                         :expires_in => 1.second)
    underlying_store.must_be_instance_of(::Redis::DistributedStore)
  end

  it "reads the data" do
    with_store_management do |store|
      store.read("rabbit").must_equal(@rabbit)
    end
  end

  it "writes the data" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit
      store.read("rabbit").must_equal(@white_rabbit)
    end
  end

  it "writes the data with specified namespace" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, namespace:'namespaced'
      store.read("namespaced:rabbit").must_equal(@white_rabbit)
    end
  end

  it "writes the data with expiration time" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, :expires_in => 1.second
      store.read("rabbit").must_equal(@white_rabbit)
      sleep 2
      store.read("rabbit").must_be_nil
    end
  end

  it "respects expiration time in seconds" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit
      store.read("rabbit").must_equal(@white_rabbit)
      store.expire "rabbit", 1.second
      sleep 2
      store.read("rabbit").must_be_nil
    end
  end

  it "does't write data if :unless_exist option is true" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, :unless_exist => true
      store.read("rabbit").must_equal(@rabbit)
    end
  end

  if RUBY_VERSION.match /1\.9/
    it "reads raw data" do
      with_store_management do |store|
        result = store.read("rabbit", :raw => true)
        result.must_include("ActiveSupport::Cache::Entry")
        result.must_include("\x0FOpenStruct{\x06:\tnameI\"\nbunny\x06:\x06EF")
      end
    end
  else
    it "reads raw data" do
      with_store_management do |store|
        result = store.read("rabbit", :raw => true)
        result.must_include("ActiveSupport::Cache::Entry")
        result.must_include("\017OpenStruct{\006:\tname")
      end
    end
  end

  it "writes raw data" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, :raw => true
      store.read("rabbit", :raw => true).must_equal(%(#<OpenStruct color=\"white\">))
    end
  end

  it "deletes data" do
    with_store_management do |store|
      store.delete "rabbit"
      store.read("rabbit").must_be_nil
    end
  end

  it "deletes namespaced data" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, namespace:'namespaced'
      store.delete "rabbit", namespace:'namespaced'
      store.read("namespaced:rabbit").must_be_nil
    end
  end

  it "deletes matched data" do
    with_store_management do |store|
      store.delete_matched "rabb*"
      store.read("rabbit").must_be_nil
    end
  end

  it "verifies existence of an object in the store" do
    with_store_management do |store|
      store.exist?("rabbit").must_equal(true)
      store.exist?("rab-a-dub").must_equal(false)
    end
  end

  it "increments a key" do
    with_store_management do |store|
      3.times { store.increment "counter" }
      store.read("counter", :raw => true).to_i.must_equal(3)
    end
  end

  it "decrements a key" do
    with_store_management do |store|
      3.times { store.increment "counter" }
      2.times { store.decrement "counter" }
      store.read("counter", :raw => true).to_i.must_equal(1)
    end
  end

  it "increments a raw key" do
    with_store_management do |store|
      assert store.write("raw-counter", 1, :raw => true)
      store.increment("raw-counter", 2)
      store.read("raw-counter", :raw => true).to_i.must_equal(3)
    end
  end

  it "decrements a raw key" do
    with_store_management do |store|
      assert store.write("raw-counter", 3, :raw => true)
      store.decrement("raw-counter", 2)
      store.read("raw-counter", :raw => true).to_i.must_equal(1)
    end
  end

  it "increments a key by given value" do
    with_store_management do |store|
      store.increment "counter", 3
      store.read("counter", :raw => true).to_i.must_equal(3)
    end
  end

  it "decrements a key by given value" do
    with_store_management do |store|
      3.times { store.increment "counter" }
      store.decrement "counter", 2
      store.read("counter", :raw => true).to_i.must_equal(1)
    end
  end

  it "clears the store" do
    with_store_management do |store|
      store.clear
      store.with { |client| client.keys("*") }.flatten.must_be_empty
    end
  end

  it "provides store stats" do
    with_store_management do |store|
      store.stats.wont_be_empty
    end
  end

  it "fetches data" do
    with_store_management do |store|
      store.fetch("rabbit").must_equal(@rabbit)
      store.fetch("rub-a-dub").must_be_nil
      store.fetch("rub-a-dub") { "Flora de Cana" }
      store.fetch("rub-a-dub").must_equal("Flora de Cana")
    end
  end

  it "fetches data with expiration time" do
    with_store_management do |store|
      store.fetch("rabbit", :force => true) # force cache miss
      store.fetch("rabbit", :force => true, :expires_in => 1.second) { @white_rabbit }
      store.fetch("rabbit").must_equal(@white_rabbit)
      sleep 2
      store.fetch("rabbit").must_be_nil
    end
  end

  it "fetches namespaced data" do
    with_store_management do |store|
      store.delete("rabbit", namespace:'namespaced')
      store.fetch("rabbit", namespace:'namespaced'){@rabbit}.must_equal(@rabbit)
      store.read("rabbit", namespace:'namespaced').must_equal(@rabbit)
    end
  end

  it "reads multiple keys" do
    @store.write "irish whisky", "Jameson"
    result = @store.read_multi "rabbit", "irish whisky"
    result['rabbit'].must_equal(@rabbit)
    result['irish whisky'].must_equal("Jameson")
  end

  it "reads multiple keys and returns only the matched ones" do
    @store.delete 'irish whisky'
    result = @store.read_multi "rabbit", "irish whisky"
    result.wont_include('irish whisky')
    result.must_include('rabbit')
  end

  it "reads multiple namespaced keys" do
    @store.write "rub-a-dub", "Flora de Cana", namespace:'namespaced'
    @store.write "irish whisky", "Jameson", namespace:'namespaced'
    result = @store.read_multi "rub-a-dub", "irish whisky", namespace:'namespaced'
    result['namespaced:rub-a-dub'].must_equal("Flora de Cana")
    result['namespaced:irish whisky'].must_equal("Jameson")
  end

  describe "fetch_multi" do
    it "reads existing keys and fills in anything missing" do
      @store.write "bourbon", "makers"

      result = @store.fetch_multi("bourbon", "rye") do |key|
        "#{key}-was-missing"
      end

      result.must_equal({ "bourbon" => "makers", "rye" => "rye-was-missing" })
      @store.read("rye").must_equal("rye-was-missing")
    end
  end

  describe "fetch_multi namespaced keys" do
    it "reads existing keys and fills in anything missing" do
      @store.write "bourbon", "makers", namespace:'namespaced'

      result = @store.fetch_multi("bourbon", "rye", namespace:'namespaced') do |key|
        "#{key}-was-missing"
      end

      result.must_equal({ "namespaced:bourbon" => "makers", "namespaced:rye" => "rye-was-missing" })
      @store.read("namespaced:rye").must_equal("rye-was-missing")
    end
  end

  describe "notifications" do
    it "notifies on #fetch" do
      with_notifications do
        @store.fetch("radiohead") { "House Of Cards" }
      end

      read, generate, write = @events

      read.name.must_equal('cache_read.active_support')
      read.payload.must_equal({ :key => 'radiohead', :super_operation => :fetch })

      generate.name.must_equal('cache_generate.active_support')
      generate.payload.must_equal({ :key => 'radiohead' })

      write.name.must_equal('cache_write.active_support')
      write.payload.must_equal({ :key => 'radiohead' })
    end

    it "notifies on #read" do
      with_notifications do
        @store.read "metallica"
      end

      read = @events.first
      read.name.must_equal('cache_read.active_support')
      read.payload.must_equal({ :key => 'metallica', :hit => false })
    end

    it "notifies on #write" do
      with_notifications do
        @store.write "depeche mode", "Enjoy The Silence"
      end

      write = @events.first
      write.name.must_equal('cache_write.active_support')
      write.payload.must_equal({ :key => 'depeche mode' })
    end

    it "notifies on #delete" do
      with_notifications do
        @store.delete "the new cardigans"
      end

      delete = @events.first
      delete.name.must_equal('cache_delete.active_support')
      delete.payload.must_equal({ :key => 'the new cardigans' })
    end

    it "notifies on #exist?" do
      with_notifications do
        @store.exist? "the smiths"
      end

      exist = @events.first
      exist.name.must_equal('cache_exist?.active_support')
      exist.payload.must_equal({ :key => 'the smiths' })
    end

    it "notifies on #delete_matched" do
      with_notifications do
        @store.delete_matched "afterhours*"
      end

      delete_matched = @events.first
      delete_matched.name.must_equal('cache_delete_matched.active_support')
      delete_matched.payload.must_equal({ :key => %("afterhours*") })
    end

    it "notifies on #increment" do
      with_notifications do
        @store.increment "pearl jam"
      end

      increment = @events.first
      increment.name.must_equal('cache_increment.active_support')
      increment.payload.must_equal({ :key => 'pearl jam', :amount => 1 })
    end

    it "notifies on #decrement" do
      with_notifications do
        @store.decrement "placebo"
      end

      decrement = @events.first
      decrement.name.must_equal('cache_decrement.active_support')
      decrement.payload.must_equal({ :key => 'placebo', :amount => 1 })
    end

    # it "notifies on cleanup" # TODO implement in ActiveSupport::Cache::RedisStore

    it "should notify on clear" do
      with_notifications do
        @store.clear
      end

      clear = @events.first
      clear.name.must_equal('cache_clear.active_support')
      clear.payload.must_equal({ :key => nil })
    end
  end

  describe "raise_errors => true" do
    def setup
      @raise_error_store = ActiveSupport::Cache::RedisStore.new("redis://127.0.0.1:6380/1", :raise_errors => true)
      @raise_error_store.stubs(:with).raises(Redis::CannotConnectError)
    end

    it "raises on read when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.read("rabbit")
      end
    end

    it "raises on writes when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.write "rabbit", @white_rabbit, :expires_in => 1.second
      end
    end

    it "raises on delete when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.delete "rabbit"
      end
    end

    it "raises on delete_matched when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.delete_matched "rabb*"
      end
    end
  end

  describe "raise_errors => false" do
    def setup
      @raise_error_store = ActiveSupport::Cache::RedisStore.new("redis://127.0.0.1:6380/1")
      @raise_error_store.stubs(:with).raises(Redis::CannotConnectError)
    end

    it "is nil when redis is unavailable" do
      @raise_error_store.read("rabbit").must_be_nil
    end

    it "returns false when redis is unavailable" do
      @raise_error_store.write("rabbit", @white_rabbit, :expires_in => 1.second).must_equal(false)
    end

    it "returns false when redis is unavailable" do
      @raise_error_store.delete("rabbit").must_equal(false)
    end

    it "raises on delete_matched when redis is unavailable" do
      @raise_error_store.delete_matched("rabb*").must_equal(false)
    end
  end

  private
    def instantiate_store(*addresses)
      ActiveSupport::Cache::RedisStore.new(*addresses).instance_variable_get(:@data)
    end

    def with_store_management
      yield @store
      yield @dstore
      yield @pool_store
      yield @external_pool_store
    end

    def with_notifications
      @events = [ ]
#      ActiveSupport::Cache::RedisStore.instrument = true
      ActiveSupport::Notifications.subscribe(/^cache_(.*)\.active_support$/) do |*args|
        @events << ActiveSupport::Notifications::Event.new(*args)
      end
      yield
#      ActiveSupport::Cache::RedisStore.instrument = false
    end
end

describe 'ActiveSupport::Cache::RedisStore with encryption' do
  def setup
    @secret = SecureRandom.hex(64)
    @store  = ActiveSupport::Cache::RedisStore.new encrypt: true, encryption_key: @secret
    @dstore = ActiveSupport::Cache::RedisStore.new "redis://127.0.0.1:6379/5", "redis://127.0.0.1:6379/6", encrypt: true, encryption_key: @secret
    @pool_store  = ActiveSupport::Cache::RedisStore.new("redis://127.0.0.1:6379/2", pool_size: 5, pool_timeout: 10, encrypt: true, encryption_key: @secret)
    @external_pool_store = ActiveSupport::Cache::RedisStore.new(encrypt: true, encryption_key: @secret, pool: ::ConnectionPool.new(size: 1, timeout: 1) { ::Redis::Store::Factory.create("redis://127.0.0.1:6379/3") })

    @pool_store.data.class.must_equal ::ConnectionPool
    @pool_store.data.instance_variable_get(:@size).must_equal 5
    @external_pool_store.data.class.must_equal ::ConnectionPool
    @external_pool_store.data.instance_variable_get(:@size).must_equal 1


    @rabbit = OpenStruct.new :name => "bunny"
    @white_rabbit = OpenStruct.new :color => "white"

    with_store_management do |store|
      store.write "rabbit", @rabbit
      store.delete "counter"
      store.delete "rub-a-dub"
    end
  end

  it "connects using an hash of options" do
    address = { host: '127.0.0.1', port: '6380', db: '1' }
    store = ActiveSupport::Cache::RedisStore.new(address.merge(pool_size: 5, pool_timeout: 10, encrypt: true, encryption_key: @secret))
    redis = Redis.new(url: "redis://127.0.0.1:6380/1")
    redis.flushall

    store.data.class.must_equal(::ConnectionPool)
    store.data.instance_variable_get(:@size).must_equal(5)
    store.data.instance_variable_get(:@timeout).must_equal(10)

    store.write("rabbit", 0)

    redis.exists("rabbit").must_equal(true)
  end

  it "connects using an string of options" do
    address = "redis://127.0.0.1:6380/1"
    store = ActiveSupport::Cache::RedisStore.new(address, pool_size: 5, pool_timeout: 10, encrypt: true, encryption_key: @secret)
    redis = Redis.new(url: address)
    redis.flushall

    store.data.class.must_equal(::ConnectionPool)
    store.data.instance_variable_get(:@size).must_equal(5)
    store.data.instance_variable_get(:@timeout).must_equal(10)

    store.write("rabbit", 0)

    redis.exists("rabbit").must_equal(true)
  end

  it "raises an error if :pool isn't a pool" do
    assert_raises(RuntimeError, 'pool must be an instance of ConnectionPool') do
      ActiveSupport::Cache::RedisStore.new(pool: 'poolio', encrypt: true, encryption_key: @secret)
    end
  end

  it "namespaces all operations" do
    address = "redis://127.0.0.1:6380/1/cache-namespace"
    store   = ActiveSupport::Cache::RedisStore.new(address, encrypt: true, encryption_key: @secret)
    redis   = Redis.new(url: address)

    store.write("white-rabbit", 0)

    redis.exists('cache-namespace:white-rabbit').must_equal(true)
  end

  it "creates a normal store when given no addresses" do
    underlying_store = instantiate_store
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a normal store when given options only" do
    underlying_store = instantiate_store(:expires_in => 1.second)
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a normal store when given a single address" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1")
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a normal store when given a single address and options" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1",
                                         { :expires_in => 1.second})
    underlying_store.must_be_instance_of(::Redis::Store)
  end

  it "creates a distributed store when given multiple addresses" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1",
                                         "redis://127.0.0.1:6381/1")
    underlying_store.must_be_instance_of(::Redis::DistributedStore)
  end

  it "creates a distributed store when given multiple address and options" do
    underlying_store = instantiate_store("redis://127.0.0.1:6380/1",
                                         "redis://127.0.0.1:6381/1",
                                         :expires_in => 1.second)
    underlying_store.must_be_instance_of(::Redis::DistributedStore)
  end

  it "reads the data" do
    with_store_management do |store|
      store.read("rabbit").must_equal(@rabbit)
    end
  end

  it "writes the data" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit
      store.read("rabbit").must_equal(@white_rabbit)
    end
  end

  it "writes the data with specified namespace" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, namespace:'namespaced'
      store.read("namespaced:rabbit").must_equal(@white_rabbit)
    end
  end

  it "writes the data with expiration time" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, :expires_in => 1.second
      store.read("rabbit").must_equal(@white_rabbit)
      sleep 2
      store.read("rabbit").must_be_nil
    end
  end

  it "respects expiration time in seconds" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit
      store.read("rabbit").must_equal(@white_rabbit)
      store.expire "rabbit", 1.second
      sleep 2
      store.read("rabbit").must_be_nil
    end
  end

  it "does't write data if :unless_exist option is true" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, :unless_exist => true
      store.read("rabbit").must_equal(@rabbit)
    end
  end

  if RUBY_VERSION.match /1\.9/
    it "reads raw data" do
      with_store_management do |store|
        result = store.read("rabbit", :raw => true)
        result.must_include("ActiveSupport::Cache::Entry")
        result.must_include("\x0FOpenStruct{\x06:\tnameI\"\nbunny\x06:\x06EF")
      end
    end
  else
    it "reads raw data" do
      with_store_management do |store|
        result = store.read("rabbit", :raw => true)
        result.must_include("ActiveSupport::Cache::Entry")
        result.must_include("\u0004\bo: ActiveSupport::Cache::Entry\t:\v@valueI")
      end
    end
  end

  it "writes raw data" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, :raw => true
      store.read("rabbit", :raw => true).must_equal(%(#<OpenStruct color=\"white\">))
    end
  end

  it "deletes data" do
    with_store_management do |store|
      store.delete "rabbit"
      store.read("rabbit").must_be_nil
    end
  end

  it "deletes namespaced data" do
    with_store_management do |store|
      store.write "rabbit", @white_rabbit, namespace:'namespaced'
      store.delete "rabbit", namespace:'namespaced'
      store.read("namespaced:rabbit").must_be_nil
    end
  end

  it "deletes matched data" do
    with_store_management do |store|
      store.delete_matched "rabb*"
      store.read("rabbit").must_be_nil
    end
  end

  it "verifies existence of an object in the store" do
    with_store_management do |store|
      store.exist?("rabbit").must_equal(true)
      store.exist?("rab-a-dub").must_equal(false)
    end
  end

  it "increments a key" do
    with_store_management do |store|
      3.times { store.increment "counter" }
      store.read("counter", :raw => true).to_i.must_equal(3)
    end
  end

  it "decrements a key" do
    with_store_management do |store|
      3.times { store.increment "counter" }
      2.times { store.decrement "counter" }
      store.read("counter", :raw => true).to_i.must_equal(1)
    end
  end

  it "increments a raw key" do
    with_store_management do |store|
      assert store.write("raw-counter", 1, :raw => true)
      store.increment("raw-counter", 2)
      store.read("raw-counter", :raw => true).to_i.must_equal(3)
    end
  end

  it "decrements a raw key" do
    with_store_management do |store|
      assert store.write("raw-counter", 3, :raw => true)
      store.decrement("raw-counter", 2)
      store.read("raw-counter", :raw => true).to_i.must_equal(1)
    end
  end

  it "increments a key by given value" do
    with_store_management do |store|
      store.increment "counter", 3
      store.read("counter", :raw => true).to_i.must_equal(3)
    end
  end

  it "decrements a key by given value" do
    with_store_management do |store|
      3.times { store.increment "counter" }
      store.decrement "counter", 2
      store.read("counter", :raw => true).to_i.must_equal(1)
    end
  end

  it "clears the store" do
    with_store_management do |store|
      store.clear
      store.with { |client| client.keys("*") }.flatten.must_be_empty
    end
  end

  it "provides store stats" do
    with_store_management do |store|
      store.stats.wont_be_empty
    end
  end

  it "fetches data" do
    with_store_management do |store|
      store.fetch("rabbit").must_equal(@rabbit)
      store.fetch("rub-a-dub").must_be_nil
      store.fetch("rub-a-dub") { "Flora de Cana" }
      store.fetch("rub-a-dub").must_equal("Flora de Cana")
    end
  end

  it "fetches data with expiration time" do
    with_store_management do |store|
      store.fetch("rabbit", :force => true) # force cache miss
      store.fetch("rabbit", :force => true, :expires_in => 1.second) { @white_rabbit }
      store.fetch("rabbit").must_equal(@white_rabbit)
      sleep 2
      store.fetch("rabbit").must_be_nil
    end
  end

  it "fetches namespaced data" do
    with_store_management do |store|
      store.delete("rabbit", namespace:'namespaced')
      store.fetch("rabbit", namespace:'namespaced'){@rabbit}.must_equal(@rabbit)
      store.read("rabbit", namespace:'namespaced').must_equal(@rabbit)
    end
  end

  it "reads multiple keys" do
    @store.write "irish whisky", "Jameson"
    result = @store.read_multi "rabbit", "irish whisky"
    result['rabbit'].must_equal(@rabbit)
    result['irish whisky'].must_equal("Jameson")
  end

  it "reads multiple keys and returns only the matched ones" do
    @store.delete 'irish whisky'
    result = @store.read_multi "rabbit", "irish whisky"
    result.wont_include('irish whisky')
    result.must_include('rabbit')
  end

  it "reads multiple namespaced keys" do
    @store.write "rub-a-dub", "Flora de Cana", namespace:'namespaced'
    @store.write "irish whisky", "Jameson", namespace:'namespaced'
    result = @store.read_multi "rub-a-dub", "irish whisky", namespace:'namespaced'
    result['namespaced:rub-a-dub'].must_equal("Flora de Cana")
    result['namespaced:irish whisky'].must_equal("Jameson")
  end

  describe "fetch_multi" do
    it "reads existing keys and fills in anything missing" do
      @store.write "bourbon", "makers"

      result = @store.fetch_multi("bourbon", "rye") do |key|
        "#{key}-was-missing"
      end

      result.must_equal({ "bourbon" => "makers", "rye" => "rye-was-missing" })
      @store.read("rye").must_equal("rye-was-missing")
    end
  end

  describe "fetch_multi namespaced keys" do
    it "reads existing keys and fills in anything missing" do
      @store.write "bourbon", "makers", namespace:'namespaced'

      result = @store.fetch_multi("bourbon", "rye", namespace:'namespaced') do |key|
        "#{key}-was-missing"
      end

      result.must_equal({ "namespaced:bourbon" => "makers", "namespaced:rye" => "rye-was-missing" })
      @store.read("namespaced:rye").must_equal("rye-was-missing")
    end
  end

  describe "notifications" do
    it "notifies on #fetch" do
      with_notifications do
        @store.fetch("radiohead") { "House Of Cards" }
      end

      read, generate, write = @events

      read.name.must_equal('cache_read.active_support')
      read.payload.must_equal({ :key => 'radiohead', :super_operation => :fetch, encrypt: true })

      generate.name.must_equal('cache_generate.active_support')
      generate.payload.must_equal({ :key => 'radiohead', encrypt: true })

      write.name.must_equal('cache_write.active_support')
      write.payload.must_equal({ :key => 'radiohead', encrypt: true })
    end

    it "notifies on #read" do
      with_notifications do
        @store.read "metallica"
      end

      read = @events.first
      read.name.must_equal('cache_read.active_support')
      read.payload.must_equal({ :key => 'metallica', :hit => false, encrypt: true })
    end

    it "notifies on #write" do
      with_notifications do
        @store.write "depeche mode", "Enjoy The Silence"
      end

      write = @events.first
      write.name.must_equal('cache_write.active_support')
      write.payload.must_equal({ :key => 'depeche mode', encrypt: true })
    end

    it "notifies on #delete" do
      with_notifications do
        @store.delete "the new cardigans"
      end

      delete = @events.first
      delete.name.must_equal('cache_delete.active_support')
      delete.payload.must_equal({ :key => 'the new cardigans' })
    end

    it "notifies on #exist?" do
      with_notifications do
        @store.exist? "the smiths"
      end

      exist = @events.first
      exist.name.must_equal('cache_exist?.active_support')
      exist.payload.must_equal({ :key => 'the smiths' })
    end

    it "notifies on #delete_matched" do
      with_notifications do
        @store.delete_matched "afterhours*"
      end

      delete_matched = @events.first
      delete_matched.name.must_equal('cache_delete_matched.active_support')
      delete_matched.payload.must_equal({ :key => %("afterhours*") })
    end

    it "notifies on #increment" do
      with_notifications do
        @store.increment "pearl jam"
      end

      increment = @events.first
      increment.name.must_equal('cache_increment.active_support')
      increment.payload.must_equal({ :key => 'pearl jam', :amount => 1 })
    end

    it "notifies on #decrement" do
      with_notifications do
        @store.decrement "placebo"
      end

      decrement = @events.first
      decrement.name.must_equal('cache_decrement.active_support')
      decrement.payload.must_equal({ :key => 'placebo', :amount => 1 })
    end

    # it "notifies on cleanup" # TODO implement in ActiveSupport::Cache::RedisStore

    it "should notify on clear" do
      with_notifications do
        @store.clear
      end

      clear = @events.first
      clear.name.must_equal('cache_clear.active_support')
      clear.payload.must_equal({ :key => nil })
    end
  end

  describe "raise_errors => true" do
    def setup
      @raise_error_store = ActiveSupport::Cache::RedisStore.new("redis://127.0.0.1:6380/1", :raise_errors => true, encrypt: true, encryption_key: @secret)
      @raise_error_store.stubs(:with).raises(Redis::CannotConnectError)
    end

    it "raises on read when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.read("rabbit")
      end
    end

    it "raises on writes when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.write "rabbit", @white_rabbit, :expires_in => 1.second
      end
    end

    it "raises on delete when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.delete "rabbit"
      end
    end

    it "raises on delete_matched when redis is unavailable" do
      assert_raises(Redis::CannotConnectError) do
        @raise_error_store.delete_matched "rabb*"
      end
    end
  end

  describe "raise_errors => false" do
    def setup
      @raise_error_store = ActiveSupport::Cache::RedisStore.new("redis://127.0.0.1:6380/1", encrypt: true, encryption_key: @secret)
      @raise_error_store.stubs(:with).raises(Redis::CannotConnectError)
    end

    it "is nil when redis is unavailable" do
      @raise_error_store.read("rabbit").must_be_nil
    end

    it "returns false when redis is unavailable" do
      @raise_error_store.write("rabbit", @white_rabbit, :expires_in => 1.second).must_equal(false)
    end

    it "returns false when redis is unavailable" do
      @raise_error_store.delete("rabbit").must_equal(false)
    end

    it "raises on delete_matched when redis is unavailable" do
      @raise_error_store.delete_matched("rabb*").must_equal(false)
    end
  end

  private
    def instantiate_store(*addresses)
      options = addresses.extract_options!
      options[:encrypt] = true
      options[:encryption_key] = @secret
      ActiveSupport::Cache::RedisStore.new(*(addresses << options)).instance_variable_get(:@data)
    end

    def with_store_management
      yield @store
      yield @dstore
      yield @pool_store
      yield @external_pool_store
    end

    def with_notifications
      @events = [ ]
#      ActiveSupport::Cache::RedisStore.instrument = true
      ActiveSupport::Notifications.subscribe(/^cache_(.*)\.active_support$/) do |*args|
        @events << ActiveSupport::Notifications::Event.new(*args)
      end
      yield
#      ActiveSupport::Cache::RedisStore.instrument = false
    end
end
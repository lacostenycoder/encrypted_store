require "encrypted_store/version"
require 'active_support/core_ext/marshal'
require 'active_support/core_ext/array/extract_options'

module EncryptedStore
  # TODO - this means we can only ever have a single encryption key for our stores.
  # this is because we don't want to store the key in a serialized Entry (otherwise
  # why bother encrypting?) and a revivified Entry has no way of knowing about
  # the Store class it belongs to. probably we could figure out how to point an
  # Entry to a specific Store but that's probably an uncommon setup.

  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= ActiveSupport::OrderedOptions.new
  end

  def self.configure
    yield(configuration)
  end

  def self.encryption_key
    # if we don't have an ecryption_key set yet go ahead and try to use rails
    # secret key base. don't do this until we need to since i'm not sure when
    # this is setup in application boot. also use #try since it's possible we
    # aren't inside of rails
    configuration.encryption_key ||= Rails.try(:application).try(:secrets).try(:secret_key_base)
  end

  def self.initialize!
    ActiveSupport::Cache::Store.send :prepend, EncryptedStore::Store
    ActiveSupport::Cache::Entry.send :prepend, EncryptedStore::Entry
  end

  module Store
    def initialize(*args)
      options = args.extract_options!
      if (encryption_key = options.delete(:encryption_key))
        EncryptedStore.configure do |config|
          config.encryption_key = encryption_key
        end
      end
      args.push(options) if options.present?
      super(*args)
    end
  end

  module Entry
    def initialize(value, options={})
      # if we encrypted and then compressed we wouldn't get any real gain so
      # instead we call super first so that we munge the data in whatever
      # appropriate way (including compression) and _then_ we actually run the
      # encryption
      super

      if should_encrypt?(value, options)
        @value = encrypt(@value)
        @encrypted = true
      end

    end

    def value

      if encrypted?
        # temporarily make a copy of @value, then decrypt it and assign the
        # decrypted value to @value - this was the simplest way forward to make
        # any super call work correctly.
        prev_value = @value.dup
        @value = decrypt(@value)
      end

      value = super

      if encrypted?
        # reverse what we did above for the same reasons
        @value = prev_value
      end

      # we end up having diverging @value and #value but that's what happens
      # with compression too so it's not too horrible.
      value
    end

    def dup_value!
      # identical to the rails version except for the !encrypted? check below
      convert_version_4beta1_entry! if defined?(@v)

      if @value && !encrypted? && !compressed? && !(@value.is_a?(Numeric) || @value == true || @value == false)
        if @value.is_a?(String)
          @value = @value.dup
        else
          @value = Marshal.load(Marshal.dump(@value))
        end
      end
    end

    private

    def should_compress?(value, options)
      # if we're not encrypting just call super
      return super unless should_encrypt?(value, options)

      if value && options[:compress]
        compress_threshold = options[:compress_threshold] || ActiveSupport::Cache::Entry::DEFAULT_COMPRESS_LIMIT
        serialized_value_size = encrypt(value).bytesize

        return true if serialized_value_size >= compress_threshold
      end

      false
    end

    def should_encrypt?(value, options)
      value && options[:encrypt]
    end

    def encrypted?
      defined?(@encrypted) ? @encrypted : false
    end

    def encrypt(value)
      encryptor.encrypt_and_sign value
    end

    def decrypt(value)
      encryptor.decrypt_and_verify value
    end

    def encryptor
      ActiveSupport::MessageEncryptor.new(EncryptedStore.encryption_key)
    end
  end

  module Rails
    class Engine < ::Rails::Engine

      # before we configure our application monkeypatch our classes - we do this
      # here since it's possible to setup caching in the configuration or
      # initialization stage
      config.before_configuration do
        EncryptedStore.initialize!
      end

      # # after configuration double-check to see if we've setup an encryption_key
      # config.after_configuration do
      #   EncryptedStore.configure do |config|
      #     # default to Rails.application.secrets.secret_key_base if we haven't
      #     # set an encryption_key
      #     config.encryption_key ||= ::Rails.application.secrets.secret_key_base
      #   end
      # end
    end
  end
end

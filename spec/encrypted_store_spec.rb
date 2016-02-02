require 'spec_helper'

# TODO - figure out what to test here - railtie, default options, explicit initialization, etc?
describe EncryptedStore do
  before(:each) do
    @tempdir = Dir.mktmpdir
    @secret = SecureRandom.hex(64)
    @file_store = ActiveSupport::Cache.lookup_store :file_store, @tempdir, encrypt: true, encryption_key: @secret
    @file_store.logger = Logger.new(STDOUT)

    @memory_store = ActiveSupport::Cache.lookup_store :memory_store, encrypt: true, encryption_key: @secret
  end

#  after(:each) { FileUtils.remove_entry @tempdir }

  it 'has a version number' do
    expect(EncryptedStore::VERSION).not_to be nil
  end

  xit "works" do
    # @file_store.write("test", "asdf1234")
    # puts @file_store.read("test")
    # puts File.read(@file_store.send(:key_file_path, "test"))

    @memory_store.write("test", "asdf1234", compress: true, compress_threshold: 1)
    puts @memory_store.read("test")
    v =  @memory_store.instance_variable_get(:@data)["test"]

    #
    # @memory_store.write("test", "asdf1234", compress: false )
    # puts @memory_store.read("test")
    # puts Marshal.dump @memory_store.instance_variable_get(:@data)["test"]

  end

end

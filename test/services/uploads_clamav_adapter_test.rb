require "test_helper"

class UploadsClamavAdapterTest < ActiveSupport::TestCase
  test "classifies fake socket responses without external scanner" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("safe fake file"), filename: "fake.bin")
    fake = StringIO.new("stream: OK\0")
    fake.define_singleton_method(:write) { |data| data.bytesize }
    factory = Object.new
    factory.define_singleton_method(:tcp) { |*| fake }
    assert_equal :clean, Uploads::Scanner::ClamavAdapter.new(host: "127.0.0.1", port: 3310, socket_factory: factory).scan(blob)
  ensure
    blob&.purge
  end
end

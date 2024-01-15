# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if ActiveStorage::TestHelper.service_available?(:s3_public)
  class ActiveStorage::Service::S3PublicServiceTest < ActiveSupport::TestCase
    setup do
      @old_service = ActiveStorage::Blob.service
      @service = ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:s3_public)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    include ActiveStorage::Service::SharedServiceTests

    test "public acl options" do
      assert_equal "public-read", @service.upload_options[:acl]
    end

    test "public URL generation" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

      assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws\.com\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end

    test "public URL generation (virtual host enabled)" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"), virtual_host: true)

      assert_match(/#{@service.bucket.name}\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end

    test "direct upload" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      checksum = OpenSSL::Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      request.add_field "Content-Type", "text/plain"
      request.add_field "Content-MD5", checksum
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      response = Net::HTTP.get_response(URI(@service.url(key)))
      assert_equal "200", response.code
      assert_equal data, response.body
    ensure
      @service.delete key
    end
  end
end

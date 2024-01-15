# frozen_string_literal: true

require "service/shared_service_tests"
require "uri"

if ActiveStorage::TestHelper.service_available?(:azure_public)
  class ActiveStorage::Service::AzureStoragePublicServiceTest < ActiveSupport::TestCase
    setup do
      @old_service = ActiveStorage::Blob.service
      @service = ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:azure_public)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    include ActiveStorage::Service::SharedServiceTests

    test "public URL generation" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

      assert_match(/.*\.blob\.core\.windows\.net\/.*\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end

    test "direct upload" do
      key          = SecureRandom.base58(24)
      data         = "Something else entirely!"
      checksum     = OpenSSL::Digest::MD5.base64digest(data)
      content_type = "text/xml"
      url          = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: content_type, content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      @service.headers_for_direct_upload(key, checksum: checksum, content_type: content_type, filename: ActiveStorage::Filename.new("test.txt")).each do |k, v|
        request.add_field k, v
      end
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

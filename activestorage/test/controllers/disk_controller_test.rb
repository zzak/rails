# frozen_string_literal: true

require "test_helper"

require "debug"
require "active_storage/engine/routes"

class ActiveStorage::DiskControllerTest < ActionController::TestCase
  tests ActiveStorage::DiskController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    ActiveStorage::Routes.draw_routes!(@routes)
    ActiveStorage::Blob.service.instance_variable_set(:@url_helpers, @routes.url_helpers)
  end

  test "showing blob inline" do
    blob = create_blob(filename: "hello.jpg", content_type: "image/jpeg")
    encoded_key = generate_encoded_key(blob)
    get :show, params: {
      encoded_key:,
      filename: blob.filename}
    assert_equal 200, response.status
    assert_equal "inline; filename=\"hello.jpg\"; filename*=UTF-8''hello.jpg", response.headers["Content-Disposition"]
    assert_equal "image/jpeg", response.headers["Content-Type"]
    # TODO: response.body is a Rack::Files::Iterator, must use stream to get content
    assert_equal "Hello world!", File.read(response.stream.path)
  end

  test "showing blob as attachment" do
    blob = create_blob
    encoded_key = generate_encoded_key(blob, disposition: :attachment)
    get :show, params: {
      encoded_key:,
      filename: blob.filename
    }
    assert_equal 200, response.status
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    # TODO: response.body is a Rack::Files::Iterator, must use stream to get content
    assert_equal "Hello world!", File.read(response.stream.path)
  end

  test "showing blob range" do
    blob = create_blob
    encoded_key = generate_encoded_key(blob, disposition: :attachment)
    @request.headers["Range"] = "bytes=5-9"
    get :show, params: {
      encoded_key:,
      filename: blob.filename
    }
    assert_response :partial_content
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal " worl", response.body
  end

  test "showing blob with invalid range" do
    blob = create_blob
    encoded_key = generate_encoded_key(blob, disposition: :attachment)
    @request.headers["Range"] = "bytes=1000-1000"
    get :show, params: {
      encoded_key:,
      filename: blob.filename
    }
    assert_response :range_not_satisfiable
  end

  test "showing blob that does not exist" do
    blob = create_blob
    blob.delete

    encoded_key = generate_encoded_key(blob, disposition: :attachment)
    get :show, params: {
      encoded_key:,
      filename: blob.filename
    }

    assert_response :not_found
  end

  test "showing blob with invalid key" do
    get :show, params: { encoded_key: "Invalid key", filename: "hello.txt" }
    assert_response :not_found
  end

  test "showing public blob" do
    with_service("local_public") do
      blob = create_blob(content_type: "image/jpeg")
      encoded_key = generate_encoded_key(blob, disposition: :attachment)

      get :show, params: {
        encoded_key:,
        filename: blob.filename
      }

      assert_equal 200, response.status
      assert_equal "image/jpeg", response.headers["Content-Type"]
      # TODO: response.body is a Rack::Files::Iterator, must use stream to get content
      assert_equal "Hello world!", File.read(response.stream.path)
    end
  end

  test "showing public blob variant" do
    with_service("local_public") do
      blob = create_file_blob.variant(resize_to_limit: [100, 100]).processed

      encoded_key = generate_encoded_key(blob, disposition: :attachment)

      get :show, params: {
        encoded_key:,
        filename: blob.filename
      }

      assert_equal 200, response.status
      assert_equal "image/jpeg", response.headers["Content-Type"]
    end
  end

  test "directly uploading blob with integrity" do
    # ActionController::TestCase does not support non-hash params to process requests
    data = { message: "Something else entirely!" }
    query = data.to_query
    blob = create_blob_before_direct_upload byte_size: query.size, checksum: OpenSSL::Digest::MD5.base64digest(query)

    encoded_token = generate_encoded_token(blob)

    @request.headers["Content-Type"] = "text/plain"

    put :update, params: { encoded_token:, **data}
    assert_response :no_content
    assert_equal query, blob.download
  end

  test "directly uploading blob without integrity" do
    data = { message: "Something else entirely!" }
    blob = create_blob_before_direct_upload byte_size: data.to_query.size, checksum: OpenSSL::Digest::MD5.base64digest("bad data")

    encoded_token = generate_encoded_token(blob)

    put :update, params: { encoded_token:, **data}
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with mismatched content type" do
    # ActionController::TestCase does not support non-hash params to process requests
    data = { message: "Something else entirely!" }
    query = data.to_query
    blob = create_blob_before_direct_upload byte_size: query.size, checksum: OpenSSL::Digest::MD5.base64digest(query)

    encoded_token = generate_encoded_token(blob)

    @request.headers["Content-Type"] = "application/x-gzip"

    put :update, params: { encoded_token:, **data}
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with different but equivalent content type" do
    data = { message: "Something else entirely!" }
    query = data.to_query
    blob = create_blob_before_direct_upload(
      byte_size: query.size, checksum: OpenSSL::Digest::MD5.base64digest(query), content_type: "application/x-gzip")

    encoded_token = generate_encoded_token(blob)

    @request.headers["Content-Type"] = "application/x-gzip"

    put :update, params: { encoded_token:, **data}
    assert_response :no_content
    assert_equal query, blob.download
  end

  test "directly uploading blob with mismatched content length" do
    data = { message: "Something else entirely!" }
    query = data.to_query
    blob = create_blob_before_direct_upload byte_size: query.size - 1, checksum: OpenSSL::Digest::MD5.base64digest(query)

    encoded_token = generate_encoded_token(blob)

    @request.headers["Content-Type"] = "text/plain"

    put :update, params: { encoded_token:, **data}
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with invalid token" do
    data = { message: "Something else entirely!" }
    @request.headers["Content-Type"] = "text/plain"
    put :update, params: { encoded_token: "invalid", **data }
    assert_response :not_found
  end

  private
  def generate_encoded_key(blob, disposition: "inline")
    content_disposition = blob.service.send(:content_disposition_with, filename: blob.filename, type: disposition)
    verified_key_with_expiration = ActiveStorage.verifier.generate(
      {
        key: blob.key,
        disposition: content_disposition,
        content_type: blob.content_type,
        service_name: blob.service.name
      },
      expires_in: 5.minutes,
      purpose: :blob_key
    )
  end

  def generate_encoded_token(blob)
    verified_key_with_expiration = ActiveStorage.verifier.generate(
      {
        key: blob.key,
        content_type: blob.content_type,
        content_length: blob.byte_size,
        checksum: blob.checksum,
        service_name: blob.service.name
      },
      expires_in: 5.minutes,
      purpose: :blob_token
    )
  end
end

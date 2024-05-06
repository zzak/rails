# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

require "active_storage/engine/routes"

class ActiveStorage::Blobs::ProxyControllerTest < ActionController::TestCase
  def setup
    @routes = ActionDispatch::Routing::RouteSet.new
    ActiveStorage::Routes.draw_routes!(@routes)
  end

  test "invalid signed ID" do
    get :show, params: { signed_id: "invalid", filename: "racecar.jpg" }
    assert_response :not_found
  end

  test "HTTP caching" do
    blob = create_file_blob(filename: "racecar.jpg")
    get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
    assert_response :success
    assert_equal "max-age=3155695200, public", response.headers["Cache-Control"]
  end

  test "forcing Content-Type to binary" do
    blob = create_blob(content_type: "text/html")
    get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
    assert_equal "application/octet-stream", response.headers["Content-Type"]
  end

  test "Accept-Ranges header" do
    blob = create_blob(filename: "racecar.jpg")
    get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
    assert_equal "bytes", response.headers["Accept-Ranges"]
    # TODO: this test fails because the response is automatically a "LiveTestResponse"
    # assert_equal blob.byte_size.to_s, response.headers["Content-Length"]
  end

  test "forcing Content-Disposition to attachment based on type" do
    bloby = create_blob(content_type: "application/zip")
    get :show, params: { signed_id: bloby.signed_id, filename: bloby.filename }
    assert_match(/^attachment; /, response.headers["Content-Disposition"])
  end

  test "caller can change disposition to attachment" do
    blob = create_blob(content_type: "image/jpeg")
    get :show, params: { signed_id: blob.signed_id, filename: blob.filename, disposition: :attachment }
    assert_match(/^attachment; /, response.headers["Content-Disposition"])
  end

  test "signed ID within expiration duration" do
    blob = create_file_blob(filename: "racecar.jpg")
    expiring_id = blob.signed_id(expires_in: 1.minute)
    get :show, params: { signed_id: expiring_id, filename: blob.filename }
    assert_response :success
  end

  test "Expired signed ID within expiration duration" do
    blob = create_file_blob(filename: "racecar.jpg")
    expiring_id = blob.signed_id(expires_in: 1.minute)
    travel 2.minutes
    get :show, params: { signed_id: expiring_id, filename: blob.filename }
    assert_response :not_found
  end

  test "signed ID within expiration time" do
    blob = create_file_blob(filename: "racecar.jpg")
    expiring_at = blob.signed_id(expires_at: 1.minute.from_now)
    get :show, params: { signed_id: expiring_at, filename: blob.filename }
    assert_response :success
  end

  test "Expired signed ID within expiration time" do
    blob = create_file_blob(filename: "racecar.jpg")
    expiring_at = blob.signed_id(expires_at: 1.minute.from_now)
    travel 2.minutes
    get :show, params: { signed_id: expiring_at, filename: blob.filename }
    assert_response :not_found
  end

  test "single Byte Range" do
    blob = create_file_blob(filename: "racecar.jpg")
    @request.headers["Range"] = "bytes=5-9"
    get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
    assert_response :partial_content
    # TODO: this test fails because the response is automatically a "LiveTestResponse"
    # assert_equal "5", response.headers["Content-Length"]
    assert_equal "bytes 5-9/1124062", response.headers["Content-Range"]
    assert_equal "image/jpeg", response.headers["Content-Type"]
    assert_equal " Exif", response.body
  end

  test "invalid Byte Range" do
    blob = create_file_blob(filename: "racecar.jpg")
    @request.headers["Range"] = "bytes=*/1234"
    get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
    assert_response :range_not_satisfiable
  end

  test "multiple Byte Ranges" do
    boundary = SecureRandom.hex
    SecureRandom.stub :hex, boundary do
      blob = create_file_blob(filename: "racecar.jpg")
      @request.headers["Range"] = "bytes=5-9,13-17"
      get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
      assert_response :partial_content
      # TODO: this test fails because the response is automatically a "LiveTestResponse"
      # assert_equal "252", response.headers["Content-Length"]
      assert_equal "multipart/byteranges; boundary=#{boundary}", response.headers["Content-Type"]
      assert_equal(
        [
          "",
          "--#{boundary}",
          "Content-Type: image/jpeg",
          "Content-Range: bytes 5-9/1124062",
          "",
          " Exif",
          "--#{boundary}",
          "Content-Type: image/jpeg",
          "Content-Range: bytes 13-17/1124062",
          "",
          "I*\u0000\b\u0000",
          "--#{boundary}--",
          ""
        ].join("\r\n"),
        response.body
      )
    end
  end

  test "uses a Live::Response" do
    # This tests for a regression of #45102. If the controller doesn't respond
    # with a ActionController::Live::Response, it will serve corrupted files
    # over 5mb when using S3 services.
    request = ActionController::TestRequest.create({})
    assert_instance_of ActionController::Live::Response, ActiveStorage::Blobs::ProxyController.make_response!(request)
  end
end

# TODO: this should just be an integration test
# class ActiveStorage::Blobs::ExpiringProxyControllerTest < ActionController::TestCase
#   tests ActiveStorage::Blobs::ProxyController
#
#   setup do
#     @routes = ActionDispatch::Routing::RouteSet.new
#     ActiveStorage::Routes.draw_routes!(@routes)
#
#     @old_urls_expire_in = ActiveStorage.urls_expire_in
#     ActiveStorage.urls_expire_in = 1.minutes
#   end
#
#   teardown do
#     ActiveStorage.urls_expire_in = @old_urls_expire_in
#   end
#
#   test "signed ID within expiration date" do
#     blob = create_file_blob(filename: "racecar.jpg")
#     get :show, params: { signed_id: blob.signed_id, filename: blob.filename }
#     assert_response :success
#   end
#
#   test "Expired signed ID" do
#     blob = create_file_blob(filename: "racecar.jpg")
#     params = { signed_id: blob.signed_id, filename: blob.filename }
#     travel 2.minutes
#     get(:show, params:)
#     assert_response :not_found
#   end
# end

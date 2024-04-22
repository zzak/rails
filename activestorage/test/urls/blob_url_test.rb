# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"

require "active_storage/engine/routes"

class BlobUrlTest < ActionView::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  routes = ActionDispatch::Routing::RouteSet.new
  ActiveStorage::Routes.draw_routes!(routes)

  include ActionView::Helpers::UrlHelper
  include routes.url_helpers
  ActiveStorage::Blob.service.instance_variable_set(:@url_helpers, routes.url_helpers)
  default_url_options[:host] = "http://example.com"

  test "URLs expiring in 5 minutes" do
    blob = create_blob

    freeze_time do
      assert_equal expected_url_for(blob), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment), blob.url(disposition: :attachment)
    end
  end

  test "URLs force content_type to binary and attachment as content disposition for content types served as binary" do
    blob = create_blob(content_type: "text/html")

    freeze_time do
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/octet-stream"), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/octet-stream"), blob.url(disposition: :inline)
    end
  end

  test "URLs force attachment as content disposition when the content type is not allowed inline" do
    blob = create_blob(content_type: "application/zip")

    freeze_time do
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/zip"), blob.url
      assert_equal expected_url_for(blob, disposition: :attachment, content_type: "application/zip"), blob.url(disposition: :inline)
    end
  end

  test "URLs allow for custom filename" do
    blob = create_blob(filename: "original.txt")
    new_filename = ActiveStorage::Filename.new("new.txt")

    freeze_time do
      assert_equal expected_url_for(blob), blob.url
      assert_equal expected_url_for(blob, filename: new_filename), blob.url(filename: new_filename)
      assert_equal expected_url_for(blob, filename: new_filename), blob.url(filename: "new.txt")
      assert_equal expected_url_for(blob, filename: blob.filename), blob.url(filename: nil)
    end
  end

  test "URLs allow for custom options" do
    blob = create_blob(filename: "original.txt")

    arguments = [
      blob.key
    ]

    kwargs = {
      expires_in: ActiveStorage.service_urls_expire_in,
      disposition: :attachment,
      content_type: blob.content_type,
      filename: blob.filename,
      thumb_size: "300x300",
      thumb_mode: "crop"
    }
    assert_called_with(blob.service, :url, arguments, **kwargs) do
      blob.url(thumb_size: "300x300", thumb_mode: "crop")
    end
  end

  private
    def expected_url_for(blob, disposition: :attachment, filename: nil, content_type: nil, service_name: :local)
      filename ||= blob.filename
      content_type ||= blob.content_type

      key_params = { key: blob.key, disposition: ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: filename.sanitized), content_type: content_type, service_name: service_name }

      "https://example.com/rails/active_storage/disk/#{ActiveStorage.verifier.generate(key_params, expires_in: 5.minutes, purpose: :blob_key)}/#{filename}"
    end
end

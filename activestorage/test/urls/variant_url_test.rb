# frozen_string_literal: true

require "test_helper"
require "active_support/testing/method_call_assertions"

require "active_storage/engine/routes"

class VariantUrlTest < ActionView::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  routes = ActionDispatch::Routing::RouteSet.new
  ActiveStorage::Routes.draw_routes!(routes)

  include ActionView::Helpers::UrlHelper
  include routes.url_helpers
  ActiveStorage::Blob.service.instance_variable_set(:@url_helpers, routes.url_helpers)
  default_url_options[:host] = "http://example.com"

  test "resized variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100]).processed
    assert_match(/racecar\.jpg/, variant.url)
  end


  test "resized and monochrome variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100], colourspace: "b-w").processed
    assert_match(/racecar\.jpg/, variant.url)
  end


  test "disabled variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100], colourspace: "srgb").processed
    assert_match(/racecar\.jpg/, variant.url)
  end

  test "center-weighted crop of JPEG blob using :resize_to_fill" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_fill: [100, 100]).processed
    assert_match(/racecar\.jpg/, variant.url)
  end

  test "resized variation of PSD blob" do
    blob = create_file_blob(filename: "icon.psd", content_type: "image/vnd.adobe.photoshop")
    variant = blob.variant(resize_to_limit: [20, 20]).processed
    assert_match(/icon\.png/, variant.url)
  end

  test "resized variation of ICO blob" do
    blob = create_file_blob(filename: "favicon.ico", content_type: "image/vnd.microsoft.icon")
    variant = blob.variant(resize_to_limit: [20, 20]).processed
    assert_match(/icon\.png/, variant.url)
  end

  test "resized variation of TIFF blob" do
    blob = create_file_blob(filename: "racecar.tif")
    variant = blob.variant(resize_to_limit: [50, 50]).processed
    assert_match(/racecar\.png/, variant.url)
  end

  test "resized variation of BMP blob" do
    blob = create_file_blob(filename: "colors.bmp", content_type: "image/bmp")
    variant = blob.variant(resize_to_limit: [15, 15]).processed
    assert_match(/colors\.png/, variant.url)
  end

  test "resized variation of WEBP blob" do
    blob = create_file_blob(filename: "valley.webp")
    variant = blob.variant(resize_to_limit: [50, 50]).processed
    assert_match(/valley\.webp/, variant.url)
  end

  test "url doesn't grow in length despite long variant options" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      variant = blob.variant(font: "a" * 10_000).processed
      assert_operator variant.url.length, :<, 785
    end
  end

  private
    def process_variants_with(processor)
      previous_processor, ActiveStorage.variant_processor = ActiveStorage.variant_processor, processor
      yield
    rescue LoadError
      ENV["BUILDKITE"] ? raise : skip("Variant processor #{processor.inspect} is not installed")
    ensure
      ActiveStorage.variant_processor = previous_processor
    end
end

# frozen_string_literal: true

require "active_support/testing/strict_warnings"

ENV["RAILS_ENV"] ||= "test"

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/core_ext/object/try"
require "active_support/testing/autorun"
require "image_processing/mini_magick"

require "active_record/testing/query_assertions"

require "action_controller"
require "active_record"
require "active_job"
require "active_storage"

require "active_storage/previewer/poppler_pdf_previewer"
require "active_storage/previewer/mupdf_previewer"
require "active_storage/previewer/video_previewer"

require "active_storage/analyzer/image_analyzer"
require "active_storage/analyzer/image_analyzer/image_magick"
require "active_storage/analyzer/image_analyzer/vips"
require "active_storage/analyzer/video_analyzer"
require "active_storage/analyzer/audio_analyzer"

ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

require "zeitwerk"

loader = Zeitwerk::Loader.new
loader.tag = "ActiveStorageTests"
loader.push_dir(File.expand_path("../app/controllers", __dir__))
loader.push_dir(File.expand_path("../app/controllers/concerns", __dir__))
loader.push_dir(File.expand_path("../app/jobs", __dir__))
loader.push_dir(File.expand_path("../app/models", __dir__))

loader.push_dir(File.expand_path("support/models", __dir__))

loader.setup

ActiveStorage.variant_processor = :vips #app.config.active_storage.variant_processor || :mini_magick
ActiveStorage.previewers        = [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
ActiveStorage.analyzers         = [ ActiveStorage::Analyzer::ImageAnalyzer::Vips, ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick, ActiveStorage::Analyzer::VideoAnalyzer, ActiveStorage::Analyzer::AudioAnalyzer ]
ActiveStorage.paths             = ActiveSupport::OrderedOptions.new
ActiveStorage.routes_prefix     = "/rails/active_storage"
ActiveStorage.draw_routes       = true #app.config.active_storage.draw_routes != false


ActiveStorage.supported_image_processing_methods = []
ActiveStorage.unsupported_image_processing_arguments = %w(
  -debug
  -display
  -distribute-cache
  -help
  -path
  -print
  -set
  -verbose
  -version
  -write
  -write-mask
)

ActiveStorage.variable_content_types = %w(
  image/png
  image/gif
  image/jpeg
  image/tiff
  image/bmp
  image/vnd.adobe.photoshop
  image/vnd.microsoft.icon
  image/webp
  image/avif
  image/heic
  image/heif
)
ActiveStorage.web_image_content_types = %w(
  image/png
  image/jpeg
  image/gif
)
ActiveStorage.content_types_to_serve_as_binary = %w(
  text/html
  image/svg+xml
  application/postscript
  application/x-shockwave-flash
  text/xml
  application/xml
  application/xhtml+xml
  application/mathml+xml
  text/cache-manifest
)
#ActiveStorage.touch_attachment_records = app.config.active_storage.touch_attachment_records != false
ActiveStorage.service_urls_expire_in = 5.minutes
#ActiveStorage.urls_expire_in = app.config.active_storage.urls_expire_in
ActiveStorage.content_types_allowed_inline = %w(
  image/webp
  image/avif
  image/png
  image/gif
  image/jpeg
  image/tiff
  image/bmp
  image/vnd.adobe.photoshop
  image/vnd.microsoft.icon
  application/pdf
)
ActiveStorage.binary_content_type = "application/octet-stream"
ActiveStorage.video_preview_arguments = "-y -vframes 1 -f image2"

###

ActiveRecord.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Attached::Model)

require "active_storage/reflection"
ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

require "active_storage/service/registry"

configs = begin
  ActiveSupport::ConfigurationFile.parse(File.expand_path("service/configurations.yml", __dir__)).deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in test/service/configurations.yml"
  {}
end

# Azure service tests are currently failing on the main branch.
# We temporarily disable them while we get things working again.
if ENV["BUILDKITE"]
  configs.delete(:azure)
  configs.delete(:azure_public)
end

SERVICE_CONFIGURATIONS = configs.merge(
  "tmp" => { "service" => "Disk", "root" => File.join(Dir.tmpdir, "active_storage") },
  "local" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests") },
  "local_public" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests"), "public" => true },
  "disk_mirror_1" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_1") },
  "disk_mirror_2" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_2") },
  "disk_mirror_3" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_3") },
  "mirror" => { "service" => "Mirror", "primary" => "local", "mirrors" => ["disk_mirror_1", "disk_mirror_2", "disk_mirror_3"] }
).deep_stringify_keys

ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new(SERVICE_CONFIGURATIONS)

# NOTE: This broke some tests when set to :tmp
#ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:local)

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = ActiveSupport::Logger.new(nil)

require File.expand_path("../db/migrate/20170806125915_create_active_storage_tables.rb", __dir__).to_s

# NOTE: Unless we remove migration_paths will pick up the default migrations in activestorage/db/migrate
# Then the migration will be loaded twice, which we want to avoid since we need to monkey patch it to remove the dependency on Rails.configuration
ActiveRecord::Migrator.migrations_paths = nil
class CreateActiveStorageTables
  private
    undef_method :primary_and_foreign_key_types
    def primary_and_foreign_key_types
      [:primary_key, :bigint]
    end
end

ActiveRecord::Schema.define do
  CreateActiveStorageTables.new.change

  create_table :groups

  create_table :users do |t|
    t.string :name
    t.integer :group_id
    t.timestamps
  end
end

#loader.eager_load(force: true)

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = ActiveSupport::Logger.new(nil)

ActiveStorage.logger = ActiveSupport::Logger.new(nil)

ActiveRecord::Base.connection.migration_context.migrate

module ActiveStorage::TestHelper
  def self.service_available?(service_name)
    ActiveStorage::Blob.services.fetch(service_name)
  rescue KeyError => error
    @@skipped ||= {}
    unless @@skipped.has_key?(service_name)
      puts error.message
      @@skipped[service_name] = :skipped
    end

    false
  end
end

class ActiveSupport::TestCase
  ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  self.file_fixture_path = ActiveStorage::FixtureSet.file_fixture_path

  include ActiveRecord::TestFixtures
  include ActiveRecord::Assertions::QueryAssertions

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]

  setup do
    ActiveStorage::Current.url_options = { protocol: "https://", host: "example.com", port: nil }
  end

  teardown do
    ActiveStorage::Current.reset
  end

  private
    def create_blob(key: nil, data: "Hello world!", filename: "hello.txt", content_type: "text/plain", identify: true, service_name: nil, record: nil)
      ActiveStorage::Blob.create_and_upload! key: key, io: StringIO.new(data), filename: filename, content_type: content_type, identify: identify, service_name: service_name, record: record
    end

    def create_file_blob(key: nil, filename: "racecar.jpg", content_type: "image/jpeg", metadata: nil, service_name: nil, record: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata, service_name: service_name, record: record
    end

    def create_blob_before_direct_upload(key: nil, filename: "hello.txt", byte_size:, checksum:, content_type: "text/plain", record: nil)
      ActiveStorage::Blob.create_before_direct_upload! key: key, filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, record: record
    end

    def build_blob_after_unfurling(key: nil, data: "Hello world!", filename: "hello.txt", content_type: "text/plain", identify: true, record: nil)
      ActiveStorage::Blob.build_after_unfurling key: key, io: StringIO.new(data), filename: filename, content_type: content_type, identify: identify, record: record
    end

    def directly_upload_file_blob(filename: "racecar.jpg", content_type: "image/jpeg", record: nil)
      file = file_fixture(filename)
      byte_size = file.size
      checksum = OpenSSL::Digest::MD5.file(file).base64digest

      create_blob_before_direct_upload(filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, record: record).tap do |blob|
        service = ActiveStorage::Blob.service.try(:primary) || ActiveStorage::Blob.service
        service.upload(blob.key, file.open)
      end
    end

    def read_image(blob_or_variant)
      MiniMagick::Image.open blob_or_variant.service.send(:path_for, blob_or_variant.key)
    end

    def extract_metadata_from(blob)
      blob.tap(&:analyze).metadata
    end

    def fixture_file_upload(filename)
      Rack::Test::UploadedFile.new file_fixture(filename).to_s
    end

    def with_service(service_name)
      previous_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = service_name ? ActiveStorage::Blob.services.fetch(service_name) : nil

      yield
    ensure
      ActiveStorage::Blob.service = previous_service
    end

    def with_strict_loading_by_default(&block)
      strict_loading_was = ActiveRecord::Base.strict_loading_by_default
      ActiveRecord::Base.strict_loading_by_default = true
      yield
    ensure
      ActiveRecord::Base.strict_loading_by_default = strict_loading_was
    end

    def without_variant_tracking(&block)
      variant_tracking_was = ActiveStorage.track_variants
      ActiveStorage.track_variants = false
      yield
    ensure
      ActiveStorage.track_variants = variant_tracking_was
    end

    def with_raise_on_open_redirects(service)
      old_raise_on_open_redirects = ActionController::Base.raise_on_open_redirects
      old_service = ActiveStorage::Blob.service

      ActionController::Base.raise_on_open_redirects = true
      # TODO: this only is used on s3/azure/gcs paths
      # ActiveStorage::Blob.service = ActiveStorage::Service.configure(service, SERVICE_CONFIGURATIONS)
      yield
    ensure
      ActionController::Base.raise_on_open_redirects = old_raise_on_open_redirects
      ActiveStorage::Blob.service = old_service
    end

    def subscribe_events_from(name)
      events = []
      ActiveSupport::Notifications.subscribe(name) { |event| events << event }
      events
    end
end

require "global_id"
GlobalID.app = "ActiveStorageExampleApp"
ActiveRecord::Base.include GlobalID::Identification

require_relative "../../tools/test_common"

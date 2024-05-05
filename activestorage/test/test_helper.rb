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
require "action_view"

require "active_job"
ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = ActiveSupport::Logger.new(nil)

require "active_storage"
ActiveStorage.logger = ActiveSupport::Logger.new(nil)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")
ActiveStorage::FixtureSet.file_fixture_path = File.expand_path("fixtures/files", __dir__)

class ActiveSupport::TestCase
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

    def create_file_blob(key: nil, filename: "racecar.jpg", fixture: filename, content_type: "image/jpeg", identify: true, metadata: nil, service_name: nil, record: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(fixture).open, filename: filename, content_type: content_type, identify: identify, metadata: metadata, service_name: service_name, record: record
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
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(service, SERVICE_CONFIGURATIONS)
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

require "active_record"
# Writing and reading roles are required for the "previewing on the writer DB" test
config = {
  "primary" => { "adapter" => "sqlite3", "database" => ":memory:" },
  "replica" => { "adapter" => "sqlite3", "database" => ":memory:" },
}
ActiveRecord::Base.configurations = config
ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :replica })
ActiveRecord::Base.logger = Logger.new(nil)

ActiveRecord.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Attached::Model)

require "active_storage/reflection"
ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

require "zeitwerk"

loader = Zeitwerk::Loader.new
loader.tag = "ActiveStorageTests"
loader.push_dir(File.expand_path("../app/controllers", __dir__))
loader.push_dir(File.expand_path("../app/controllers/concerns", __dir__))
loader.push_dir(File.expand_path("../app/jobs", __dir__))
loader.push_dir(File.expand_path("../app/models", __dir__))

# loader.push_dir(File.expand_path("support/models", __dir__))

loader.setup

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
ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:local)

require "./db/migrate/20170806125915_create_active_storage_tables"
require "database/create_groups_migration.rb"
require "database/create_users_migration.rb"
ActiveRecord::Base.connection.pool.migration_context.migrate
ActiveStorageCreateUsers.migrate(:up)
ActiveStorageCreateGroups.migrate(:up)

class User < ActiveRecord::Base
  validates :name, presence: true

  has_one_attached :avatar
  has_one_attached :cover_photo, dependent: false, service: :local
  has_one_attached :avatar_with_variants do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  has_one_attached :avatar_with_preprocessed do |attachable|
    attachable.variant :bool, resize_to_limit: [1, 1], preprocessed: true
  end
  has_one_attached :avatar_with_conditional_preprocessed do |attachable|
    attachable.variant :proc, resize_to_limit: [2, 2],
      preprocessed: ->(user) { user.name == "transform via proc" }
    attachable.variant :method, resize_to_limit: [3, 3],
      preprocessed: :should_preprocessed?
  end
  has_one_attached :intro_video
  has_one_attached :name_pronunciation_audio

  has_many_attached :highlights
  has_many_attached :vlogs, dependent: false, service: :local
  has_many_attached :highlights_with_variants do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
  end
  has_many_attached :highlights_with_preprocessed do |attachable|
    attachable.variant :bool, resize_to_limit: [1, 1], preprocessed: true
  end
  has_many_attached :highlights_with_conditional_preprocessed do |attachable|
    attachable.variant :proc, resize_to_limit: [2, 2],
      preprocessed: ->(user) { user.name == "transform via proc" }
    attachable.variant :method, resize_to_limit: [3, 3],
      preprocessed: :should_preprocessed?
  end
  has_one_attached :resume do |attachable|
    attachable.variant :preview, resize_to_fill: [400, 400]
  end
  has_one_attached :resume_with_preprocessing do |attachable|
    attachable.variant :preview, resize_to_fill: [400, 400], preprocessed: true
  end

  accepts_nested_attributes_for :highlights_attachments, allow_destroy: true

  def should_preprocessed?
    name == "transform via method"
  end
end

class Group < ActiveRecord::Base
  has_one_attached :avatar
  has_many :users, autosave: true

  accepts_nested_attributes_for :users
end

require "active_storage/previewer/poppler_pdf_previewer"
require "active_storage/previewer/mupdf_previewer"
require "active_storage/previewer/video_previewer"

require "active_storage/analyzer/image_analyzer"
require "active_storage/analyzer/image_analyzer/image_magick"
require "active_storage/analyzer/image_analyzer/vips"
require "active_storage/analyzer/video_analyzer"
require "active_storage/analyzer/audio_analyzer"


ActiveStorage.variant_processor = :vips #app.config.active_storage.variant_processor || :mini_magick
ActiveStorage.previewers        = [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
ActiveStorage.analyzers         = [ ActiveStorage::Analyzer::ImageAnalyzer::Vips, ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick, ActiveStorage::Analyzer::VideoAnalyzer, ActiveStorage::Analyzer::AudioAnalyzer ]
ActiveStorage.paths             = ActiveSupport::OrderedOptions.new
ActiveStorage.routes_prefix     = "/rails/active_storage"
ActiveStorage.draw_routes       = true #app.config.active_storage.draw_routes != false


#ActiveStorage.supported_image_processing_methods = []
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

# Variant tracking has been true since load_defaults(6.1)
# However, several tests depend on the defaults being loaded from the old dummy app config.
# Since this is the only config option that was dependent upon that assumption, we can keep it here.
ActiveStorage.track_variants = true

require_relative "../../tools/test_common"

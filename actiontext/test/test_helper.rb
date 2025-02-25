# frozen_string_literal: true

require "active_support/testing/strict_warnings"

require "debug"
require "openssl"

require "action_text"

require "action_controller"
require "action_mailer"
require "action_view"
require "active_job"
require "active_record"
require "active_record/testing/query_assertions"

require "active_storage"
require "active_storage/reflection"
require "active_storage/service/registry"

require "importmap-rails"
require "importmap/map"

require "zeitwerk"
loader = Zeitwerk::Loader.new
loader.push_dir("app/helpers")
loader.push_dir("app/models")
loader.push_dir("app/views")

loader.push_dir("test/support/controllers")
loader.push_dir("test/support/jobs")
loader.push_dir("test/support/models")
loader.push_dir("test/support/mailers")

RAILS_ROOT = Pathname.new(__dir__).join("../..")

loader.push_dir(RAILS_ROOT.join("activestorage/app/controllers"))
loader.push_dir(RAILS_ROOT.join("activestorage/app/controllers/concerns"))
loader.push_dir(RAILS_ROOT.join("activestorage/app/jobs"))
loader.push_dir(RAILS_ROOT.join("activestorage/app/models"))

# Add importmap-rails helpers to the autoload path
importmap_gem_path = Gem::Specification.find_by_name('importmap-rails').gem_dir
loader.push_dir(Pathname.new(importmap_gem_path).join('app/helpers'))

loader.setup

require "active_storage/previewer/poppler_pdf_previewer"
require "active_storage/previewer/mupdf_previewer"
require "active_storage/previewer/video_previewer"
require "active_storage/analyzer/image_analyzer"
require "active_storage/analyzer/image_analyzer/vips"
require "active_storage/analyzer/image_analyzer/image_magick"
require "active_storage/analyzer/video_analyzer"
require "active_storage/analyzer/audio_analyzer"

ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("Testing")

ActiveStorage.variant_processor = :vips #app.config.active_storage.variant_processor || :mini_magick
ActiveStorage.previewers        = [ ActiveStorage::Previewer::PopplerPDFPreviewer, ActiveStorage::Previewer::MuPDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
ActiveStorage.analyzers         = [ ActiveStorage::Analyzer::ImageAnalyzer::Vips, ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick, ActiveStorage::Analyzer::VideoAnalyzer, ActiveStorage::Analyzer::AudioAnalyzer ]
ActiveStorage.paths             = ActiveSupport::OrderedOptions.new
ActiveStorage.routes_prefix     = "/rails/active_storage"
ActiveStorage.draw_routes       = true #app.config.active_storage.draw_routes != false
ActiveStorage.resolve_model_to_route = :rails_storage_redirect



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

=begin
# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
=end

module Rails
  class << self
    def application
      @app ||= Application.new
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def env
      @env ||= Env.new
    end

    def env=(env)
      @env.instance_variable_set(:@env, env)
    end

    def logger
      @logger ||= Logger.new($stdout)
    end
  end

  class Application
    def config
      Rails.configuration
    end

    def credentials
      {}
    end

    def env_config
      {}
    end

    def routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end

    def importmap
      @importmap ||= Importmap::Map.new
    end
  end

  class Configuration
    def active_storage
      @active_storage ||= ActiveSupport::OrderedOptions.new.tap do |config|
        config.service = :local
      end
    end

    def generators(&block)
      @generators ||= GeneratorConfig.new
      yield @generators if block_given?
      @generators
    end
  end

  class Env
    def initialize
      @env = "test"
    end

    [:development?, :test?, :production?].each do |method|
      define_method(method) { @env == method.to_s.delete("?") }
    end
  end

  class GeneratorConfig
    attr_accessor :options

    def initialize
      @options = { active_record: { primary_key_type: nil } }
      @orm = :active_record
    end

    def orm(orm = nil, options = {})
      if orm
        @options[orm] = options
      else
        @orm
      end
    end
  end
end

Rails.application.routes.draw do
  load RAILS_ROOT.join("activestorage/config/routes.rb")

  resources :messages

  namespace :admin do
    resources :messages, only: [:show]
  end
end

Rails.application.routes.default_url_options = { host: "www.example.com" }

class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk)
    @app = @stack.build(@routes)
  end

  def call(env)
    @app.call(env)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  def self.build_app
    RoutedRackApp.new(Rails.application.routes) do |middleware|
      yield(middleware) if block_given?
    end
  end

  self.app = build_app
end

ActiveSupport::TestCase.include(Rails.application.routes.url_helpers)
ActionMailer::Base.include(Rails.application.routes.url_helpers)

Rails.application.routes.define_mounted_helper(:main_app)

ActionController::Base.include(Rails.application.routes.url_helpers)
ActionController::Base.include(Rails.application.routes.mounted_helpers)

ActionController::Base.prepend_view_path("app/views")
ActionController::Base.append_view_path("test/support/views")
ActionController::Base.append_view_path(RAILS_ROOT.join("actionmailbox/app/views"))
ActionController::Base.helper ActionText::ContentHelper, ActionText::TagHelper

#ActiveSupport.on_load(:action_controller_base) do
#  helper Importmap::ImportmapTagsHelper
#end
ActionController::Base.helper Importmap::ImportmapTagsHelper

ActiveSupport.on_load(:active_storage_blob) do
  include ActionText::Attachable

  def previewable_attachable?
    representable?
  end

  def attachable_plain_text_representation(caption = nil)
    "[#{caption || filename}]"
  end

  def to_trix_content_attachment_partial_path
    nil
  end
end

ActiveRecord.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Attached::Model)

ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)

ActiveSupport.on_load(:active_record) do
  include ActionText::Attribute
  prepend ActionText::Encryption
end

ActiveSupport.on_load(:active_record) do
  ActiveStorage.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}active_storage_"
  end
  ActionText.singleton_class.redefine_method(:table_name_prefix) do
    "#{ActiveRecord::Base.table_name_prefix}action_text_"
  end
end

ActiveRecord::Migrator.migrations_paths << File.expand_path("support/migrations", __dir__)
ActiveRecord::Migrator.migrations_paths << File.expand_path("../../activestorage/db/migrate", __dir__)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Base.connection_pool.migration_context.migrate

#ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
#require "rails/test_help"

ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new({
  "test" => { "service" => "Disk", "root" => Dir.mktmpdir("action_text_tests") },
  "local" => { "service" => "Disk", "root" => Dir.mktmpdir("action_text_tests_local") },
  #"test_email" => { "service" => "Disk", "root" => Dir.mktmpdir("action_text_storage_email") },
})
ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:test)

ActiveJob::Base.queue_adapter = :test

require "rails/test_unit/reporter"
Rails::TestUnitReporter.executable = "bin/test"

# Disable available locale checks to allow to add locale after initialized.
I18n.enforce_available_locales = false

# Load fixtures from the engine
#if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
#  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
#  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
#  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
#  ActiveSupport::TestCase.fixtures :all
#end

class ActiveSupport::TestCase
  module QueryHelpers
    include ActiveJob::TestHelper
    include ActiveRecord::Assertions::QueryAssertions
  end

  include ActiveRecord::TestFixtures

  self.fixture_paths = [File.expand_path("fixtures", __dir__)]
  self.file_fixture_path = File.expand_path("fixtures/files", __dir__)
  fixtures :all

  private
    def create_file_blob(filename:, content_type:, metadata: nil)
      ActiveStorage::Blob.create_and_upload! io: file_fixture(filename).open, filename: filename, content_type: content_type, metadata: metadata
    end
end

require "global_id"

require "global_id/fixture_set"
ActiveRecord::FixtureSet.extend(GlobalID::FixtureSet)

GlobalID.app = "actiontext_test"
ActiveRecord::Base.include(GlobalID::Identification)

key_generator = ActiveSupport::KeyGenerator.new("actiontext_tests_generator")
verifier = GlobalID::Verifier.new(key_generator.generate_key('signed_global_ids'))
SignedGlobalID.verifier = verifier

# Encryption
ActiveRecord::Encryption.configure \
  primary_key: "test master key",
  deterministic_key: "test deterministic key",
  key_derivation_salt: "testing key derivation salt",
  support_unencrypted_data: true

Time.zone = "UTC"

require_relative "../../tools/test_common"

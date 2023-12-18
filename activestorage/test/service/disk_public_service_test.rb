# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

class ActiveStorage::Service::DiskPublicServiceTest < ActiveSupport::TestCase
  setup do
    tmp_config = {
      tmp_public: { service: "Disk", root: File.join(Dir.tmpdir, "active_storage_public"), public: true }
    }
    @service = ActiveStorage::Service.configure(:tmp_public, tmp_config)
  end

  include ActiveStorage::Service::SharedServiceTests

  test "public URL generation" do
    url = @service.url(@key, disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

    assert_match(/^https:\/\/example.com\/rails\/active_storage\/disk\/.*\/avatar\.png/, url)
  end
end

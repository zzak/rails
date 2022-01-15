# frozen_string_literal: true

if ENV["BUILDKITE"] || ENV["CIRCLECI"]
  require "minitest-ci"

  job_id = ENV['BUILDKITE_JOB_ID'] || ENV['CIRCLE_BUILD_NUM']
  Minitest::Ci.report_dir = File.join(__dir__, "../test-reports/#{job_id}")
end

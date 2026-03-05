# frozen_string_literal: true

require "cases/helper"
require "active_record/connection_adapters/postgresql/oid/well_known_generator"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class WellKnownGeneratorTest < ActiveRecord::TestCase
        test "build_mappings parses pg_type and pg_range data" do
          generator = OID::WellKnown::Generator.new

          mappings = generator.build_mappings(
            pg_type_source: <<~PG_TYPE,
              [
              { oid => '16', array_type_oid => '1000', typname => 'bool', typinput => 'boolin' },
              { oid => '23', array_type_oid => '1007', typname => 'int4', typinput => 'int4in' },
              { oid => '600', array_type_oid => '1020', typname => 'box', typinput => 'box_in', typdelim => ';' },
              { oid => '1020', typname => '_box', typinput => 'array_in', typelem => 'box', typdelim => ';' },
              { oid => '3904', typname => 'int4range', typtype => 'r' },
              { oid => '5000', typname => 'mydomain', typtype => 'd', typbasetype => 'int4' },
              ]
            PG_TYPE
            pg_range_source: <<~PG_RANGE
              [
              { rngtypid => 'int4range', rngsubtype => 'int4' },
              ]
            PG_RANGE
          )

          assert_equal "bool", mappings[:type_aliases][16]
          assert_equal "int4range", mappings[:type_aliases][3904]
          assert_equal 16, mappings[:array_types][1000]
          assert_equal 600, mappings[:array_types][1020]
          assert_equal ";", mappings[:array_type_delimiters][1020]
          assert_nil mappings[:array_type_delimiters][1000]
          assert_equal 23, mappings[:range_types][3904]
          assert_equal 23, mappings[:domain_types][5000]
        end

        test "render serializes mappings into well_known module constants" do
          generator = OID::WellKnown::Generator.new

          rendered = generator.render(
            {
              type_aliases: { 16 => "bool" },
              array_types: { 1000 => 16, 1020 => 16 },
              array_type_delimiters: { 1020 => ";" },
              range_types: { 3904 => 23 },
              domain_types: { 5000 => 23 }
            },
            pg_type_url: "https://example.test/pg_type.dat",
            pg_range_url: "https://example.test/pg_range.dat"
          )

          assert_includes rendered, "# This file is generated. Do not edit manually."
          assert_includes rendered, "#   bundle exec rake db:postgresql:update_well_known_oids"
          assert_includes rendered, '"pg_type" => "https://example.test/pg_type.dat"'
          assert_includes rendered, '"pg_range" => "https://example.test/pg_range.dat"'
          assert_includes rendered, '16 => "bool",'
          assert_includes rendered, "1000 => 16,"
          assert_includes rendered, '1020 => ";",'
          assert_includes rendered, "3904 => 23,"
          assert_includes rendered, "5000 => 23,"
          assert_not_includes rendered, "def register_types"
        end

        test "latest_stable_branch picks highest REL_X_STABLE branch" do
          generator = OID::WellKnown::Generator.new
          refs = <<~JSON
            [
              { "ref": "refs/heads/REL_17_STABLE" },
              { "ref": "refs/heads/REL_18_STABLE" },
              { "ref": "refs/heads/REL_16_STABLE" },
              { "ref": "refs/heads/master" }
            ]
          JSON

          generator.stub(:fetch_catalog, refs) do
            assert_equal "REL_18_STABLE", generator.send(:latest_stable_branch)
          end
        end
      end
    end
  end
end

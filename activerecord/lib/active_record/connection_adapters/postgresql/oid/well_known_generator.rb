# frozen_string_literal: true

require "json"
require "net/http"

require "active_support/core_ext/string/indent"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        module WellKnown # :nodoc:
          class Generator # :nodoc:
            PG_GIT_REF_API_URL = "https://api.github.com/repos/postgres/postgres/git/matching-refs/heads/REL_"
            PG_RAW_BASE_URL = "https://raw.githubusercontent.com/postgres/postgres/refs/heads"
            PG_TYPE_CATALOG_PATH = "src/include/catalog/pg_type.dat"
            PG_RANGE_CATALOG_PATH = "src/include/catalog/pg_range.dat"
            OUTPUT_PATH = File.expand_path("well_known_values.rb", __dir__)

            class << self
              def generate!(...)
                new(...).generate!
              end
            end

            def initialize(
              output_path: OUTPUT_PATH,
              pg_type_source: nil,
              pg_range_source: nil,
              pg_stable_branch: nil,
              pg_type_url: nil,
              pg_range_url: nil
            )
              @output_path = output_path
              @pg_type_source = pg_type_source
              @pg_range_source = pg_range_source
              @pg_stable_branch = pg_stable_branch
              @pg_type_url = pg_type_url
              @pg_range_url = pg_range_url
            end

            def generate!
              validate_input_pairs!

              pg_stable_branch = resolve_stable_branch
              pg_type_url, pg_range_url = resolve_catalog_urls(pg_stable_branch)
              pg_type_source, pg_range_source = resolve_catalog_sources(pg_type_url, pg_range_url)

              mappings = build_mappings(pg_type_source: pg_type_source, pg_range_source: pg_range_source)
              output = render(
                mappings,
                pg_type_url: pg_type_url,
                pg_range_url: pg_range_url
              )
              File.write(@output_path, output)
              mappings
            end

            def build_mappings(pg_type_source:, pg_range_source:)
              type_rows = parse_catalog_rows(pg_type_source).select { |row| row["oid"] && row["typname"] }
              type_rows.sort_by! { |row| row["oid"].to_i }

              name_to_oid = type_rows.to_h { |row| [row["typname"], row["oid"].to_i] }
              array_types, array_type_delimiters = build_array_types(type_rows, name_to_oid)

              {
                type_aliases: type_rows.to_h { |row| [row["oid"].to_i, row["typname"]] },
                array_types: array_types,
                array_type_delimiters: array_type_delimiters,
                range_types: build_range_types(parse_catalog_rows(pg_range_source), name_to_oid),
                domain_types: build_domain_types(type_rows, name_to_oid)
              }
            end

            def render(mappings, pg_type_url:, pg_range_url:)
              type_aliases_body = render_hash(mappings.fetch(:type_aliases))
              array_types_body = render_hash(mappings.fetch(:array_types))
              array_type_delimiters_body = render_hash(mappings.fetch(:array_type_delimiters))
              range_types_body = render_hash(mappings.fetch(:range_types))
              domain_types_body = render_hash(mappings.fetch(:domain_types))

              <<~RUBY
                # frozen_string_literal: true

                # This file is generated. Do not edit manually.
                #
                # To regenerate:
                #   bundle exec rake db:postgresql:update_well_known_oids

                module ActiveRecord
                  module ConnectionAdapters
                    module PostgreSQL
                      module OID
                        module WellKnown # :nodoc:
                          GENERATED_FROM = {
                            "pg_type" => "#{pg_type_url}",
                            "pg_range" => "#{pg_range_url}",
                          }.freeze

                          TYPE_ALIASES = #{type_aliases_body.indent(10).strip}.freeze

                          ARRAY_TYPES = #{array_types_body.indent(10).strip}.freeze

                          ARRAY_TYPE_DELIMITERS = #{array_type_delimiters_body.indent(10).strip}.freeze

                          RANGE_TYPES = #{range_types_body.indent(10).strip}.freeze

                          DOMAIN_TYPES = #{domain_types_body.indent(10).strip}.freeze
                        end
                      end
                    end
                  end
                end
              RUBY
            end

            private
              def validate_input_pairs!
                if @pg_type_url.nil? ^ @pg_range_url.nil?
                  raise ArgumentError, "pass both pg_type_url and pg_range_url or neither"
                end

                if @pg_type_source.nil? ^ @pg_range_source.nil?
                  raise ArgumentError, "pass both pg_type_source and pg_range_source or neither"
                end
              end

              def resolve_stable_branch
                return @pg_stable_branch if @pg_stable_branch

                if @pg_type_url && @pg_range_url
                  branch = branch_from_catalog_url(@pg_type_url)
                  return branch if branch
                end

                latest_stable_branch
              end

              def resolve_catalog_urls(pg_stable_branch)
                if @pg_type_url && @pg_range_url
                  [@pg_type_url, @pg_range_url]
                else
                  [
                    catalog_url(pg_stable_branch, PG_TYPE_CATALOG_PATH),
                    catalog_url(pg_stable_branch, PG_RANGE_CATALOG_PATH)
                  ]
                end
              end

              def resolve_catalog_sources(pg_type_url, pg_range_url)
                if @pg_type_source && @pg_range_source
                  [@pg_type_source, @pg_range_source]
                else
                  [fetch_catalog(pg_type_url), fetch_catalog(pg_range_url)]
                end
              end

              def catalog_url(branch_name, catalog_path)
                "#{PG_RAW_BASE_URL}/#{branch_name}/#{catalog_path}"
              end

              def branch_from_catalog_url(url)
                URI.parse(url).path[/\/refs\/heads\/([^\/]+)\//, 1]
              end

              def latest_stable_branch
                refs = JSON.parse(fetch_catalog(PG_GIT_REF_API_URL))
                stable_refs = refs.filter_map do |ref|
                  branch_name = ref["ref"].to_s.split("/").last
                  major_version = branch_name[/\AREL_(\d+)_STABLE\z/, 1]
                  next unless major_version

                  [major_version.to_i, branch_name]
                end

                branch = stable_refs.max_by(&:first)&.last
                return branch if branch

                raise RuntimeError, "could not find a PostgreSQL REL_*_STABLE branch"
              end

              def fetch_catalog(url, redirect_limit: 5)
                raise ArgumentError, "too many redirects while fetching #{url}" if redirect_limit <= 0

                uri = URI.parse(url)
                raise ArgumentError, "catalog URL must use HTTPS: #{url}" unless uri.is_a?(URI::HTTPS)

                response = Net::HTTP.get_response(uri)

                case response
                when Net::HTTPSuccess
                  response.body
                when Net::HTTPRedirection
                  location = response["location"]
                  raise "redirect response missing location while fetching #{url}" unless location

                  fetch_catalog(URI.join(url, location).to_s, redirect_limit: redirect_limit - 1)
                else
                  response.value
                end
              end

              def parse_catalog_rows(source)
                source.scan(/\{(.*?)\},/m).map { |record| parse_catalog_row(record.first) }
              end

              def parse_catalog_row(record)
                record.scan(/([a-z_]+)\s*=>\s*'((?:\\'|[^'])*)'/m).to_h.transform_values do |value|
                  value.gsub("\\'", "'")
                end
              end

              def build_array_types(type_rows, name_to_oid)
                array_types = {}
                array_type_delimiters = {}

                type_rows.each do |row|
                  next unless row["array_type_oid"]

                  add_array_type(array_types, array_type_delimiters, row["array_type_oid"].to_i, row["oid"].to_i, row.fetch("typdelim", ","))
                end

                type_rows.each do |row|
                  next unless row["typinput"] == "array_in"

                  subtype_oid = resolve_oid_reference(row["typelem"], name_to_oid)
                  next unless subtype_oid

                  add_array_type(array_types, array_type_delimiters, row["oid"].to_i, subtype_oid, row.fetch("typdelim", ","))
                end

                [array_types, array_type_delimiters]
              end

              def add_array_type(array_types, array_type_delimiters, array_oid, subtype_oid, delimiter)
                array_types[array_oid] = subtype_oid
                if delimiter != ","
                  array_type_delimiters[array_oid] = delimiter
                end
              end

              def build_range_types(range_rows, name_to_oid)
                range_rows.each_with_object({}) do |row, range_types|
                  range_oid = resolve_oid_reference(row["rngtypid"], name_to_oid)
                  subtype_oid = resolve_oid_reference(row["rngsubtype"], name_to_oid)
                  next unless range_oid && subtype_oid

                  range_types[range_oid] = subtype_oid
                end
              end

              def build_domain_types(type_rows, name_to_oid)
                type_rows.each_with_object({}) do |row, domain_types|
                  next unless row["typtype"] == "d"

                  base_oid = resolve_oid_reference(row["typbasetype"], name_to_oid)
                  next unless base_oid

                  domain_types[row["oid"].to_i] = base_oid
                end
              end

              def resolve_oid_reference(value, name_to_oid)
                return if value.nil? || value.empty?
                return value.to_i if value.match?(/\A\d+\z/)

                name_to_oid[value]
              end

              def render_hash(hash)
                if hash.empty?
                  "{}"
                else
                  "{\n" +
                    hash.sort.map do |key, value|
                      "  #{key.inspect} => #{value.inspect},\n"
                    end.join +
                    "}"
                end
              end
          end
        end
      end
    end
  end
end

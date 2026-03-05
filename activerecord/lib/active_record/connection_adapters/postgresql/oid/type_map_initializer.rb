# frozen_string_literal: true

require "active_support/core_ext/array/extract"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        # This class uses the data from PostgreSQL pg_type table to build
        # the OID -> Type mapping.
        #   - OID is an integer representing the type.
        #   - Type is an OID::Type object.
        # This class has side effects on the +store+ passed during initialization.
        class TypeMapInitializer # :nodoc:
          def initialize(store)
            @store = store
          end

          def run(records)
            @pending = Hash.new { |h, oid| h[oid] = [] }

            nodes = records.reject { |row| @store.key? row["oid"].to_i }
            mapped = nodes.extract! { |row| @store.key? row["typname"] }
            ranges = nodes.extract! { |row| row["typtype"] == "r" }
            enums = nodes.extract! { |row| row["typtype"] == "e" }
            domains = nodes.extract! { |row| row["typtype"] == "d" }
            arrays = nodes.extract! { |row| row["typinput"] == "array_in" }
            composites = nodes.extract! { |row| row["typelem"].to_i != 0 }

            mapped.each     { |row| register_mapped_type(row)    }
            enums.each      { |row| register_enum_type(row)      }
            domains.each    { |row| register_domain_type(row)    }
            arrays.each     { |row| register_array_type(row)     }
            ranges.each     { |row| register_range_type(row)     }
            composites.each { |row| register_composite_type(row) }
          end

          def query_conditions_for_known_type_names
            known_type_names = unresolved_type_names
            return if known_type_names.empty?

            <<~SQL % known_type_names.map { |name| "'#{name}'" }.join(", ")
              WHERE
                t.typname IN (%s)
            SQL
          end

          def query_conditions_for_known_type_types
            known_type_types = %w('r' 'e' 'd')
            <<~SQL % known_type_types.join(", ")
              WHERE
                t.typtype IN (%s)
            SQL
          end

          def query_conditions_for_array_types
            known_type_oids = unresolved_array_subtype_oids
            return if known_type_oids.empty?

            <<~SQL % [known_type_oids.join(", ")]
              WHERE
                t.typelem IN (%s)
            SQL
          end

          private
            def unresolved_type_names
              known_type_oids = @store.keys.grep(Integer)
              known_types_by_oid = known_type_oids.map { |oid| @store.lookup(oid) }

              @store.keys.grep(String).reject do |type_name|
                known_types_by_oid.include?(@store.lookup(type_name))
              end
            end

            def unresolved_array_subtype_oids
              known_type_oids = @store.keys.grep(Integer)

              known_type_oids.reject do |subtype_oid|
                subtype = @store.lookup(subtype_oid)

                known_type_oids.any? do |oid|
                  type = @store.lookup(oid)
                  type.is_a?(OID::Array) && type.subtype == subtype
                end
              end
            end

            def register_mapped_type(row)
              alias_type row["oid"], row["typname"]
            end

            def register_enum_type(row)
              register row["oid"], OID::Enum.new
            end

            def register_array_type(row)
              register_with_subtype(row["oid"], row["typelem"].to_i) do |subtype|
                OID::Array.new(subtype, row["typdelim"].freeze)
              end
            end

            def register_range_type(row)
              register_with_subtype(row["oid"], row["rngsubtype"].to_i) do |subtype|
                OID::Range.new(subtype, row["typname"].to_sym)
              end
            end

            def register_domain_type(row)
              if base_type = @store.lookup(row["typbasetype"].to_i)
                register row["oid"], base_type
              else
                warn "unknown base type (OID: #{row["typbasetype"]}) for domain #{row["typname"]}."
              end
            end

            def register_composite_type(row)
              if subtype = @store.lookup(row["typelem"].to_i)
                register row["oid"], OID::Vector.new(row["typdelim"], subtype)
              end
            end

            def register(oid, oid_type = nil, &block)
              oid = assert_valid_registration(oid, oid_type || block)
              if block_given?
                @store.register_type(oid, &block)
              else
                @store.register_type(oid, oid_type)
              end
              flush_pending_registrations(oid)
            end

            def alias_type(oid, target)
              oid = assert_valid_registration(oid, target)
              @store.alias_type(oid, target)
              flush_pending_registrations(oid)
            end

            def register_with_subtype(oid, target_oid)
              if @store.key?(target_oid)
                register(oid) do |_, *args|
                  yield @store.lookup(target_oid, *args)
                end
              else
                @pending[target_oid] << proc do
                  register(oid) do |_, *args|
                    yield @store.lookup(target_oid, *args)
                  end
                end
              end
            end

            def flush_pending_registrations(oid)
              @pending.delete(oid)&.each(&:call)
            end

            def assert_valid_registration(oid, oid_type)
              raise ArgumentError, "can't register nil type for OID #{oid}" if oid_type.nil?
              oid.to_i
            end
        end
      end
    end
  end
end

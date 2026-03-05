# frozen_string_literal: true

require "active_record/connection_adapters/postgresql/oid/well_known_values"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        module WellKnown # :nodoc:
          TYPE_OIDS = TYPE_ALIASES.invert.freeze

          class << self
            def register_types(store)
              register_type_aliases(store)
              register_domain_types(store)
              register_array_types(store)
              register_range_types(store)
            end

            private
              def register_type_aliases(store)
                TYPE_ALIASES.each do |oid, type_name|
                  next unless store.key?(type_name)

                  store.alias_type(oid, type_name)
                end
              end

              def register_domain_types(store)
                DOMAIN_TYPES.each do |oid, base_oid|
                  next unless store.key?(base_oid)

                  store.register_type(oid, store.lookup(base_oid))
                end
              end

              def register_array_types(store)
                ARRAY_TYPES.each do |oid, subtype_oid|
                  next unless store.key?(subtype_oid)

                  delimiter = ARRAY_TYPE_DELIMITERS.fetch(oid, ",")
                  store.register_type(oid) do |_, *args|
                    OID::Array.new(store.lookup(subtype_oid, *args), delimiter)
                  end
                end
              end

              def register_range_types(store)
                RANGE_TYPES.each do |oid, subtype_oid|
                  next unless store.key?(subtype_oid)

                  range_name = TYPE_ALIASES.fetch(oid).to_sym
                  store.register_type(oid) do |_, *args|
                    OID::Range.new(store.lookup(subtype_oid, *args), range_name)
                  end
                end
              end
          end
        end
      end
    end
  end
end

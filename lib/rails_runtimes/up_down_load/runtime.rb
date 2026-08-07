# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

module RailsRuntimes
  module UpDownLoad
    # Runtime registry of schema + surface + repository bindings for export/import.
    class Runtime
      Entry = Struct.new(:schema, :surface, :repository, keyword_init: true)

      def initialize
        @entries = []
      end

      def register(schema, surface:, repository:)
        @entries << Entry.new(schema: schema, surface: surface.to_sym, repository: repository)
        self
      end

      def entries
        @entries.dup
      end

      def schemas
        @entries.map(&:schema).uniq(&:name)
      end

      def for_surface(schema_name, surface)
        @entries.find { |e| e.schema.name == schema_name.to_s && e.surface == surface.to_sym }
      end

      def each_entry(&block)
        @entries.each(&block)
      end
    end
  end
end

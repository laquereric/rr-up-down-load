# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require_relative "outcome"
require_relative "iris"
require_relative "reader"

module RailsRuntimes
  module UpDownLoad
    # Gather from / apply to rr-store repositories by surface.
    class StoreAdapter
      def initialize(runtime)
        @runtime = runtime
      end

      def gather(scope: :application)
        gathered = []
        @runtime.each_entry do |entry|
          next unless in_scope?(entry, scope)

          result = entry.repository.all.await
          return Outcome.err(:gather_failed, because: result.because || result.reason.to_s) if result.err?

          Array(result.value).each do |record|
            gathered << {
              schema: entry.schema,
              record: record,
              surface: entry.surface,
              driver_kind: entry.repository.driver.driver_kind,
              table: entry.repository.table_name
            }
          end
        end
        Outcome.ok(gathered)
      rescue StandardError => e
        Outcome.err(:gather_failed, because: e.message)
      end

      # mode: :replace_scope — clear matching bindings then insert staged records.
      def apply(document, mode: :replace_scope)
        reader = Reader.new(document)
        validation = reader.validate
        return validation if validation.err?

        staged = stage_entities(reader)
        return staged if staged.err?

        if mode.to_sym == :replace_scope
          clear = clear_scope(staged.value.map { |s| [s[:schema].name, s[:surface]] }.uniq)
          return clear if clear.err?
        end

        staged.value.each do |item|
          entry = @runtime.for_surface(item[:schema].name, item[:surface])
          return Outcome.err(:missing_binding, details: { model: item[:schema].name, surface: item[:surface] }) unless entry

          attrs = item[:attributes]
          created = entry.repository.create(attrs).await
          return Outcome.err(:import_create_failed, because: created.because || created.reason.to_s, details: { id: attrs[:id] }) if created.err?
        end

        Outcome.ok({ imported: staged.value.size })
      rescue StandardError => e
        Outcome.err(:apply_failed, because: e.message)
      end

      def clear_all
        clear_scope(@runtime.entries.map { |e| [e.schema.name, e.surface] })
      end

      private

      def in_scope?(entry, scope)
        case scope
        when :application, "application", nil then true
        when Hash
          if scope[:model]
            entry.schema.name == scope[:model].to_s
          elsif scope[:surface]
            entry.surface == scope[:surface].to_sym
          else
            true
          end
        else
          true
        end
      end

      def clear_scope(pairs)
        pairs.each do |name, surface|
          entry = @runtime.for_surface(name, surface)
          next unless entry

          listed = entry.repository.all.await
          return listed if listed.err?

          Array(listed.value).each do |rec|
            destroyed = entry.repository.destroy(rec.id).await
            return destroyed if destroyed.err?
          end
        end
        Outcome.ok(true)
      end

      def stage_entities(reader)
        staged = []
        reader.each_entity do |node|
          model_iri = node.dig("rr:logicalModel", "@id").to_s
          surface_iri = node.dig("rr:onSurface", "@id").to_s
          surface = surface_iri.split(":").last&.to_sym
          token = node["rr:entityToken"].to_s

          schema = @runtime.schemas.find { |s| Iris.model_iri(s.name) == model_iri }
          return Outcome.err(:unknown_model, details: { model_iri: model_iri }) unless schema

          attrs = { schema.identity.field => token }
          schema.columns.each do |col|
            next if col.name == schema.identity.field

            term = Iris.compact_field_term(schema.name, col.name)
            attrs[col.name] = node[term] if node.key?(term)
          end

          staged << { schema: schema, surface: surface, attributes: attrs, token: token }
        end
        Outcome.ok(staged)
      end
    end
  end
end

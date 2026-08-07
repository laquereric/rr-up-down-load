# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

module RailsRuntimes
  module UpDownLoad
    # urn:rr: IRI construction (Bundle Profile v1). No remote lookups.
    module Iris
      module_function

      # Notes::Note -> Notes.Note
      def model_slug(logical_model)
        logical_model.to_s.split("::").join(".")
      end

      def model_iri(logical_model)
        "urn:rr:model:#{model_slug(logical_model)}"
      end

      def binding_iri(logical_model, surface)
        "urn:rr:binding:#{model_slug(logical_model)}:#{surface}"
      end

      def record_iri(entity_token)
        "urn:rr:record:#{entity_token}"
      end

      def store_iri(surface, driver_kind)
        "urn:rr:store:#{surface}:#{driver_kind}"
      end

      def surface_iri(surface)
        "urn:rr:surface:#{surface}"
      end

      def table_iri(table)
        "urn:rr:table:#{table}"
      end

      def field_iri(logical_model, field)
        "urn:rr:field:#{model_slug(logical_model)}:#{field}"
      end

      def column_iri(logical_model, field)
        "urn:rr:column:#{model_slug(logical_model)}:#{field}"
      end

      def shape_iri(logical_model)
        "urn:rr:shape:#{model_slug(logical_model)}"
      end

      def shape_property_iri(logical_model, prop)
        "urn:rr:shape:#{model_slug(logical_model)}:property:#{prop}"
      end

      def identity_iri(logical_model, field)
        "urn:rr:identity:#{model_slug(logical_model)}:#{field}"
      end

      def compact_field_term(logical_model, field)
        parts = logical_model.to_s.split("::")
        ns = parts.first.to_s
        model = parts.last.to_s
        base = "#{ns[0].downcase}#{ns[1..]}#{model}#{field.to_s.split('_').map(&:capitalize).join}"
        # notesNoteTitle style: downcase first char of namespace only when full lower
        slug = model_slug(logical_model).gsub(".", "")
        field_camel = field.to_s.split("_").map.with_index { |p, i| i.zero? ? p : p.capitalize }.join
        # Prefer Notes.Note + title -> notesNoteTitle
        ns_part = parts.first.to_s
        model_part = parts.last.to_s
        "#{ns_part[0].downcase}#{ns_part[1..]}#{model_part}#{field.to_s.split('_').map(&:capitalize).join}"
      end
    end
  end
end

# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require_relative "iris"
require_relative "context"

module RailsRuntimes
  module UpDownLoad
    # Deterministic SHACL Core shape generation from rr-model Schema.
    class ShaclGenerator
      UUID_PATTERN = "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$".freeze

      def generate(schema)
        nodes = []
        shape_id = Iris.shape_iri(schema.name)
        prop_ids = []

        schema.columns.sort_by { |c| c.name.to_s }.each do |col|
          pid = Iris.shape_property_iri(schema.name, col.name)
          prop_ids << { "@id" => pid }
          nodes << property_shape(
            id: pid,
            path: Iris.field_iri(schema.name, col.name),
            datatype: Context.datatype_for(col.type),
            min_count: col.null ? nil : 1,
            pattern: col.type.to_sym == :uuid ? UUID_PATTERN : nil
          )
        end

        # Provenance properties
        {
          entityToken: { path: "rr:entityToken", datatype: "xsd:string", min: 1, pattern: UUID_PATTERN },
          logicalModel: { path: "rr:logicalModel", node_kind: "sh:IRI", min: 1 },
          onSurface: { path: "rr:onSurface", node_kind: "sh:IRI", min: 1 },
          storedIn: { path: "rr:storedIn", node_kind: "sh:IRI", min: 1 },
          inTable: { path: "rr:inTable", node_kind: "sh:IRI", min: 1 },
          viaBinding: { path: "rr:viaBinding", node_kind: "sh:IRI", min: 1 }
        }.sort.to_h.each do |name, spec|
          pid = Iris.shape_property_iri(schema.name, name)
          prop_ids << { "@id" => pid }
          nodes << property_shape(
            id: pid,
            path: spec[:path],
            datatype: spec[:datatype],
            node_kind: spec[:node_kind],
            min_count: spec[:min],
            pattern: spec[:pattern]
          )
        end

        prop_ids.sort_by! { |h| h["@id"] }

        nodes.unshift(
          {
            "@id" => shape_id,
            "@type" => "sh:NodeShape",
            "sh:closed" => true,
            "ignoredProperties" => [{ "@id" => "rdf:type" }],
            "sh:property" => prop_ids,
            "sh:targetClass" => { "@id" => Iris.model_iri(schema.name) }
          }
        )
        nodes
      end

      private

      def property_shape(id:, path:, datatype: nil, node_kind: nil, min_count: nil, pattern: nil)
        node = {
          "@id" => id,
          "@type" => "sh:PropertyShape",
          "sh:maxCount" => 1,
          "sh:path" => path.start_with?("rr:") || path.start_with?("urn:") ? { "@id" => path } : { "@id" => path }
        }
        node["sh:minCount"] = min_count if min_count
        node["sh:datatype"] = { "@id" => datatype } if datatype
        node["sh:nodeKind"] = { "@id" => node_kind } if node_kind
        node["sh:pattern"] = pattern if pattern
        node
      end
    end
  end
end

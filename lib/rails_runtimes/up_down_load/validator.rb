# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require "json"
require_relative "outcome"
require_relative "iris"

module RailsRuntimes
  module UpDownLoad
    # Focused RR-profile validator. Enforces generated SHACL-ish constraints
    # without a heavy RDF library. Embedded shapes remain standard SHACL-Core JSON.
    class Validator
      UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

      def validate(document)
        doc = coerce(document)
        return doc if doc.err?

        doc = doc.value
        errors = []

        errors << { reason: :missing_context } unless doc["@context"].is_a?(Hash)
        graph = doc["@graph"]
        errors << { reason: :missing_graph } unless graph.is_a?(Array)

        return Outcome.err(:invalid_bundle, details: { errors: errors }) if errors.any?

        # No blank nodes
        blank = find_blank_nodes(doc)
        errors << { reason: :blank_nodes, nodes: blank } if blank.any?

        by_id = index_graph(graph)
        bundle = graph.find { |n| n["@type"] == "Bundle" || Array(n["@type"]).include?("Bundle") || Array(n["@type"]).include?("rr:Bundle") }
        errors << { reason: :missing_bundle } unless bundle

        if bundle
          meta_ref = bundle.dig("rr:metadata", "@id")
          meta = by_id[meta_ref]
          errors << { reason: :missing_metadata } unless meta
          if meta
            errors << { reason: :bad_format_version } unless meta["rr:formatVersion"].to_s == FORMAT_VERSION
            errors << { reason: :missing_created_at } if meta["rr:createdAt"].to_s.empty?
            errors << { reason: :missing_state_digest } if meta["rr:stateDigest"].to_s.empty?
          end
        end

        # Validate record nodes against field shapes (minCount + entityToken match)
        graph.each do |node|
          next unless node["rr:entityToken"]

          token = node["rr:entityToken"].to_s
          id = node["@id"].to_s
          errors << { reason: :entity_token_mismatch, id: id, token: token } unless id == Iris.record_iri(token)
          errors << { reason: :invalid_entity_token, token: token } unless token.match?(UUID)
          errors << { reason: :missing_logical_model, id: id } unless node["rr:logicalModel"]
          errors << { reason: :missing_via_binding, id: id } unless node["rr:viaBinding"]
          errors << { reason: :missing_on_surface, id: id } unless node["rr:onSurface"]
        end

        # Enforce SHACL property minCount for NodeShapes targeting model classes
        shapes = graph.select { |n| n["@type"] == "sh:NodeShape" }
        shapes.each do |shape|
          target = shape.dig("sh:targetClass", "@id")
          next unless target.to_s.start_with?("urn:rr:model:")

          # Only typed record instances (not Binding/LogicalModel nodes that also cite logicalModel)
          records = graph.select do |n|
            n["rr:entityToken"] && n.dig("rr:logicalModel", "@id") == target
          end

          prop_refs = Array(shape["sh:property"]).map { |p| p["@id"] || p }
          prop_refs.each do |pid|
            pshape = by_id[pid]
            next unless pshape

            min = pshape["sh:minCount"].to_i
            next if min <= 0

            path = pshape.dig("sh:path", "@id") || pshape["sh:path"]
            records.each do |rec|
              val = value_for_path(rec, path, doc["@context"])
              if val.nil?
                errors << { reason: :shacl_min_count, shape: pid, path: path, record: rec["@id"] }
              end
            end
          end
        end

        if errors.empty?
          Outcome.ok(doc)
        else
          Outcome.err(:invalid_bundle, details: { errors: errors })
        end
      rescue StandardError => e
        Outcome.err(:validation_failed, because: e.message)
      end

      private

      def coerce(document)
        case document
        when Hash
          Outcome.ok(deep_stringify(document))
        when String
          Outcome.ok(deep_stringify(JSON.parse(document)))
        else
          Outcome.err(:invalid_input, because: "expected Hash or JSON String")
        end
      rescue JSON::ParserError => e
        Outcome.err(:parse_failed, because: e.message)
      end

      def deep_stringify(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
        when Array
          obj.map { |i| deep_stringify(i) }
        else
          obj
        end
      end

      def index_graph(graph)
        graph.each_with_object({}) do |node, h|
          h[node["@id"]] = node if node.is_a?(Hash) && node["@id"]
        end
      end

      def find_blank_nodes(obj, found = [])
        case obj
        when Hash
          obj.each do |k, v|
            found << k if k.to_s.start_with?("_:")
            found << v if v.is_a?(String) && v.start_with?("_:")
            find_blank_nodes(v, found)
          end
        when Array
          obj.each { |i| find_blank_nodes(i, found) }
        end
        found
      end

      def value_for_path(record, path, context)
        return record[path] if record.key?(path)

        # Match compact term whose @id equals path
        if context.is_a?(Hash)
          context.each do |term, defn|
            iri = defn.is_a?(Hash) ? defn["@id"] : defn
            return record[term] if iri == path && record.key?(term)
          end
        end

        # Common compact rr: props
        compact = path.to_s.sub(%r{\Aurn:rr:}, "rr:")
        return record[compact] if record.key?(compact)
        return record[path.to_s] if record.key?(path.to_s)

        nil
      end
    end
  end
end

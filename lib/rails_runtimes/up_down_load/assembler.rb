# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require "digest"
require_relative "iris"
require_relative "context"
require_relative "canonical_json"
require_relative "shacl_generator"
require_relative "outcome"

module RailsRuntimes
  module UpDownLoad
    # Builds an RR Bundle Profile v1 document from schemas + gathered records.
    class Assembler
      # gathered: array of { schema:, record: Store::Record, surface:, driver_kind:, table: }
      def initialize(schemas:, gathered:, created_at:, application:, application_version: nil, scope_kind: "application")
        @schemas = Array(schemas)
        @gathered = Array(gathered)
        @created_at = created_at.to_s
        @application = application.to_s
        @application_version = application_version
        @scope_kind = scope_kind.to_s
        @shacl = ShaclGenerator.new
      end

      def build
        graph_nodes = []
        model_nodes = []
        binding_nodes = []
        record_nodes = []
        shape_nodes = []

        @schemas.sort_by(&:name).each do |schema|
          model_nodes.concat(build_model_nodes(schema))
          schema.bindings.each do |b|
            next if b.surface == :default && schema.bindings.size > 1

            binding_nodes << build_binding_node(schema, b)
          end
          shape_nodes.concat(@shacl.generate(schema))
        end

        @gathered.sort_by { |g| g[:record].id.to_s }.each do |g|
          record_nodes << build_record_node(g)
        end

        # Sort all nodes by @id
        all = (model_nodes + binding_nodes + record_nodes + shape_nodes)
        all.sort_by! { |n| n["@id"].to_s }

        binding_iris = binding_nodes.map { |n| n["@id"] }.uniq.sort
        model_iris = @schemas.map { |s| Iris.model_iri(s.name) }.uniq.sort
        entity_iris = record_nodes.map { |n| n["@id"] }.sort
        shape_entry = @schemas.map { |s| Iris.shape_iri(s.name) }.sort

        state_payload = {
          "application" => @application,
          "scopeKind" => @scope_kind,
          "models" => model_nodes,
          "bindings" => binding_nodes,
          "entities" => record_nodes
        }
        state_bytes = CanonicalJson.dump(state_payload)
        state_digest = CanonicalJson.digest_iri(state_bytes)

        schema_payload = {
          "models" => model_nodes,
          "bindings" => binding_nodes,
          "shapes" => shape_nodes
        }
        schema_digest = CanonicalJson.digest_iri(CanonicalJson.dump(schema_payload))

        bundle_id = "urn:rr:bundle:#{state_digest}"
        meta_id = "urn:rr:bundle-meta:#{state_digest}"

        metadata = {
          "@id" => meta_id,
          "@type" => "BundleMetadata",
          "rr:application" => { "@id" => @application.start_with?("urn:") ? @application : "urn:rr:app:#{@application}" },
          "rr:canonicalProfile" => CANONICAL_PROFILE,
          "rr:createdAt" => @created_at,
          "rr:formatVersion" => FORMAT_VERSION,
          "rr:jsonLdVersion" => "1.1",
          "rr:receiptPolicy" => "reuse-if-state-digest-matches",
          "rr:recordCount" => record_nodes.size,
          "rr:resolvedBinding" => binding_iris.map { |id| { "@id" => id } },
          "rr:schemaFingerprint" => schema_digest,
          "rr:scopeKind" => @scope_kind,
          "rr:shapeProfile" => { "@id" => SHAPE_PROFILE },
          "rr:stateDigest" => state_digest
        }
        metadata["rr:applicationVersion"] = @application_version if @application_version

        bundle = {
          "@id" => bundle_id,
          "@type" => "Bundle",
          "rr:metadata" => { "@id" => meta_id },
          "rr:models" => model_iris.map { |id| { "@id" => id } },
          "rr:bindings" => binding_iris.map { |id| { "@id" => id } },
          "rr:entities" => entity_iris.map { |id| { "@id" => id } },
          "rr:shapes" => shape_entry.map { |id| { "@id" => id } }
        }

        graph = [bundle, metadata] + all
        graph.sort_by! { |n| n["@id"].to_s }

        doc = {
          "@context" => Context.for_schemas(@schemas),
          "@graph" => graph
        }
        Outcome.ok(doc)
      rescue StandardError => e
        Outcome.err(:assemble_failed, because: e.message)
      end

      private

      def build_model_nodes(schema)
        nodes = []
        parts = schema.name.split("::")
        col_refs = schema.columns.sort_by { |c| c.name.to_s }.map do |col|
          cid = Iris.column_iri(schema.name, col.name)
          nodes << {
            "@id" => cid,
            "@type" => "Column",
            "rr:fieldName" => col.name.to_s,
            "rr:fieldType" => col.type.to_s,
            "rr:null" => col.null,
            "rr:primaryKey" => col.primary_key
          }
          { "@id" => cid }
        end

        id_field = schema.identity.field
        iid = Iris.identity_iri(schema.name, id_field)
        nodes << {
          "@id" => iid,
          "@type" => "Identity",
          "rr:fieldName" => id_field.to_s,
          "rr:strategy" => schema.identity.strategy.to_s
        }

        bindings = schema.bindings.reject { |b| b.surface == :default && schema.bindings.size > 1 }
        nodes << {
          "@id" => Iris.model_iri(schema.name),
          "@type" => %w[LogicalModel rdfs:Class],
          "rr:column" => col_refs,
          "rr:descriptorVersion" => schema.descriptor_version.to_s,
          "rr:hasBinding" => bindings.map { |b| { "@id" => Iris.binding_iri(schema.name, b.surface) } }.sort_by { |h| h["@id"] },
          "rr:identity" => { "@id" => iid },
          "rr:name" => parts.last.to_s,
          "rr:namespace" => parts.first.to_s,
          "rr:table" => { "@id" => Iris.table_iri(schema.table) }
        }
        nodes
      end

      def build_binding_node(schema, binding)
        surface = binding.surface
        driver = binding.driver_kind || :unknown
        {
          "@id" => Iris.binding_iri(schema.name, surface),
          "@type" => "Binding",
          "rr:logicalModel" => { "@id" => Iris.model_iri(schema.name) },
          "rr:onSurface" => { "@id" => Iris.surface_iri(surface) },
          "rr:storedIn" => { "@id" => Iris.store_iri(surface, driver) },
          "rr:table" => { "@id" => Iris.table_iri(binding.table) },
          "rr:driverKind" => driver.to_s
        }
      end

      def build_record_node(entry)
        schema = entry[:schema]
        record = entry[:record]
        origin = record.origin
        surface = origin&.surface || entry[:surface]
        driver_kind = origin&.driver_kind || entry[:driver_kind]
        table = origin&.table || entry[:table] || schema.table
        token = origin&.entity_token || record.id.to_s

        node = {
          "@id" => Iris.record_iri(token),
          "@type" => Context.model_compact(schema.name),
          "rr:entityToken" => token,
          "rr:logicalModel" => { "@id" => Iris.model_iri(schema.name) },
          "rr:onSurface" => { "@id" => Iris.surface_iri(surface) },
          "rr:storedIn" => { "@id" => Iris.store_iri(surface, driver_kind) },
          "rr:inTable" => { "@id" => Iris.table_iri(table) },
          "rr:viaBinding" => { "@id" => Iris.binding_iri(schema.name, surface) }
        }

        schema.columns.each do |col|
          value = record[col.name]
          next if value.nil?

          term = Iris.compact_field_term(schema.name, col.name)
          node[term] = encode_value(col.type, value)
        end
        node
      end

      def encode_value(type, value)
        case type.to_sym
        when :integer then value.to_i
        when :boolean then !!value
        when :uuid, :string, :text then value.to_s
        else value.to_s
        end
      end
    end
  end
end

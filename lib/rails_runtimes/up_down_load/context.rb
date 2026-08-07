# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require_relative "iris"

module RailsRuntimes
  module UpDownLoad
    # Inline JSON-LD 1.1 @context — no remote URLs.
    module Context
      module_function

      BASE = {
        "@version" => 1.1,
        "rr" => "urn:rr:",
        "rrm" => "urn:rr:model:",
        "rrb" => "urn:rr:binding:",
        "rrr" => "urn:rr:record:",
        "rrs" => "urn:rr:store:",
        "rrf" => "urn:rr:field:",
        "rrsh" => "urn:rr:shape:",
        "rrsurf" => "urn:rr:surface:",
        "rrtbl" => "urn:rr:table:",
        "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "rdfs" => "http://www.w3.org/2000/01/rdf-schema#",
        "sh" => "http://www.w3.org/ns/shacl#",
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
        "Bundle" => "rr:Bundle",
        "BundleMetadata" => "rr:BundleMetadata",
        "LogicalModel" => "rr:LogicalModel",
        "Binding" => "rr:Binding",
        "Column" => "rr:Column",
        "Identity" => "rr:Identity",
        "rr:metadata" => { "@type" => "@id" },
        "rr:models" => { "@container" => "@set", "@type" => "@id" },
        "rr:bindings" => { "@container" => "@set", "@type" => "@id" },
        "rr:entities" => { "@container" => "@set", "@type" => "@id" },
        "rr:shapes" => { "@container" => "@set", "@type" => "@id" },
        "rr:logicalModel" => { "@type" => "@id" },
        "rr:storedIn" => { "@type" => "@id" },
        "rr:onSurface" => { "@type" => "@id" },
        "rr:inTable" => { "@type" => "@id" },
        "rr:viaBinding" => { "@type" => "@id" },
        "rr:hasBinding" => { "@container" => "@set", "@type" => "@id" },
        "rr:table" => { "@type" => "@id" },
        "rr:column" => { "@container" => "@set", "@type" => "@id" },
        "rr:identity" => { "@type" => "@id" },
        "rr:entityToken" => "xsd:string",
        "rr:name" => "xsd:string",
        "rr:namespace" => "xsd:string",
        "rr:fieldName" => "xsd:string",
        "rr:fieldType" => "xsd:string",
        "rr:null" => "xsd:boolean",
        "rr:primaryKey" => "xsd:boolean",
        "rr:strategy" => "xsd:string",
        "rr:formatVersion" => "xsd:string",
        "rr:jsonLdVersion" => "xsd:string",
        "rr:shapeProfile" => { "@type" => "@id" },
        "rr:createdAt" => { "@type" => "xsd:dateTime" },
        "rr:application" => { "@type" => "@id" },
        "rr:applicationVersion" => "xsd:string",
        "rr:schemaFingerprint" => "xsd:string",
        "rr:stateDigest" => "xsd:string",
        "rr:scopeKind" => "xsd:string",
        "rr:resolvedBinding" => { "@container" => "@set", "@type" => "@id" },
        "rr:recordCount" => "xsd:integer",
        "rr:canonicalProfile" => "xsd:string",
        "rr:receiptPolicy" => "xsd:string",
        "rr:driverKind" => "xsd:string",
        "rr:descriptorVersion" => "xsd:string",
        "sh:closed" => "xsd:boolean",
        "sh:minCount" => "xsd:integer",
        "sh:maxCount" => "xsd:integer",
        "sh:datatype" => { "@type" => "@id" },
        "sh:path" => { "@type" => "@id" },
        "sh:nodeKind" => { "@type" => "@id" },
        "sh:targetClass" => { "@type" => "@id" },
        "sh:class" => { "@type" => "@id" },
        "sh:property" => { "@container" => "@set", "@type" => "@id" },
        "sh:pattern" => "xsd:string",
        "ignoredProperties" => {
          "@id" => "sh:ignoredProperties",
          "@container" => "@list",
          "@type" => "@id"
        }
      }.freeze

      def for_schemas(schemas)
        ctx = BASE.dup
        Array(schemas).each do |schema|
          compact = model_compact(schema.name)
          ctx[compact] = Iris.model_iri(schema.name)
          schema.columns.each do |col|
            term = Iris.compact_field_term(schema.name, col.name)
            ctx[term] = {
              "@id" => Iris.field_iri(schema.name, col.name),
              "@type" => datatype_for(col.type)
            }
          end
        end
        ctx
      end

      def model_compact(logical_model)
        parts = logical_model.to_s.split("::")
        ns = parts.first.to_s
        model = parts.last.to_s
        "#{ns[0].downcase}#{ns[1..]}#{model}"
      end

      def datatype_for(type)
        case type.to_sym
        when :integer then "xsd:integer"
        when :boolean then "xsd:boolean"
        when :float then "xsd:double"
        when :decimal then "xsd:decimal"
        when :date then "xsd:date"
        when :datetime then "xsd:dateTime"
        else "xsd:string"
        end
      end
    end
  end
end

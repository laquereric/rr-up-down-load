# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require "json"
require_relative "outcome"
require_relative "validator"

module RailsRuntimes
  module UpDownLoad
    # Standalone reader — iterate entities without application model code.
    class Reader
      attr_reader :document

      def self.open(bundle)
        new(bundle)
      end

      def initialize(bundle)
        raw =
          case bundle
          when Hash then bundle
          when String then JSON.parse(bundle)
          else raise ArgumentError, "bundle must be Hash or JSON String"
          end
        @document = deep_stringify(raw)
        @graph = Array(@document["@graph"])
        @by_id = @graph.each_with_object({}) { |n, h| h[n["@id"]] = n if n["@id"] }
      end

      def valid?
        Validator.new.validate(@document).ok?
      end

      def validate
        Validator.new.validate(@document)
      end

      def metadata
        bundle = bundle_node
        return nil unless bundle

        ref = bundle.dig("rr:metadata", "@id")
        @by_id[ref]
      end

      def entities
        @graph.select { |n| n["rr:entityToken"] }.sort_by { |n| n["@id"].to_s }
      end

      def each_entity(&block)
        return enum_for(:each_entity) unless block

        entities.each(&block)
      end

      def models
        @graph.select { |n| types = Array(n["@type"]); types.include?("LogicalModel") || types.include?("rr:LogicalModel") }
      end

      def bindings
        @graph.select { |n| types = Array(n["@type"]); types.include?("Binding") || types.include?("rr:Binding") }
      end

      def entity_attributes(node)
        attrs = {}
        node.each do |k, v|
          next if k.start_with?("@") || k.start_with?("rr:")

          attrs[k] = v
        end
        attrs
      end

      private

      def bundle_node
        @graph.find do |n|
          t = Array(n["@type"])
          t.include?("Bundle") || t.include?("rr:Bundle")
        end
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
    end
  end
end

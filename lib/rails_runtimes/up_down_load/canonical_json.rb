# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require "json"
require "digest"

module RailsRuntimes
  module UpDownLoad
    # RR Canonical JSON Profile v1 — RFC 8785-compatible object key order;
    # omit JSON null (RR/SQL NULL = property absence); LF + trailing LF.
    module CanonicalJson
      module_function

      def dump(value)
        "#{JSON.generate(canonicalize(value), ascii_only: false)}\n"
      end

      def canonicalize(value)
        case value
        when Hash
          value.each_with_object({}) do |(k, v), h|
            next if v.nil?

            h[k.to_s] = canonicalize(v)
          end.sort.to_h
        when Array
          value.map { |item| canonicalize(item) }
        when Symbol
          value.to_s
        else
          value
        end
      end

      def sha256_hex(bytes)
        Digest::SHA256.hexdigest(bytes)
      end

      def digest_iri(bytes)
        "sha256:#{sha256_hex(bytes)}"
      end
    end
  end
end

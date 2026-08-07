# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require_relative "up_down_load/version"
require_relative "up_down_load/outcome"
require_relative "up_down_load/iris"
require_relative "up_down_load/canonical_json"
require_relative "up_down_load/context"
require_relative "up_down_load/shacl_generator"
require_relative "up_down_load/assembler"
require_relative "up_down_load/validator"
require_relative "up_down_load/reader"
require_relative "up_down_load/runtime"
require_relative "up_down_load/store_adapter"

# Portable SHACL-constrained JSON-LD export/import for RailsRuntimes.
# "Store your data on your laptop" — RR Bundle Profile v1.
module RailsRuntimes
  module UpDownLoad
    module_function

    def version = VERSION

    def hello
      { ok: true, gem: "rr-up-down-load", version: VERSION }
    end

    # Export selected state as canonical .rr.jsonld bytes (String).
    # created_at MUST be passed in (pure fn — no Time.now).
    def download(scope: :application, runtime:, created_at:, application:, application_version: nil)
      adapter = StoreAdapter.new(runtime)
      gathered = adapter.gather(scope: scope)
      return gathered if gathered.err?

      assembled = Assembler.new(
        schemas: runtime.schemas,
        gathered: gathered.value,
        created_at: created_at,
        application: application,
        application_version: application_version,
        scope_kind: scope.is_a?(Hash) ? scope.keys.first.to_s : scope.to_s
      ).build
      return assembled if assembled.err?

      validated = Validator.new.validate(assembled.value)
      return validated if validated.err?

      bytes = CanonicalJson.dump(assembled.value)
      Outcome.ok(bytes)
    rescue StandardError => e
      Outcome.err(:download_failed, because: e.message)
    end

    # Parse + validate; return Reader for standalone iteration.
    def read(bundle)
      reader = Reader.open(bundle)
      validation = reader.validate
      return validation if validation.err?

      Outcome.ok(reader)
    rescue StandardError => e
      Outcome.err(:read_failed, because: e.message)
    end

    # Validate only.
    def validate(bundle)
      Validator.new.validate(bundle)
    rescue StandardError => e
      Outcome.err(:validation_failed, because: e.message)
    end

    # Import bundle into runtime stores. Validates before any mutation.
    def upload(bundle, runtime:, mode: :replace_scope)
      doc =
        case bundle
        when String
          require "json"
          JSON.parse(bundle)
        when Hash
          bundle
        else
          return Outcome.err(:invalid_input, because: "bundle must be String or Hash")
        end

      pre = Validator.new.validate(doc)
      return pre if pre.err?

      StoreAdapter.new(runtime).apply(doc, mode: mode)
    rescue StandardError => e
      Outcome.err(:upload_failed, because: e.message)
    end
  end
end

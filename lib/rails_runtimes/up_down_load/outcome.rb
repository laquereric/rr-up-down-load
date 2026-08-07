# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

module RailsRuntimes
  module UpDownLoad
    class Outcome
      attr_reader :ok, :value, :reason, :because, :details

      def self.ok(value = nil, details: {})
        new(ok: true, value: value, reason: nil, because: nil, details: details)
      end

      def self.err(reason, because: nil, details: {})
        new(ok: false, value: nil, reason: reason.to_sym, because: because, details: details)
      end

      def initialize(ok:, value:, reason:, because:, details:)
        @ok = !!ok
        @value = value
        @reason = reason
        @because = because
        @details = (details || {}).freeze
        freeze
      end

      def ok?
        @ok
      end

      def err?
        !@ok
      end

      def to_h
        if ok?
          { ok: true, value: value, details: details }
        else
          { ok: false, reason: reason, because: because, details: details }
        end
      end
    end
  end
end

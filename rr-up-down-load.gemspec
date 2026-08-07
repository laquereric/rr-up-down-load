# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require_relative "lib/rails_runtimes/up_down_load/version"

Gem::Specification.new do |spec|
  spec.name        = "rr-up-down-load"
  spec.version     = RailsRuntimes::UpDownLoad::VERSION
  spec.authors     = ["Eric Laquer"]
  spec.email       = ["LaquerEric@gmail.com"]
  spec.summary     = "Portable SHACL-constrained JSON-LD export/import for RailsRuntimes (RR Bundle Profile v1)."
  spec.description = spec.summary
  spec.homepage    = "https://github.com/laquereric/DataYoursSoftwareMine"
  spec.license     = "LicenseRef-DataYoursSoftwareMine-1.0"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*", "README.md", "LICENSE", "NOTICE"].select { |f| File.file?(f) }
  spec.require_paths = ["lib"]
  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => "https://github.com/laquereric/rr-up-down-load",
    "rubygems_mfa_required" => "true"
  }
  spec.add_dependency "rr-model", "~> 0.2"
  spec.add_dependency "rr-store", "~> 0.2"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "sqlite3", ">= 1.4"
  spec.add_development_dependency "activerecord", ">= 7.0"
  spec.add_development_dependency "rr-store-opfs", ">= 0.2"
end

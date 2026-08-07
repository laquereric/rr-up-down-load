# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require "spec_helper"
require "json"

RSpec.describe RailsRuntimes::UpDownLoad do
  FIXED_AT = "2026-08-06T12:00:00.000000Z"

  def note_schema
    out = RailsRuntimes::Model.define("Notes::Note", table: "notes") do
      field :id, type: :uuid, null: false, primary_key: true, default: "__rr_uuid__"
      field :title, type: :string, null: false, default: ""
      field :body, type: :text, null: true
      identity :id, strategy: :client_uuid
      validates :title, :presence
      store surface: :server, table: "notes", driver_kind: :active_record
      store surface: :browser, table: "notes", driver_kind: :opfs_sqlite
      local_only
    end
    expect(out.ok?).to be(true), out.to_h.inspect
    out.value
  end

  def build_runtime(schema)
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ar = RailsRuntimes::Store::Server::ActiveRecordDriver.new
    expect(ar.install_schema(schema).await.ok?).to be(true)
    RailsRuntimes::Store::DriverRegistry.register(schema, ar, surface: :server)
    server_repo = RailsRuntimes::Store.for(schema, surface: :server)

    opfs = RailsRuntimes::Store::Opfs.test_driver(schema: schema, surface: :browser)
    browser_repo = RailsRuntimes::Store.for(schema, surface: :browser)
    expect(browser_repo.driver).to eq(opfs)

    runtime = described_class::Runtime.new
    runtime.register(schema, surface: :server, repository: server_repo)
    runtime.register(schema, surface: :browser, repository: browser_repo)
    [runtime, server_repo, browser_repo]
  end

  it "has a version and hello envelope" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+/)
    expect(described_class.hello[:ok]).to be(true)
  end

  it "generates SHACL shapes for Notes::Note" do
    schema = note_schema
    shapes = described_class::ShaclGenerator.new.generate(schema)
    root = shapes.find { |n| n["@id"] == "urn:rr:shape:Notes.Note" }
    expect(root).not_to be_nil
    expect(root["@type"]).to eq("sh:NodeShape")
    expect(root["sh:closed"]).to be(true)
    title_prop = shapes.find { |n| n["@id"]&.include?("property:title") }
    expect(title_prop["sh:minCount"]).to eq(1)
    body_prop = shapes.find { |n| n["@id"]&.include?("property:body") }
    expect(body_prop["sh:minCount"]).to be_nil
  end

  it "canonical JSON is byte-stable for the same structure" do
    doc = { "b" => 1, "a" => [2, 3], "c" => nil }
    a = described_class::CanonicalJson.dump(doc)
    b = described_class::CanonicalJson.dump(doc)
    expect(a).to eq(b)
    expect(a).to end_with("\n")
    expect(a).not_to include("null")
    expect(a).to include('"a"')
    # keys sorted: a before b
    expect(a.index('"a"')).to be < a.index('"b"')
  end

  it "reader iterates entities standalone after validate" do
    schema = note_schema
    runtime, server_repo, browser_repo = build_runtime(schema)
    server_repo.create(id: "11111111-1111-4111-8111-111111111111", title: "S", body: "sv").await
    browser_repo.create(id: "22222222-2222-4222-8222-222222222222", title: "B", body: nil).await

    dl = described_class.download(
      runtime: runtime, created_at: FIXED_AT, application: "notes-demo"
    )
    expect(dl.ok?).to be(true), dl.to_h.inspect

    rd = described_class.read(dl.value)
    expect(rd.ok?).to be(true), rd.to_h.inspect
    reader = rd.value
    ids = reader.entities.map { |e| e["rr:entityToken"] }.sort
    expect(ids).to eq(%w[
      11111111-1111-4111-8111-111111111111
      22222222-2222-4222-8222-222222222222
    ])
  end

  it "rejects invalid bundles before mutation" do
    schema = note_schema
    runtime, = build_runtime(schema)
    bad = { "@context" => {}, "@graph" => [{ "@id" => "_:blank", "@type" => "Bundle" }] }
    out = described_class.upload(bad, runtime: runtime)
    expect(out.err?).to be(true)
    expect(out.reason).to eq(:invalid_bundle)
  end

  describe "round-trip gate" do
    it "download -> clear -> upload -> identical; export2 == export1 byte-stable" do
      schema = note_schema
      runtime, server_repo, browser_repo = build_runtime(schema)

      sid = "11111111-1111-4111-8111-111111111111"
      bid = "22222222-2222-4222-8222-222222222222"
      expect(server_repo.create(id: sid, title: "Server note", body: "from AR").await.ok?).to be(true)
      expect(browser_repo.create(id: bid, title: "Browser note", body: "from OPFS").await.ok?).to be(true)

      export1 = described_class.download(
        runtime: runtime, created_at: FIXED_AT, application: "notes-demo", application_version: "0.1.0"
      )
      expect(export1.ok?).to be(true), export1.to_h.inspect
      bytes1 = export1.value
      expect(bytes1).to include('"@context"')
      expect(bytes1).to include("urn:rr:record:#{sid}")
      expect(bytes1).to include("urn:rr:record:#{bid}")
      expect(bytes1).to include("urn:rr:surface:server")
      expect(bytes1).to include("urn:rr:surface:browser")

      # clear both stores
      adapter = described_class::StoreAdapter.new(runtime)
      expect(adapter.clear_all.ok?).to be(true)
      expect(server_repo.all.await.value).to eq([])
      expect(browser_repo.all.await.value).to eq([])

      # invalid must not write
      bad_up = described_class.upload("{not json", runtime: runtime)
      expect(bad_up.err?).to be(true)

      up = described_class.upload(bytes1, runtime: runtime)
      expect(up.ok?).to be(true), up.to_h.inspect

      s = server_repo.find(sid).await
      b = browser_repo.find(bid).await
      expect(s.value[:title]).to eq("Server note")
      expect(s.value[:body]).to eq("from AR")
      expect(b.value[:title]).to eq("Browser note")
      expect(b.value[:body]).to eq("from OPFS")
      expect(s.value.origin.surface).to eq(:server)
      expect(b.value.origin.surface).to eq(:browser)

      export2 = described_class.download(
        runtime: runtime, created_at: FIXED_AT, application: "notes-demo", application_version: "0.1.0"
      )
      expect(export2.ok?).to be(true), export2.to_h.inspect
      expect(export2.value).to eq(bytes1)
    end
  end

  it "contains no private-substrate vocabulary in library sources" do
    root = File.expand_path("../lib", __dir__)
    hits = Dir[File.join(root, "**", "*.rb")].flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, i|
        if line.match?(/\b(Mmg|mmg-|urn:mm:|epic_|SAL|substrate|vv-|a2a)\b/i)
          "#{path}:#{i + 1}:#{line.strip}"
        end
      end
    end
    expect(hits).to eq([])
  end
end

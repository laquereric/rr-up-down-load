# frozen_string_literal: true
# Copyright 2026 CBI BUSINESS TRANSACTIONS, LLC
# SPDX-License-Identifier: Apache-2.0
# Part of RailsRuntimes -- https://github.com/laquereric/DataYoursSoftwareMine

require "rails_runtimes/up_down_load"
require "rails_runtimes/model"
require "rails_runtimes/store"
require "rails_runtimes/store/server"
require "rails_runtimes/store/opfs"
require "active_record"

RSpec.configure do |c|
  c.disable_monkey_patching!

  c.before(:each) do
    RailsRuntimes::Store::DriverRegistry.reset!
    RailsRuntimes::Store.runtime_surface = nil
  end
end

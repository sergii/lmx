# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Platform reliability RLS", type: :model do
  it "enables and forces workspace RLS on Inbox, Event Store, and Outbox tables" do
    rows = ActiveRecord::Base.connection.exec_query(<<~SQL).to_a.index_by { |row| row.fetch("relname") }
      SELECT relname, relrowsecurity, relforcerowsecurity
      FROM pg_class
      WHERE relname IN (
        'platform_inbox_messages',
        'platform_domain_events',
        'platform_outbox_messages'
      )
    SQL

    expect(rows.keys).to contain_exactly(
      "platform_inbox_messages",
      "platform_domain_events",
      "platform_outbox_messages"
    )
    rows.each_value do |row|
      expect(row).to include("relrowsecurity" => true, "relforcerowsecurity" => true)
    end
  end
end

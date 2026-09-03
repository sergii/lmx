# frozen_string_literal: true

require "rails_helper"

RSpec.describe TypedId do
  fixtures :users

  it "serializes UUID primary keys as compact TypeIDs and parses them back" do
    user = users(:one)

    expect(user.typed_id).to match(/\Auser_[0-7][0-9a-hjkmnp-tv-z]{25}\z/)
    expect(User.typed_id_value(user.typed_id)).to eq(user.id)
  end

  it "rejects a valid TypeID with the wrong record type" do
    expect { User.typed_id_value("candidate_01h46z1k2cf2av8mp4r7we4697") }
      .to raise_error(ActiveRecord::RecordNotFound)
  end
end

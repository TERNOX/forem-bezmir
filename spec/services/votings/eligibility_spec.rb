require "rails_helper"

RSpec.describe Votings::Eligibility do
  let(:voting) { create(:voting) }
  let(:user) { create(:user) }

  def reason_for(voting, user)
    described_class.call(voting, user).reason
  end

  it "lets a confirmed member with a non-negative score vote" do
    expect(described_class.call(voting, user)).to be_eligible
  end

  it "lets brand-new members (score 0) vote by default" do
    user.update_column(:score, 0)
    expect(reason_for(voting, user)).to be_nil
  end

  it "reports the voting state first" do
    expect(reason_for(build(:voting, published: false), user)).to eq(:draft)
    expect(reason_for(build(:voting, opens_at: 1.day.from_now), user)).to eq(:upcoming)
    expect(reason_for(build(:voting, opens_at: 2.days.ago, closes_at: 1.day.ago), user)).to eq(:closed)
  end

  it "requires signing in" do
    expect(reason_for(voting, nil)).to eq(:sign_in)
  end

  it "requires a confirmed email" do
    user.update_column(:confirmed_at, nil)
    expect(reason_for(voting, user)).to eq(:unconfirmed)
  end

  it "rejects suspended and spam members" do
    expect(reason_for(voting, create(:user, :suspended))).to eq(:restricted)
    expect(reason_for(voting, create(:user, :spam))).to eq(:restricted)
  end

  it "rejects members with a negative score" do
    user.update_column(:score, -5)
    expect(reason_for(voting, user)).to eq(:low_score)
  end

  it "honours a higher minimum score" do
    voting.update!(min_user_score: 10)
    user.update_column(:score, 9)
    expect(reason_for(voting, user)).to eq(:low_score)
  end

  it "can require accounts older than the voting" do
    voting.update!(require_account_before_start: true, opens_at: 1.day.ago)
    expect(reason_for(voting, user)).to eq(:account_too_new)

    user.update_column(:created_at, 2.days.ago)
    expect(reason_for(voting, user)).to be_nil
  end
end

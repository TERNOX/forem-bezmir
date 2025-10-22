require "rails_helper"

RSpec.describe Users::CalculateMonthlyReputation do
  let(:period) { Date.new(2025, 10, 1) }
  let!(:badge) do
    create(:badge, title: "Топ 10 користувачів місяця", allow_multiple_awards: true)
  end

  before do
    # Ensure the badge slug matches the expected value
    badge.update!(slug: Users::CalculateMonthlyReputation::BADGE_SLUG)
  end

  it "persists monthly scores and awards the top 10" do
    recipient = create(:user)
    other_recipient = create(:user)
    liker = create(:user)

    article = create(:article, user: recipient)
    create(:reaction, reactable: article, user: liker, status: "valid", category: "like", created_at: period + 1.day)

    comment = create(:comment, user: other_recipient)
    create(:reaction, reactable: comment, user: liker, status: "confirmed", category: "like", created_at: period + 2.days)

    expect do
      described_class.call(period: period)
    end.to change { MonthlyUserReputation.where(period: period).count }.from(0).to(2)
      .and change(BadgeAchievement, :count).by(2)

    top_entry = MonthlyUserReputation.find_by(user: recipient, period: period)
    second_entry = MonthlyUserReputation.find_by(user: other_recipient, period: period)

    expect(top_entry.score).to eq(1)
    expect(top_entry.rank).to eq(1)
    expect(top_entry.awarded_top_ten_at).to be_present

    expect(second_entry.score).to eq(1)
    expect(second_entry.rank).to eq(2)
    expect(second_entry.awarded_top_ten_at).to be_present

    expect do
      described_class.call(period: period)
    end.not_to change(BadgeAchievement, :count)
  end

  it "clears out users with no reactions for the month" do
    user = create(:user)
    create(:monthly_user_reputation, user: user, period: period, score: 5, rank: 1)

    described_class.call(period: period)

    expect(MonthlyUserReputation.for_period(period)).to be_empty
  end
end

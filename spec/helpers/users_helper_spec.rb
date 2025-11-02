require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  include ActiveSupport::Testing::TimeHelpers

  describe "#reputation_breakdown" do
    let(:user) { build_stubbed(:user, reputation_score: 120) }

    around do |example|
      travel_to(Time.zone.local(2025, 3, 15, 12)) { example.run }
    end

    it "returns formatted sections with totals, percentages, and ranks" do
      allow(Users::ReputationBreakdown).to receive(:call)
        .with(user)
        .and_return({ articles: 40, comments: 10 })
      allow(Users::ReputationBreakdown).to receive(:call)
        .with(user, range: kind_of(Range))
        .and_return({ articles: 8, comments: 7 })
      allow(helper).to receive(:overall_rank_for).with(user).and_return(3)
      allow(helper).to receive(:monthly_rank_for).with(user, Date.new(2025, 3, 1)).and_return(7)

      result = helper.reputation_breakdown(user)

      expect(result[:overall][:total]).to eq(50)
      expect(result[:overall][:formatted_total]).to eq("50")
      expect(result[:overall][:articles][:formatted_percentage]).to eq("80%")
      expect(result[:overall][:rank]).to eq(3)

      expect(result[:monthly][:total]).to eq(15)
      expect(result[:monthly][:formatted_total]).to eq("15")
      expect(result[:monthly][:period_param]).to eq("2025-03")
      expect(result[:monthly][:rank]).to eq(7)

      expect(result[:points_per_article_like]).to eq(Users::ReputationBreakdown::ARTICLE_WEIGHT)
      expect(result[:points_per_comment_like]).to eq(Users::ReputationBreakdown::COMMENT_WEIGHT)
    end

    it "handles zero totals without errors" do
      allow(Users::ReputationBreakdown).to receive(:call).with(user).and_return({ articles: 0, comments: 0 })
      allow(Users::ReputationBreakdown).to receive(:call)
        .with(user, range: kind_of(Range))
        .and_return({ articles: 0, comments: 0 })
      allow(helper).to receive(:overall_rank_for).and_return(nil)
      allow(helper).to receive(:monthly_rank_for).and_return(nil)

      result = helper.reputation_breakdown(user)

      expect(result[:overall][:total]).to eq(0)
      expect(result[:overall][:articles][:formatted_percentage]).to eq("0%")
      expect(result[:monthly][:comments][:formatted_percentage]).to eq("0%")
    end
  end
end

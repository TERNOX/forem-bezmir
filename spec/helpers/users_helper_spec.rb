require "rails_helper"

RSpec.describe UsersHelper, type: :helper do
  describe "#reputation_breakdown" do
    let(:user) { build_stubbed(:user) }

    it "returns formatted totals and percentages" do
      allow(Users::ReputationBreakdown).to receive(:call).with(user).and_return({ articles: 40, comments: 10 })

      result = helper.reputation_breakdown(user)

      expect(result[:total]).to eq(50)
      expect(result[:formatted_total]).to eq("50")
      expect(result[:articles][:formatted_points]).to eq("40")
      expect(result[:articles][:formatted_percentage]).to eq("80%")
      expect(result[:comments][:formatted_percentage]).to eq("20%")
    end

    it "handles zero totals without errors" do
      allow(Users::ReputationBreakdown).to receive(:call).with(user).and_return({ articles: 0, comments: 0 })

      result = helper.reputation_breakdown(user)

      expect(result[:total]).to eq(0)
      expect(result[:articles][:formatted_percentage]).to eq("0%")
      expect(result[:comments][:formatted_percentage]).to eq("0%")
    end
  end
end

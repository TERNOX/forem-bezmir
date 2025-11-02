require "rails_helper"

RSpec.describe Users::ReputationBreakdown do
  include ActiveSupport::Testing::TimeHelpers

  describe ".call" do
    let(:user) { create(:user) }

    it "returns zero scores when the user has no reactions" do
      expect(described_class.call(user)).to eq(articles: 0, comments: 0)
    end

    it "calculates points from post and comment likes" do
      article = create(:article, user: user)
      comment = create(:comment, user: user)

      create_list(:reaction, 3, reactable: article, category: "like", status: "valid")
      create(:reaction, reactable: article, category: "like", status: "confirmed")
      create_list(:reaction, 2, reactable: comment, category: "like", status: "valid")

      result = described_class.call(user)

      expect(result).to eq(articles: 8, comments: 2)
    end

    it "ignores reactions with different status or category" do
      article = create(:article, user: user)
      comment = create(:comment, user: user)

      create(:reaction, reactable: article, category: "vomit", status: "valid")
      create(:reaction, reactable: article, category: "like", status: "invalid")
      create(:reaction, reactable: comment, category: "like", status: "archived")

      expect(described_class.call(user)).to eq(articles: 0, comments: 0)
    end

    it "limits the calculation to the provided range" do
      travel_to(Time.zone.local(2025, 3, 10, 10)) do
        article = create(:article, user: user)
        recent_comment = create(:comment, user: user)

        create(:reaction, reactable: article, category: "like", status: "valid", created_at: 3.months.ago)
        create(:reaction, reactable: article, category: "like", status: "valid", created_at: Time.zone.now)
        create(:reaction, reactable: recent_comment, category: "like", status: "valid", created_at: Time.zone.now)

        range = Time.zone.today.beginning_of_month.beginning_of_day..Time.zone.today.end_of_month.end_of_day

        result = described_class.call(user, range: range)

        expect(result).to eq(articles: 2, comments: 1)
      end
    end
  end
end

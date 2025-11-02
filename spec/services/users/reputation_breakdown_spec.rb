require "rails_helper"

RSpec.describe Users::ReputationBreakdown do
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
  end
end

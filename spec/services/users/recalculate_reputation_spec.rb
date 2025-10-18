require "rails_helper"

RSpec.describe Users::RecalculateReputation do
  describe ".call" do
    let!(:author) { create(:user, reputation_score: 10) }
    let!(:other_user) { create(:user, reputation_score: 5) }
    let!(:article) { create(:article, user: author) }
    let!(:comment) { create(:comment, user: author, commentable: article) }

    before do
      create(:reaction, reactable: comment, user: other_user, category: "like")
      create(:reaction, reactable: article, user: other_user, category: "like")
      author.update!(reputation_score: 7)
      other_user.update!(reputation_score: 9)
    end

    it "resets all reputation scores based on comment likes" do
      described_class.call

      expect(author.reload.reputation_score).to eq(1)
      expect(other_user.reload.reputation_score).to eq(0)
    end

    it "returns summary information" do
      result = described_class.call

      expect(result).to eq(users: 1, likes: 1)
    end
  end
end

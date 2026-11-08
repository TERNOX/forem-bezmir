require "rails_helper"

RSpec.describe VotingCategory do
  describe "#points_for" do
    it "gives 1 point per pick when not ranked" do
      category = build(:voting_category, max_choices: 3, ranked: false)
      expect([1, 2, 3].map { |rank| category.points_for(rank) }).to eq([1, 1, 1])
    end

    it "gives max_choices..1 points by place when ranked" do
      category = build(:voting_category, max_choices: 3, ranked: true)
      expect([1, 2, 3].map { |rank| category.points_for(rank) }).to eq([3, 2, 1])
    end
  end

  it "appends new categories after existing ones" do
    voting = create(:voting)
    first = create(:voting_category, voting: voting)
    second = create(:voting_category, voting: voting)
    expect(second.position).to eq(first.position + 1)
    expect(voting.categories.reload).to eq([first, second])
  end

  it "limits max_choices" do
    expect(build(:voting_category, max_choices: 0)).not_to be_valid
    expect(build(:voting_category, max_choices: VotingCategory::MAX_CHOICES_LIMIT + 1)).not_to be_valid
  end
end

RSpec.describe VotingNominee do
  it "needs a game or a title" do
    expect(build(:voting_nominee, game: nil, title: nil)).not_to be_valid
    expect(build(:voting_nominee, game: nil, title: "Інше")).to be_valid
  end

  it "rejects the same game twice in one nomination" do
    nominee = create(:voting_nominee)
    duplicate = build(:voting_nominee, category: nominee.category, game: nominee.game)
    expect(duplicate).not_to be_valid
  end

  it "only accepts http(s) links" do
    expect(build(:voting_nominee, link_url: "javascript:alert(1)")).not_to be_valid
    expect(build(:voting_nominee, link_url: "https://kutok.io/s/8363")).to be_valid
  end

  it "uses the game title and picture unless overridden" do
    game = build(:game, title: "Hades II", igdb_cover_image_id: "co1", igdb_artwork_image_id: "ar1")
    nominee = build(:voting_nominee, game: game)
    expect(nominee.display_title).to eq("Hades II")
    expect(nominee.image_url_for("cover")).to include("t_cover_big_2x/co1.jpg")
    expect(nominee.image_url_for("artwork")).to include("t_screenshot_huge/ar1.jpg")
  end
end

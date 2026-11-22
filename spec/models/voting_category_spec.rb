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

    it "uses the custom points per place when set" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 1])
      expect([1, 2, 3].map { |rank| category.points_for(rank) }).to eq([5, 3, 1])
    end

    it "gives a missing or out-of-range rank the lowest place's points" do
      linear = build(:voting_category, max_choices: 3, ranked: true)
      custom = build(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 2])

      expect([nil, 0, 4].map { |rank| linear.points_for(rank) }).to eq([1, 1, 1])
      expect([nil, 0, 4].map { |rank| custom.points_for(rank) }).to eq([2, 2, 2])
    end
  end

  describe "#rank_points_list" do
    it "falls back to the linear scale for a ranked category" do
      expect(build(:voting_category, max_choices: 4, ranked: true).rank_points_list).to eq([4, 3, 2, 1])
    end

    it "returns the custom list when set" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 1])
      expect(category.rank_points_list).to eq([5, 3, 1])
    end

    it "is empty for an unranked category" do
      expect(build(:voting_category, max_choices: 3).rank_points_list).to eq([])
    end
  end

  describe "rank_points validation" do
    def ranked(points)
      build(:voting_category, max_choices: 3, ranked: true, rank_points: points)
    end

    it "accepts an empty list or a non-increasing list with one value per place" do
      expect(ranked([])).to be_valid
      expect(ranked([5, 3, 1])).to be_valid
      expect(ranked([2, 2, 1])).to be_valid
    end

    it "needs exactly max_choices values" do
      expect(ranked([5, 3])).not_to be_valid
      expect(ranked([5, 3, 2, 1])).not_to be_valid
    end

    it "needs whole numbers of at least 1" do
      category = ranked([5, 3, 0])
      expect(category).not_to be_valid
      expect(category.errors[:rank_points]).to be_present
      expect(ranked([5, 3, VotingCategory::RANK_POINTS_MAX + 1])).not_to be_valid
    end

    it "rejects a lower place earning more than a higher one" do
      expect(ranked([1, 3, 5])).not_to be_valid
      expect(ranked([5, 1, 3])).not_to be_valid
    end

    it "stores no points for an unranked category" do
      category = create(:voting_category, max_choices: 3, ranked: false, rank_points: [5, 3, 1])
      expect(category.reload.rank_points).to eq([])
    end
  end

  describe "#rank_points_text" do
    it "parses comma-separated points, spaces allowed" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points_text: " 5, 3,1 ")
      expect(category.rank_points).to eq([5, 3, 1])
      expect(category).to be_valid
    end

    it "treats blank as the linear scale" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 1])
      category.rank_points_text = ""
      expect(category.rank_points).to eq([])
      expect(category.rank_points_list).to eq([3, 2, 1])
    end

    it "prints the stored list" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 1])
      expect(category.rank_points_text).to eq("5,3,1")
    end

    it "reports non-numbers as an error instead of turning them into 0" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 1])
      category.rank_points_text = "5,three,1"

      expect(category).not_to be_valid
      expect(category.errors[:rank_points]).to include(I18n.t("models.voting_category.rank_points_format"))
      expect(category.rank_points).to eq([5, 3, 1])
      expect(category.rank_points_text).to eq("5,three,1")
    end

    it "rejects negative numbers and empty entries" do
      expect(build(:voting_category, max_choices: 3, ranked: true, rank_points_text: "5,-3,1")).not_to be_valid
      expect(build(:voting_category, max_choices: 3, ranked: true, rank_points_text: "5,,1")).not_to be_valid
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

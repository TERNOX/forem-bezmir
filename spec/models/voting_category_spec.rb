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

    it "treats blank on an existing nomination as the linear scale" do
      category = create(:voting_category, max_choices: 3, ranked: true, rank_points: [5, 3, 1])
      category.rank_points_text = ""
      category.save!
      expect(category.reload.rank_points).to eq([])
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

  describe "default points for a three-place ranked nomination" do
    it "gives a new one 5-3-1 when the points are left blank" do
      category = create(:voting_category, max_choices: 3, ranked: true, rank_points_text: "")
      expect(category.reload.rank_points).to eq(VotingCategory::DEFAULT_THREE_PLACE_POINTS)
      expect(category.rank_points).to eq([5, 3, 1])
      expect(category.rank_points_list).to eq([5, 3, 1])
      expect(create(:voting_category, max_choices: 3, ranked: true).reload.rank_points).to eq([5, 3, 1])
    end

    it "keeps the points typed for a new one, linear included" do
      category = create(:voting_category, max_choices: 3, ranked: true, rank_points_text: "3,2,1")
      expect(category.reload.rank_points).to eq([3, 2, 1])
    end

    it "keeps the linear fallback for other numbers of places" do
      two = create(:voting_category, max_choices: 2, ranked: true)
      four = create(:voting_category, max_choices: 4, ranked: true)

      expect(two.reload).to have_attributes(rank_points: [], rank_points_list: [2, 1])
      expect(four.reload).to have_attributes(rank_points: [], rank_points_list: [4, 3, 2, 1])
    end

    it "stores no points for an unranked one" do
      category = create(:voting_category, max_choices: 3, ranked: false)
      expect(category.reload).to have_attributes(rank_points: [], rank_points_list: [])
    end

    it "leaves a legacy one with empty points at 3-2-1 when other attributes change" do
      category = create(:voting_category, max_choices: 3, ranked: true)
      category.update_column(:rank_points, [])

      expect(category.reload.update(title: "Гра року", description: "Нове", rank_points_text: "")).to be(true)
      expect(category.reload).to have_attributes(title: "Гра року", rank_points: [], rank_points_list: [3, 2, 1])
      expect(category.update(ranked: true, max_choices: "3")).to be(true) # same values, as the form sends them
      expect(category.reload.rank_points).to eq([])
    end

    it "gives 5-3-1 to an unvoted one that becomes ranked or gets three places" do
      unranked = create(:voting_category, max_choices: 3)
      expect(unranked.update(ranked: true)).to be(true)
      expect(unranked.reload.rank_points).to eq([5, 3, 1])

      two_places = create(:voting_category, max_choices: 2, ranked: true)
      expect(two_places.update(max_choices: 3)).to be(true)
      expect(two_places.reload.rank_points).to eq([5, 3, 1])
    end

    it "still reports invalid typed points instead of defaulting them" do
      category = build(:voting_category, max_choices: 3, ranked: true, rank_points_text: "a,b")

      expect(category).not_to be_valid
      expect(category.errors[:rank_points]).to include(I18n.t("models.voting_category.rank_points_format"))
      expect(category.rank_points).to eq([])
      expect(category.save).to be(false)
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

  describe "structure lock once people have voted" do
    let(:voting) { create(:voting) }
    let(:plain) { create(:voting_category, voting: voting, max_choices: 3) }
    let(:ranked) { create(:voting_category, voting: voting, max_choices: 3, ranked: true, rank_points: [5, 3, 1]) }

    def vote_in(category)
      nominee = create(:voting_nominee, category: category)
      Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                    selections: { category.id.to_s => { "nominee_ids" => [nominee.id] } }).tap do |r|
        raise r.errors.inspect unless r.success?
      end
    end

    it "allows any structural change while nobody has voted" do
      create(:voting_nominee, category: ranked)

      expect(ranked.voted?).to be(false)
      expect(ranked.update(max_choices: 2, rank_points: [3, 1])).to be(true)
      expect(ranked.update(ranked: false)).to be(true)
      expect(plain.update(max_choices: 1, ranked: true)).to be(true)
    end

    it "does not let ranked be turned on" do
      vote_in(plain)

      expect(plain.voted?).to be(true)
      expect(plain.update(ranked: true)).to be(false)
      expect(plain.errors[:ranked]).to include(I18n.t("models.voting_category.ranked_locked"))
      expect(plain.reload.ranked).to be(false)
    end

    it "does not let ranked be turned off" do
      vote_in(ranked)

      expect(ranked.update(ranked: false)).to be(false)
      expect(ranked.errors[:ranked]).to include(I18n.t("models.voting_category.ranked_locked"))
      expect(ranked.reload).to have_attributes(ranked: true, rank_points: [5, 3, 1])
    end

    it "does not let max_choices be lowered" do
      vote_in(plain)

      expect(plain.update(max_choices: 2)).to be(false)
      expect(plain.errors[:max_choices]).to include(I18n.t("models.voting_category.max_choices_lowered", count: 3))
      expect(plain.reload.max_choices).to eq(3)
    end

    it "lets max_choices go up in an unranked nomination" do
      vote_in(plain)

      expect(plain.update(max_choices: 5)).to be(true)
      expect(plain.reload.max_choices).to eq(5)
    end

    it "does not let max_choices change at all in a ranked nomination" do
      vote_in(ranked)

      expect(ranked.update(max_choices: 4, rank_points: [5, 3, 2, 1])).to be(false)
      expect(ranked.errors[:max_choices]).to include(I18n.t("models.voting_category.max_choices_locked_ranked"))
      expect(ranked.update(max_choices: 2, rank_points: [5, 3])).to be(false)
      expect(ranked.reload.max_choices).to eq(3)
    end

    it "keeps everything else editable" do
      vote_in(ranked)

      expect(ranked.update(title: "Гра року", description: "Нове", required: true, allow_other: true,
                           card_style: "artwork", position: 7, rank_points: [10, 5, 1],
                           ranked: true, max_choices: "3")).to be(true)
      expect(ranked.reload).to have_attributes(title: "Гра року", required: true, allow_other: true,
                                               card_style: "artwork", position: 7, rank_points: [10, 5, 1])
    end
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

  it "locks its game once people have voted for it" do
    nominee = create(:voting_nominee)
    other_game = create(:game)
    expect(nominee.update(game: other_game)).to be(true) # no votes yet

    voting = nominee.category.voting
    Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                  selections: { nominee.voting_category_id.to_s => { "nominee_ids" => [nominee.id] } })

    expect(nominee.voted?).to be(true)
    expect(nominee.update(game: create(:game))).to be(false)
    expect(nominee.errors[:base]).to include(I18n.t("models.voting_nominee.game_locked"))
    expect(nominee.reload.game).to eq(other_game)
    expect(nominee.update(title: "Override", subtitle: "DLC", link_url: "https://kutok.io")).to be(true)
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

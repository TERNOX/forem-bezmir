require "rails_helper"

RSpec.describe Voting do
  describe "validations" do
    it "derives the slug from the title when it is blank" do
      voting = described_class.create!(title: "Game of the Year", slug: "")
      expect(voting.slug).to eq("game-of-the-year")
    end

    it "downcases and validates the slug format" do
      expect(build(:voting, slug: "Gra-Roku")).to be_valid
      expect(build(:voting, slug: "gra roku")).not_to be_valid
    end

    it "requires closes_at to be after opens_at" do
      voting = build(:voting, opens_at: 1.day.from_now, closes_at: 1.day.ago)
      expect(voting).not_to be_valid
      expect(voting.errors[:closes_at]).to be_present
    end

    it "rejects a top-level slug taken by a member" do
      create(:user, username: "gra-roku")
      expect(build(:voting, slug: "gra-roku", top_level_path: true)).not_to be_valid
      expect(build(:voting, slug: "gra-roku", top_level_path: false)).to be_valid
    end

    it "rejects a top-level slug that is a reserved word" do
      expect(build(:voting, slug: "settings", top_level_path: true)).not_to be_valid
    end
  end

  describe "#status and #open?" do
    it "is draft when unpublished" do
      voting = build(:voting, published: false)
      expect(voting.status).to eq(:draft)
      expect(voting).not_to be_open
    end

    it "is upcoming before opens_at" do
      expect(build(:voting, opens_at: 1.hour.from_now).status).to eq(:upcoming)
    end

    it "is closed after closes_at" do
      expect(build(:voting, opens_at: 2.days.ago, closes_at: 1.hour.ago).status).to eq(:closed)
    end

    it "is open in between, also without dates" do
      expect(build(:voting).status).to eq(:open)
      expect(build(:voting, opens_at: nil, closes_at: nil)).to be_open
    end
  end

  describe "#path" do
    it "uses /vote/ unless the voting is top-level" do
      expect(build(:voting, slug: "goty").path).to eq("/vote/goty")
      expect(build(:voting, slug: "goty", top_level_path: true).path).to eq("/goty")
    end
  end

  it "makes a top-level slug unavailable to new members (CrossModelSlug)" do
    create(:voting, slug: "goty-2026", top_level_path: true)
    create(:voting, slug: "hidden-goty", top_level_path: false)

    expect(CrossModelSlug.exists?("goty-2026")).to be(true)
    expect(CrossModelSlug.exists?("hidden-goty")).to be(false)
  end
end

require "rails_helper"

RSpec.describe SocialPostSnapshot do
  subject(:snapshot) { build(:social_post_snapshot) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires a known platform" do
      snapshot.platform = "myspace"
      expect(snapshot).not_to be_valid
    end

    it "enforces uniqueness of source_id per platform" do
      create(:social_post_snapshot, platform: "bluesky", source_id: "dup")
      duplicate = build(:social_post_snapshot, platform: "bluesky", source_id: "dup")
      expect(duplicate).not_to be_valid
    end

    it "allows the same source_id on a different platform" do
      create(:social_post_snapshot, platform: "bluesky", source_id: "same")
      other = build(:social_post_snapshot, :twitter, source_id: "same")
      expect(other).to be_valid
    end
  end

  describe "#photos" do
    it "returns only photo media entries with a url" do
      snapshot.media = [
        { "type" => "photo", "url" => "https://cdn/a.jpg" },
        { "type" => "photo", "url" => "" },
        { "type" => "video", "url" => "https://cdn/v.mp4" },
      ]
      expect(snapshot.photos).to eq([{ "type" => "photo", "url" => "https://cdn/a.jpg" }])
    end
  end

  describe "#renderable?" do
    it "is true with text" do
      expect(build(:social_post_snapshot, text_html: "hi", text_content: nil, media: [])).to be_renderable
    end

    it "is true with photos and no text" do
      expect(build(:social_post_snapshot, :with_photo, text_html: nil, text_content: nil)).to be_renderable
    end

    it "is false with neither text nor photos" do
      expect(build(:social_post_snapshot, text_html: nil, text_content: nil, media: [])).not_to be_renderable
    end
  end

  describe "#archived_fallback?" do
    it "is true only when deleted AND renderable" do
      expect(build(:social_post_snapshot, :archived, text_html: "hi")).to be_archived_fallback
      expect(build(:social_post_snapshot, source_status: :live, text_html: "hi")).not_to be_archived_fallback
      expect(build(:social_post_snapshot, :archived, text_html: nil, text_content: nil,
                                                     media: [])).not_to be_archived_fallback
    end
  end

  describe "#stale_for_liveness?" do
    it "is true when never checked or checked long ago" do
      expect(build(:social_post_snapshot, checked_at: nil)).to be_stale_for_liveness
      expect(build(:social_post_snapshot, checked_at: 1.day.ago)).to be_stale_for_liveness
    end

    it "is false when recently checked" do
      expect(build(:social_post_snapshot, checked_at: 1.minute.ago)).not_to be_stale_for_liveness
    end
  end
end

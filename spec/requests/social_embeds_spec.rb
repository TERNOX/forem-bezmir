require "rails_helper"

RSpec.describe "SocialEmbeds" do
  describe "GET /social_embeds/status" do
    def get_status(platform:, source_id:)
      get "/social_embeds/status", params: { platform: platform, source_id: source_id }
    end

    it "returns unknown and makes no external call when no snapshot exists" do
      allow(SocialEmbeds::BlueskyClient).to receive(:fetch)

      get_status(platform: "bluesky", source_id: "missing")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("status" => "unknown", "archived" => false)
      expect(SocialEmbeds::BlueskyClient).not_to have_received(:fetch)
    end

    it "does not live-check a snapshot with no captured content" do
      snapshot = create(:social_post_snapshot, text_html: nil, text_content: nil, media: [], source_status: :unknown)
      allow(SocialEmbeds::BlueskyClient).to receive(:fetch)

      get_status(platform: snapshot.platform, source_id: snapshot.source_id)

      expect(response.parsed_body).to eq("status" => "unknown", "archived" => false)
      expect(SocialEmbeds::BlueskyClient).not_to have_received(:fetch)
    end

    it "reports live while the source is still present" do
      snapshot = create(:social_post_snapshot, text_html: "hi", source_status: :live)
      allow(SocialEmbeds::BlueskyClient).to receive(:fetch)
        .and_return(SocialEmbeds::PostData.new(status: :ok, text_content: "hi", photos: [], raw: {}))

      get_status(platform: snapshot.platform, source_id: snapshot.source_id)

      expect(response.parsed_body).to eq("status" => "live", "archived" => false)
    end

    it "detects a freshly deleted source, reports archived and preserves content" do
      snapshot = create(:social_post_snapshot, text_html: "kept", source_status: :live)
      allow(SocialEmbeds::BlueskyClient).to receive(:fetch).and_return(SocialEmbeds::PostData.deleted)

      get_status(platform: snapshot.platform, source_id: snapshot.source_id)

      expect(response.parsed_body).to eq("status" => "deleted", "archived" => true)
      expect(snapshot.reload).to be_deleted
      expect(snapshot.text_html).to eq("kept")
    end

    it "serves an already-deleted snapshot without hitting the platform again" do
      snapshot = create(:social_post_snapshot, :archived, text_html: "kept")
      allow(SocialEmbeds::BlueskyClient).to receive(:fetch)

      get_status(platform: snapshot.platform, source_id: snapshot.source_id)

      expect(response.parsed_body).to eq("status" => "deleted", "archived" => true)
      expect(SocialEmbeds::BlueskyClient).not_to have_received(:fetch)
    end
  end
end

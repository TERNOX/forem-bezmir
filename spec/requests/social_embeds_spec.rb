require "rails_helper"

RSpec.describe "SocialEmbeds" do
  describe "GET /social_embeds/status" do
    it "returns unknown when no snapshot exists" do
      get "/social_embeds/status", params: { platform: "bluesky", source_id: "missing" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("status" => "unknown", "archived" => false)
    end

    it "reports a live snapshot" do
      snapshot = create(:social_post_snapshot, source_status: :live, checked_at: 1.minute.ago)

      get "/social_embeds/status", params: { platform: snapshot.platform, source_id: snapshot.source_id }

      expect(response.parsed_body).to eq("status" => "live", "archived" => false)
    end

    it "reports an archived (deleted + renderable) snapshot" do
      snapshot = create(:social_post_snapshot, :archived, text_html: "kept", checked_at: 1.minute.ago)

      get "/social_embeds/status", params: { platform: snapshot.platform, source_id: snapshot.source_id }

      expect(response.parsed_body).to eq("status" => "deleted", "archived" => true)
    end

    it "enqueues a background refresh when the snapshot is stale" do
      snapshot = create(:social_post_snapshot, source_status: :live, checked_at: 1.day.ago)

      expect do
        get "/social_embeds/status", params: { platform: snapshot.platform, source_id: snapshot.source_id }
      end.to change(SocialEmbeds::SnapshotWorker.jobs, :size).by(1)
    end
  end
end

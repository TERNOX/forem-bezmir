require "rails_helper"

RSpec.describe SocialEmbeds::Snapshotter do
  let(:source_id) { "abc123" }
  let(:args) do
    {
      platform: "bluesky",
      source_id: source_id,
      source_url: "https://bsky.app/profile/alice/post/#{source_id}",
      at_uri: "at://did:plc:x/app.bsky.feed.post/#{source_id}"
    }
  end

  def stub_client(post_data)
    allow(SocialEmbeds::BlueskyClient).to receive(:fetch).and_return(post_data)
  end

  def ok_data(**overrides)
    SocialEmbeds::PostData.new(
      status: :ok, author_handle: "alice", author_name: "Alice", author_avatar_url: nil,
      text_content: "Hello world", text_html: nil, posted_at: Time.current, photos: [], raw: {}, **overrides
    )
  end

  describe ".call" do
    it "captures a new snapshot and marks it live" do
      stub_client(ok_data)

      snapshot = described_class.call(**args)

      expect(snapshot).to be_persisted
      expect(snapshot).to be_live
      expect(snapshot.author_handle).to eq("alice")
      expect(snapshot.text_html).to include("Hello world")
    end

    it "does not re-fetch a freshly captured snapshot" do
      stub_client(ok_data)
      described_class.call(**args)

      described_class.call(**args)

      expect(SocialEmbeds::BlueskyClient).to have_received(:fetch).once
    end

    it "converts plain text to safe linkified html" do
      stub_client(ok_data(text_content: "see http://example.com now"))

      snapshot = described_class.call(**args)

      expect(snapshot.text_html).to include('<a href="http://example.com"')
    end
  end

  describe ".refresh (source deleted later)" do
    it "flips to deleted but preserves previously captured content" do
      stub_client(ok_data)
      snapshot = described_class.call(**args)

      stub_client(SocialEmbeds::PostData.deleted)
      described_class.refresh(snapshot)

      expect(snapshot.reload).to be_deleted
      expect(snapshot.text_html).to include("Hello world")
      expect(snapshot).to be_archived_fallback
    end

    it "does not downgrade a good snapshot on a transient failure" do
      stub_client(ok_data)
      snapshot = described_class.call(**args)

      stub_client(SocialEmbeds::PostData.unavailable)
      described_class.refresh(snapshot)

      expect(snapshot.reload).to be_live
      expect(snapshot.text_html).to include("Hello world")
    end
  end

  describe "photo re-hosting" do
    it "stores rehosted photo urls returned by the uploader" do
      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url).and_return("https://ourhost/uploads/social_embeds/x.jpg")
      stub_client(ok_data(photos: [{ "url" => "https://cdn.bsky/a.jpg", "alt" => "cat" }]))

      snapshot = described_class.call(**args)

      expect(snapshot.photos.first).to include(
        "url" => "https://ourhost/uploads/social_embeds/x.jpg",
        "source_url" => "https://cdn.bsky/a.jpg",
        "alt" => "cat",
      )
    end

    it "never erases already-archived photos when a later re-host fails" do
      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url).and_return("https://ourhost/photo.jpg")
      stub_client(ok_data(photos: [{ "url" => "https://cdn/a.jpg", "alt" => "" }]))
      snapshot = described_class.call(**args)

      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url).and_return(nil)
      stub_client(ok_data(photos: [{ "url" => "https://cdn/CHANGED.jpg", "alt" => "" }]))
      described_class.refresh(snapshot)

      expect(snapshot.reload.photos.pluck("url")).to eq(["https://ourhost/photo.jpg"])
    end

    it "retries a photo that failed on the initial capture" do
      photos = [{ "url" => "https://cdn/a.jpg", "alt" => "" }, { "url" => "https://cdn/b.jpg", "alt" => "" }]
      # first capture: a stores, b transiently fails
      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url) { |_instance, url| url == "https://cdn/a.jpg" ? "https://ourhost/a.jpg" : nil }
      stub_client(ok_data(photos: photos))
      snapshot = described_class.call(**args)
      expect(snapshot.photos.pluck("source_url")).to eq(["https://cdn/a.jpg"])

      # refresh: b now succeeds and is appended, a is kept
      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url).and_return("https://ourhost/b.jpg")
      stub_client(ok_data(photos: photos))
      described_class.refresh(snapshot)

      expect(snapshot.reload.photos.pluck("source_url"))
        .to contain_exactly("https://cdn/a.jpg", "https://cdn/b.jpg")
    end
  end

  describe "avatar re-hosting" do
    it "re-hosts the author avatar onto our storage" do
      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url).and_return("https://ourhost/av.jpg")
      stub_client(ok_data(author_avatar_url: "https://cdn/orig-av.jpg"))

      snapshot = described_class.call(**args)

      expect(snapshot.author_avatar_url).to eq("https://ourhost/av.jpg")
    end

    it "keeps the stored avatar on refresh instead of re-downloading" do
      allow_any_instance_of(SocialEmbedImageUploader) # rubocop:disable RSpec/AnyInstance
        .to receive(:upload_from_url).and_return("https://ourhost/av.jpg")
      stub_client(ok_data(author_avatar_url: "https://cdn/orig-av.jpg"))
      snapshot = described_class.call(**args)

      stub_client(ok_data(author_avatar_url: "https://cdn/CHANGED-av.jpg"))
      described_class.refresh(snapshot)

      expect(snapshot.reload.author_avatar_url).to eq("https://ourhost/av.jpg")
    end
  end
end

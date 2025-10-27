require "rails_helper"

RSpec.describe YoutubeUrl do
  describe ".normalize_embed_src" do
    it "returns nocookie embed url for youtube embeds" do
      url = "https://www.youtube.com/embed/abc123?t=1m1s"

      expect(described_class.normalize_embed_src(url)).to eq("https://www.youtube-nocookie.com/embed/abc123?start=61")
    end

    it "returns nocookie embed url for watch links" do
      url = "https://www.youtube.com/watch?v=abc123&t=90"

      expect(described_class.normalize_embed_src(url)).to eq("https://www.youtube-nocookie.com/embed/abc123?start=90")
    end

    it "returns original url for non youtube urls" do
      url = "https://example.com/video"

      expect(described_class.normalize_embed_src(url)).to eq(url)
    end
  end

  describe ".normalize_embed_html" do
    it "rewrites iframe src attributes to nocookie embeds" do
      html = <<~HTML
        <div>
          <iframe src="https://www.youtube.com/embed/abc123"></iframe>
          <iframe src="https://www.youtube.com/embed/xyz789?t=1m"></iframe>
        </div>
      HTML

      result = described_class.normalize_embed_html(html)

      expect(result).to include("https://www.youtube-nocookie.com/embed/abc123")
      expect(result).to include("https://www.youtube-nocookie.com/embed/xyz789?start=60")
    end

    it "leaves non youtube iframes intact" do
      html = "<iframe src=\"https://player.vimeo.com/video/123\"></iframe>"

      expect(described_class.normalize_embed_html(html)).to eq(html)
    end
  end
end

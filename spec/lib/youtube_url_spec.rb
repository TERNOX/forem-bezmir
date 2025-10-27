require "rails_helper"

RSpec.describe YoutubeUrl do
  describe ".normalize_embed_src" do
    it "returns nocookie embed url for youtube embeds" do
      url = "https://www.youtube.com/embed/abc123?t=1m1s"
      normalized = described_class.normalize_embed_src(url)

      expect(normalized).to start_with("https://www.youtube-nocookie.com/embed/abc123")
      query_params = URI.parse(normalized).query.split("&")
      expect(query_params).to include("start=61")
      expect(query_params).to include(a_string_starting_with("origin="))
      expect(query_params).to include(a_string_starting_with("widget_referrer="))
    end

    it "returns nocookie embed url for watch links" do
      url = "https://www.youtube.com/watch?v=abc123&t=90"
      normalized = described_class.normalize_embed_src(url)

      expect(normalized).to start_with("https://www.youtube-nocookie.com/embed/abc123")
      query_params = URI.parse(normalized).query.split("&")
      expect(query_params).to include("start=90")
      expect(query_params).to include(a_string_starting_with("origin="))
      expect(query_params).to include(a_string_starting_with("widget_referrer="))
    end

    it "returns original url for non youtube urls" do
      url = "https://example.com/video"

      expect(described_class.normalize_embed_src(url)).to eq(url)
    end

    it "preserves additional query parameters" do
      url = "https://youtu.be/abc123?si=FPFWKE9g0PhQjAUE"
      normalized = described_class.normalize_embed_src(url)

      expect(normalized).to start_with("https://www.youtube-nocookie.com/embed/abc123")
      expect(URI.parse(normalized).query.split("&")).to include("si=FPFWKE9g0PhQjAUE")
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
      expect(result).to match(/https:\/\/www\.youtube-nocookie\.com\/embed\/xyz789\?[^\"]*start=60/)
    end

    it "leaves non youtube iframes intact" do
      html = "<iframe src=\"https://player.vimeo.com/video/123\"></iframe>"

      expect(described_class.normalize_embed_html(html)).to eq(html)
    end
  end
end

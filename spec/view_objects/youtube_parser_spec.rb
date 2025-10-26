require "rails_helper"

RSpec.describe YoutubeParser do
  describe "#video_id" do
    it "extracts the id from a watch URL" do
      parser = described_class.new("https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share")

      expect(parser.video_id).to eq("dQw4w9WgXcQ")
    end

    it "returns nil for a non-YouTube URL" do
      parser = described_class.new("https://example.com/video/123")

      expect(parser.video_id).to be_nil
    end
  end

  describe "#thumbnail_url" do
    it "builds the thumbnail URL for a youtu.be link" do
      parser = described_class.new("https://youtu.be/dQw4w9WgXcQ?t=43")

      expect(parser.thumbnail_url).to eq("https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
    end
  end

  describe "#call" do
    it "returns the embed URL when possible" do
      parser = described_class.new("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

      expect(parser.call).to eq("https://www.youtube.com/embed/dQw4w9WgXcQ")
    end
  end
end

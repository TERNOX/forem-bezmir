require "rails_helper"

describe YoutubeParser do
  describe "#call" do
    let(:video_id) { "dQw4w9WgXcQ" }

    it "returns the standard embed url" do
      parser = described_class.new("https://www.youtube.com/watch?v=#{video_id}")
      result = parser.call

      expect(result).to start_with("https://www.youtube.com/embed/#{video_id}")
      query = URI.parse(result).query.split("&")
      expect(query).to include(a_string_starting_with("origin="))
      expect(query).to include(a_string_starting_with("widget_referrer="))
      expect(query).to include("autoplay=1")
      expect(query).to include("rel=0")
      expect(query).to include("modestbranding=1")
      expect(query).to include("playsinline=1")
    end

    it "preserves the start parameter" do
      parser = described_class.new("https://youtu.be/#{video_id}?t=1m1s")
      result = parser.call

      expect(result).to start_with("https://www.youtube.com/embed/#{video_id}")
      query = URI.parse(result).query.split("&")
      expect(query).to include("start=61")
    end

    it "handles nocookie embed urls" do
      parser = described_class.new("https://www.youtube-nocookie.com/embed/#{video_id}?start=30")
      result = parser.call

      expect(result).to start_with("https://www.youtube.com/embed/#{video_id}")
      query = URI.parse(result).query.split("&")
      expect(query).to include("start=30")
      expect(query).to include("autoplay=1")
    end
  end
end

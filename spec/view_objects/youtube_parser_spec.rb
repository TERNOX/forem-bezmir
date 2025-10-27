require "rails_helper"

describe YoutubeParser do
  describe "#call" do
    let(:video_id) { "dQw4w9WgXcQ" }

    it "returns the cookie-less embed url" do
      parser = described_class.new("https://www.youtube.com/watch?v=#{video_id}")

      expect(parser.call).to eq("https://www.youtube-nocookie.com/embed/#{video_id}")
    end

    it "preserves the start parameter" do
      parser = described_class.new("https://youtu.be/#{video_id}?t=1m1s")

      expect(parser.call).to eq("https://www.youtube-nocookie.com/embed/#{video_id}?start=61")
    end

    it "handles nocookie embed urls" do
      parser = described_class.new("https://www.youtube-nocookie.com/embed/#{video_id}?start=30")

      expect(parser.call).to eq("https://www.youtube-nocookie.com/embed/#{video_id}?start=30")
    end
  end
end

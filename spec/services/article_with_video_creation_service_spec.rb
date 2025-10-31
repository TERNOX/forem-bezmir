require "rails_helper"

RSpec.describe ArticleWithVideoCreationService, type: :service do
  let(:link) { "https://s3.amazonaws.com/example-video-input/video-upload__2d7dc29e39a40c7059572bca75bb646b" }
  let(:cdn_base_url) { "https://videos.example.com" }

  before do
    allow(Settings::General).to receive(:video_cdn_base_url).and_return(cdn_base_url)
  end

  describe "#create!" do
    it "creates a correct article" do
      Timecop.travel(3.weeks.ago)
      user = create(:user)
      user.setting.update(editor_version: "v1")
      Timecop.return
      test = build_stubbed(:article, user: user, video: link).attributes.symbolize_keys
      article = described_class.new(test, user).create!
      expect(article.body_markdown.inspect).to include("description: \\ntags: \\n")
      expect(article.video_state).to eq("PROGRESSING")
      expect(article.video_code).to eq("video-upload__2d7dc29e39a40c7059572bca75bb646b")
      expect(article.video_source_url).to eq(
        "#{cdn_base_url}/video-upload__2d7dc29e39a40c7059572bca75bb646b/video-upload__2d7dc29e39a40c7059572bca75bb646b.m3u8",
      )
      expect(article.video_thumbnail_url).to eq(
        "#{cdn_base_url}/video-upload__2d7dc29e39a40c7059572bca75bb646b/thumbs-video-upload__2d7dc29e39a40c7059572bca75bb646b-00001.png",
      )
    end
  end
end

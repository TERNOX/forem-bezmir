require "rails_helper"

RSpec.describe TweetTag, type: :liquid_tag do
  describe "#id" do
    let(:valid_id)      { "1671839966572290048" }
    let(:invalid_id)    { "blahblahblahbl" }

    def generate_tweet_tag(id, capture: true)
      Liquid::Template.register_tag("tweet", TweetTag)
      Liquid::Template.parse("{% tweet #{id} %}", capture_social_embeds: capture)
    end

    before do
      # Fork-only: TweetTag now captures a durable snapshot on render; keep the
      # network out of these parsing specs.
      allow(SocialEmbeds::Snapshotter).to receive(:call).and_return(nil)
    end

    it "checks that the tag is properly parsed" do
      valid_id = "1671839966572290048"
      liquid = generate_tweet_tag(valid_id)

      # rubocop:disable Style/StringLiterals
      expect(liquid.render).to include('<iframe')
        .and include('class="tweet-embed"')
        .and include("id=\"tweet-#{valid_id}")
        .and include("var iframe = document.getElementById('tweet-")
      # rubocop:enable Style/StringLiterals
    end
    it "rejects invalid ids" do
      expect { generate_tweet_tag(invalid_id) }.to raise_error(StandardError)
    end

    it "accepts a valid id" do
      expect { generate_tweet_tag(valid_id) }.not_to raise_error
    end

    it "captures a snapshot on the article-save path" do
      generate_tweet_tag(valid_id).render

      expect(SocialEmbeds::Snapshotter).to have_received(:call).with(hash_including(source_id: valid_id))
    end

    it "does not capture a snapshot without the capture flag (e.g. preview)" do
      generate_tweet_tag(valid_id, capture: false).render

      expect(SocialEmbeds::Snapshotter).not_to have_received(:call)
    end
  end
end

require "rails_helper"

RSpec.describe Articles::TopArticlesDigestWorker, type: :worker do
  describe "#perform" do
    let(:global_secret) { create(:api_secret) }
    let(:subforem) { create(:subforem) }
    let(:subforem_secret) { create(:api_secret) }

    before do
      Settings::General.set_top_articles_digest_bot_api_key(global_secret.secret)
      Settings::General.set_top_articles_digest_bot_api_key(subforem_secret.secret, subforem_id: subforem.id)
    end

    after { RequestStore.clear! }

    it "runs the digest for each configured subforem context" do
      captured_keys = []

      allow(Articles::TopArticles::DigestPublisher).to receive(:new) do |**_args|
        captured_keys << Settings::General.top_articles_digest_bot_api_key
        instance_double(Articles::TopArticles::DigestPublisher, call: nil)
      end

      described_class.new.perform

      expect(captured_keys).to contain_exactly(global_secret.secret, subforem_secret.secret)
    end
  end
end

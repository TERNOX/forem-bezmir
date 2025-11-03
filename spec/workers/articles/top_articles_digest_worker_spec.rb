require "rails_helper"

RSpec.describe Articles::TopArticlesDigestWorker do
  subject(:worker) { described_class.new }

  let(:publisher) { instance_double(Articles::TopArticles::DigestPublisher, call: true) }

  before do
    allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
  end

  around do |example|
    travel_to(current_time) { example.run }
  end

  context "when the configured time matches the current hour" do
    let(:current_time) { Time.zone.local(2024, 6, 17, 10, 0, 0) }

    before do
      Settings::General.set_top_articles_digest_publish_time("10:00")
    end

    it "invokes the digest publisher" do
      worker.perform

      expect(Articles::TopArticles::DigestPublisher).to have_received(:new).with(reference_time: current_time)
      expect(publisher).to have_received(:call)
    end
  end

  context "when the configured time does not match" do
    let(:current_time) { Time.zone.local(2024, 6, 17, 9, 0, 0) }

    before do
      Settings::General.set_top_articles_digest_publish_time("10:00")
    end

    it "skips the publisher" do
      worker.perform

      expect(Articles::TopArticles::DigestPublisher).not_to have_received(:new)
    end
  end

  context "when the application time zone differs from UTC" do
    around do |example|
      Time.use_zone("Eastern Time (US & Canada)") { example.run }
    end

    let(:current_time) { Time.zone.local(2024, 6, 17, 12, 0, 0) }

    it "publishes when the UTC time matches the configuration" do
      Settings::General.set_top_articles_digest_publish_time("16:00")

      worker.perform

      expect(Articles::TopArticles::DigestPublisher).to have_received(:new).with(reference_time: current_time)
      expect(publisher).to have_received(:call)
    end

    it "does not publish when only the local time matches the configuration" do
      Settings::General.set_top_articles_digest_publish_time("12:00")

      worker.perform

      expect(Articles::TopArticles::DigestPublisher).not_to have_received(:new)
    end
  end
end

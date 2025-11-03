require "rails_helper"

RSpec.describe Articles::TopArticlesDigestWorker do
  subject(:worker) { described_class.new }

  let(:current_time) { Time.zone.local(2024, 6, 17, 10, 0, 0) }
  let(:next_run_time) { current_time + 1.day }
  let(:publisher) { instance_double(Articles::TopArticles::DigestPublisher) }
  let(:schedule) { instance_double(Articles::TopArticles::DigestSchedule, next_run_at: next_run_time) }

  before do
    Settings::General.set_top_articles_digest_publish_time("07:00")
    Settings::General.set_top_articles_digest_last_run_status(nil)
    Settings::General.set_top_articles_digest_last_run_at(nil)
    Settings::General.set_top_articles_digest_last_run_message(nil)
    Settings::General.set_top_articles_digest_next_run_at(nil)

    allow(Articles::TopArticles::DigestSchedule).to receive(:new).and_return(schedule)
  end

  around do |example|
    travel_to(current_time) { example.run }
  end

  context "when the publication is due and succeeds" do
    let(:article) { instance_double(Article, persisted?: true) }

    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(true)
      allow(publisher).to receive(:call).and_return(article)
    end

    it "publishes the digest and records a successful run" do
      worker.perform

      expect(Articles::TopArticles::DigestPublisher).to have_received(:new).with(reference_time: current_time)
      expect(publisher).to have_received(:call)

      expect(Settings::General.top_articles_digest_last_run_status).to eq("success")
      expect(Settings::General.top_articles_digest_last_run_at).to eq(current_time)
      expect(Settings::General.top_articles_digest_last_run_message).to be_nil
      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_time)
    end
  end

  context "when the publication is not due" do
    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(false)
    end

    it "records a skipped run" do
      worker.perform

      expect(publisher).not_to have_received(:call)
      expect(Settings::General.top_articles_digest_last_run_status).to eq("skipped")
      expect(Settings::General.top_articles_digest_last_run_at).to eq(current_time)
      expect(Settings::General.top_articles_digest_last_run_message).to be_nil
    end
  end

  context "when configuration errors are present" do
    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return(["Missing API key"])
    end

    it "records a failed run with the error message" do
      worker.perform

      expect(publisher).not_to have_received(:call)
      expect(Settings::General.top_articles_digest_last_run_status).to eq("failed")
      expect(Settings::General.top_articles_digest_last_run_message).to eq("Missing API key")
    end
  end

  context "when the article cannot be published" do
    let(:article) { instance_double(Article, persisted?: false) }

    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(true)
      allow(publisher).to receive(:call).and_return(article)
    end

    it "stores a failure message" do
      worker.perform

      expect(Settings::General.top_articles_digest_last_run_status).to eq("failed")
      expect(Settings::General.top_articles_digest_last_run_message).to eq(
        I18n.t("workers.articles.top_articles_digest.publication_failed"),
      )
    end
  end

  context "when the configured time does not match the current hour" do
    let(:current_time) { Time.zone.local(2024, 6, 17, 9, 0, 0) }

    before do
      Settings::General.set_top_articles_digest_publish_time("07:00")
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

    before do
      Settings::General.set_top_articles_digest_publish_time("16:00")
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(true)
      allow(publisher).to receive(:call).and_return(instance_double(Article, persisted?: true))
    end

    it "publishes when the UTC time matches the configuration" do
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

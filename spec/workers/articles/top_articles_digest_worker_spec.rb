require "rails_helper"

RSpec.describe Articles::TopArticlesDigestWorker do
  subject(:worker) { described_class.new }

  let(:scheduled_run_at) { Time.zone.local(2024, 6, 17, 20, 0, 0) }
  let(:current_time) { scheduled_run_at + 15.minutes }
  let(:next_run_time) { scheduled_run_at + 1.week }
  let(:publisher) { instance_double(Articles::TopArticles::DigestPublisher) }
  let(:schedule) { instance_double(Articles::TopArticles::DigestSchedule) }

  before do
    Settings::General.set_top_articles_digest_last_run_status(nil)
    Settings::General.set_top_articles_digest_last_run_at(nil)
    Settings::General.set_top_articles_digest_last_run_message(nil)
    Settings::General.set_top_articles_digest_next_run_at(scheduled_run_at)

    allow(Articles::TopArticles::DigestSchedule).to receive(:new).and_return(schedule)
    allow(schedule).to receive(:next_run_at).and_return(next_run_time)
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

    it "publishes the digest, records success, and schedules the next run" do
      worker.perform

      expect(Articles::TopArticles::DigestPublisher).to have_received(:new).with(reference_time: current_time)
      expect(publisher).to have_received(:call)

      expect(Settings::General.top_articles_digest_last_run_status).to eq("success")
      expect(Settings::General.top_articles_digest_last_run_at).to eq(current_time)
      expect(Settings::General.top_articles_digest_last_run_message).to be_nil
      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_time)
      expect(Articles::TopArticles::DigestSchedule).to have_received(:new).with(
        reference_time: scheduled_run_at + Articles::TopArticles::DigestSchedule.window,
      )
    end
  end

  context "when the publisher reports configuration errors" do
    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return(["Missing API key"])
    end

    it "records the failure and advances the schedule" do
      expect { worker.perform }.not_to raise_error

      expect(Settings::General.top_articles_digest_last_run_status).to eq("failed")
      expect(Settings::General.top_articles_digest_last_run_message).to eq("Missing API key")
      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_time)
    end
  end

  context "when publication is skipped" do
    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(false)
    end

    it "records the skip and advances the schedule" do
      worker.perform

      expect(publisher).not_to have_received(:call)
      expect(Settings::General.top_articles_digest_last_run_status).to eq("skipped")
      expect(Settings::General.top_articles_digest_last_run_at).to eq(current_time)
      expect(Settings::General.top_articles_digest_last_run_message).to be_nil
      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_time)
    end
  end

  context "when the digest publication raises an exception" do
    before do
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(true)
      allow(publisher).to receive(:call).and_raise(StandardError, "boom")
    end

    it "records the failure and re-raises" do
      expect { worker.perform }.to raise_error(StandardError, "boom")

      expect(Settings::General.top_articles_digest_last_run_status).to eq("failed")
      expect(Settings::General.top_articles_digest_last_run_message).to eq("boom")
      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_time)
    end
  end

  context "when the next run is still in the future" do
    let(:current_time) { Time.zone.local(2024, 6, 17, 10, 0, 0) }

    before do
      Settings::General.set_top_articles_digest_next_run_at(current_time + 5.hours)
    end

    it "does nothing" do
      worker.perform

      expect(Articles::TopArticles::DigestPublisher).not_to have_received(:new)
      expect(Settings::General.top_articles_digest_last_run_status).to be_nil
      expect(Settings::General.top_articles_digest_next_run_at).to eq(current_time + 5.hours)
    end
  end

  context "when the schedule needs to be seeded" do
    before do
      Settings::General.set_top_articles_digest_next_run_at(nil)
      allow(schedule).to receive(:next_run_at).and_return(scheduled_run_at, next_run_time)
      allow(Articles::TopArticles::DigestPublisher).to receive(:new).and_return(publisher)
      allow(publisher).to receive(:publication_errors).and_return([])
      allow(publisher).to receive(:publication_due?).and_return(true)
      allow(publisher).to receive(:call).and_return(instance_double(Article, persisted?: true))
    end

    it "initializes the schedule and publishes immediately" do
      worker.perform

      expect(Settings::General.top_articles_digest_next_run_at).to eq(next_run_time)
      expect(Articles::TopArticles::DigestSchedule).to have_received(:new).with(
        reference_time: current_time - Articles::TopArticles::DigestSchedule.window,
      )
      expect(Articles::TopArticles::DigestPublisher).to have_received(:new).with(reference_time: current_time)
    end
  end
end

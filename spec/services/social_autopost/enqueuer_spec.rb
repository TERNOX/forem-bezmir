require "rails_helper"

RSpec.describe SocialAutopost::Enqueuer do
  let(:article) { create(:article) }

  before do
    Settings::SocialAutopost.enabled = true
    Settings::SocialAutopost.telegram_bot_token = "123:abc"
    Settings::SocialAutopost.telegram_chat_id = "-100123"
    allow(SocialAutopost::PostItemWorker).to receive(:perform_async)
  end

  describe ".enqueue_digest" do
    it "sends the digest right away by default" do
      item = described_class.enqueue_digest(article)

      expect(item).to have_attributes(source: "digest", kind: "digest", status: "queued")
      expect(item.post_after).to be_present
      expect(SocialAutopost::PostItemWorker).to have_received(:perform_async).with(item.id)
    end

    it "puts the digest first in line for the next slot when configured" do
      SocialAutopostItem.create!(article: create(:article), priority: 3)
      Settings::SocialAutopost.digest_timing = "next_slot"

      item = described_class.enqueue_digest(article)

      expect(item.post_after).to be_nil
      expect(item.priority).to eq(4)
      expect(SocialAutopost::PostItemWorker).not_to have_received(:perform_async)
    end

    it "leaves an item that is being sent alone" do
      item = SocialAutopostItem.create!(article: article, status: "sending")

      described_class.enqueue_digest(article)

      expect(item.reload).to be_sending
      expect(SocialAutopost::PostItemWorker).not_to have_received(:perform_async)
    end

    it "does nothing when digest posting is off" do
      Settings::SocialAutopost.post_digest = false
      expect(described_class.enqueue_digest(article)).to be_nil
      expect(SocialAutopostItem.count).to eq(0)
    end

    it "does nothing while autoposting is off" do
      Settings::SocialAutopost.enabled = false
      expect(described_class.enqueue_digest(article)).to be_nil
    end
  end

  describe ".add_manual" do
    it "queues any published article at the top" do
      item = described_class.add_manual(article)
      expect(item).to have_attributes(source: "manual", status: "queued", priority: 1)
    end

    it "brings a skipped article back" do
      SocialAutopostItem.create!(article: article, status: "skipped", skip_reason: "admin")
      expect(described_class.add_manual(article)).to be_queued
    end

    it "refuses an article that was already posted" do
      SocialAutopostItem.create!(article: article, status: "posted", posted_at: Time.current)
      expect { described_class.add_manual(article) }.to raise_error(described_class::Error)
    end

    it "refuses an article that is being sent right now" do
      item = SocialAutopostItem.create!(article: article, status: "sending")

      expect { described_class.add_manual(article) }.to raise_error(described_class::Error, /being sent/)
      expect(item.reload).to be_sending
    end

    it "refuses drafts" do
      draft = create(:article, published: false, published_at: nil)
      expect { described_class.add_manual(draft) }.to raise_error(described_class::Error)
    end
  end
end

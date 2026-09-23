require "rails_helper"

RSpec.describe Emails::SendUserDigestWorker, type: :worker do
  let(:worker) { described_class.new }
  let(:user) { create(:user) }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:articles) { create_list(:article, 3) }
  let(:collector) { instance_double(EmailDigestArticleCollector, articles_to_send: articles) }
  let(:mailer) { double }
  let(:message_delivery) { double }
  let(:smtp_error) do
    Net::SMTPUnknownError.new(
      "554 5.7.1 <DATA>: Data command rejected: Reject: too many messages from sender in last 60 minutes",
    )
  end

  before do
    allow(Emails::DigestDeliveryLimiter).to receive(:call).and_return(nil)
    user.notification_setting.update!(email_digest_periodic: true)
    allow(Rails).to receive(:cache).and_return(cache)
    allow(EmailDigestArticleCollector).to receive(:new).and_return(collector)
    allow(DigestMailer).to receive(:with).and_return(mailer)
    allow(mailer).to receive(:digest_email).and_return(message_delivery)
    allow(message_delivery).to receive(:message)
    allow(message_delivery).to receive(:deliver_now).and_raise(smtp_error)
    allow(Honeybadger).to receive(:notify)
  end

  it "retains the failed job for retry and pauses other digest deliveries" do
    Timecop.freeze do
      expect { worker.perform(user.id) }.to raise_error(Net::SMTPUnknownError)

      expect(cache.read(described_class::SMTP_COOLDOWN_KEY)).to eq(1.hour.from_now.to_i)
      expect(Honeybadger).not_to have_received(:notify)
      expect(BillboardEvent.count).to eq(0)
    end
  end

  it "waits at least an hour before retrying the rejected delivery" do
    delay = described_class.sidekiq_retry_in_block.call(0, smtp_error)

    expect(delay).to be_between(3600, 3899)
    expect(described_class.sidekiq_retry_in_block.call(0, StandardError.new)).to be_nil
  end

  it "defers another user's digest with its options without contacting SMTP" do
    other_user = create(:user)
    other_user.notification_setting.update!(email_digest_periodic: true)
    attempt = EmailDigestTestAttempt.create!(user: other_user)
    allow(described_class).to receive(:perform_in)

    Timecop.freeze do
      cache.write(described_class::SMTP_COOLDOWN_KEY, 1.hour.from_now.to_i, expires_in: 1.hour)
      worker.perform(other_user.id, "test_attempt_id" => attempt.id)

      expect(described_class).to have_received(:perform_in).with(
        a_value_between(3600, 3659), other_user.id, "test_attempt_id" => attempt.id
      )
    end
    expect(message_delivery).not_to have_received(:deliver_now)
    expect(attempt.reload.status).to eq("queued")
  end

  it "resumes delivery when the cooldown expires" do
    cache.write(described_class::SMTP_COOLDOWN_KEY, 1.second.ago.to_i)
    allow(message_delivery).to receive(:deliver_now)

    worker.perform(user.id)

    expect(message_delivery).to have_received(:deliver_now).once
  end

  it "honors an unsubscribe while a delivery is waiting for retry" do
    user.notification_setting.update!(email_digest_periodic: false)
    allow(described_class).to receive(:perform_in)
    cache.write(described_class::SMTP_COOLDOWN_KEY, 1.hour.from_now.to_i, expires_in: 1.hour)

    worker.perform(user.id)

    expect(message_delivery).not_to have_received(:deliver_now)
    expect(described_class).not_to have_received(:perform_in)
  end

  it "does not treat an unrelated SMTP rejection as an hourly quota" do
    error = Net::SMTPUnknownError.new("554 5.7.1 Message rejected as spam")
    allow(message_delivery).to receive(:deliver_now).and_raise(error)

    worker.perform(user.id)

    expect(cache.read(described_class::SMTP_COOLDOWN_KEY)).to be_nil
    expect(Honeybadger).to have_received(:notify).with(error)
  end

  it "records a tracked attempt failure before allowing Sidekiq to retry" do
    attempt = EmailDigestTestAttempt.create!(user: user)

    expect { worker.perform(user.id, test_attempt_id: attempt.id) }.to raise_error(Net::SMTPUnknownError)

    expect(attempt.reload.status).to eq("failed")
    expect(attempt.error_message).to include("too many messages from sender")
  end
end

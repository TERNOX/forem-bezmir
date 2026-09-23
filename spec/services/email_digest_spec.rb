require "rails_helper"

RSpec.describe EmailDigest, type: :service do
  after { Settings::SMTP.clear_cache }

  describe "::send_digest_email" do
    it "does not enqueue automatic digests while disabled" do
      Settings::SMTP.automatic_digests_enabled = false
      user = create(:user)
      user.notification_setting.update!(email_digest_periodic: true)
      allow(Emails::SendUserDigestWorker).to receive(:perform_async)

      described_class.send_periodic_digest_email

      expect(Emails::SendUserDigestWorker).not_to have_received(:perform_async)
    end

    it "resumes automatic digests when enabled again" do
      user = create(:user)
      user.notification_setting.update!(email_digest_periodic: true)
      allow(Emails::SendUserDigestWorker).to receive(:perform_async)
      Settings::SMTP.automatic_digests_enabled = false
      described_class.send_periodic_digest_email
      Settings::SMTP.automatic_digests_enabled = true

      described_class.send_periodic_digest_email

      expect(Emails::SendUserDigestWorker).to have_received(:perform_async).with(user.id).once
    end

    it "enqueues Emails::SendUserDigestWorker" do
      user = create(:user)
      user.notification_setting.update(email_digest_periodic: true)
      allow(Emails::SendUserDigestWorker).to receive(:perform_async)
      described_class.send_periodic_digest_email
      expect(Emails::SendUserDigestWorker).to have_received(:perform_async).with(user.id)
    end

    it "enqueues DEV digests so Sidekiq applies pacing and retries" do
      allow(ForemInstance).to receive(:dev_to?).and_return(true)
      user = create(:user)
      user.notification_setting.update(email_digest_periodic: true)
      worker = Emails::SendUserDigestWorker.new
      allow(worker).to receive(:perform)
      allow(Emails::SendUserDigestWorker).to receive(:new).and_return(worker)
      allow(Emails::SendUserDigestWorker).to receive(:perform_async)
      described_class.send_periodic_digest_email
      expect(Emails::SendUserDigestWorker).to have_received(:perform_async).with(user.id)
      expect(worker).not_to have_received(:perform)
    end
  end
end

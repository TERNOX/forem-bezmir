require "rails_helper"

RSpec.describe Deliverable do
  let(:user) { create(:user) }

  before do
    Settings::SMTP.address = "smtp.example.com"
    Settings::SMTP.user_name = "sender"
    Settings::SMTP.password = "saved-password"
  end

  after { Settings::SMTP.clear_cache }

  def verification_email
    VerificationMailer.with(user_id: user.id).account_ownership_verification_email
  end

  it "sends by default and resumes after being re-enabled" do
    expect(Settings::SMTP.delivery_enabled).to be(true)
    expect { verification_email.deliver_now }.to change(ActionMailer::Base.deliveries, :size).by(1)

    Settings::SMTP.delivery_enabled = false
    expect { verification_email.deliver_now }.not_to change(ActionMailer::Base.deliveries, :size)

    Settings::SMTP.delivery_enabled = true
    expect { verification_email.deliver_now }.to change(ActionMailer::Base.deliveries, :size).by(1)
  end

  it "checks the switch at delivery time even if the message was already composed" do
    email = verification_email
    email.message
    Settings::SMTP.delivery_enabled = false

    expect { email.deliver_now }.not_to change(ActionMailer::Base.deliveries, :size)
  end

  it "also suppresses Devise password reset mail" do
    Settings::SMTP.delivery_enabled = false

    expect do
      DeviseMailer.reset_password_instructions(user, "test-token").deliver_now
    end.not_to change(ActionMailer::Base.deliveries, :size)
  end

  it "also suppresses the SendGrid fallback without clearing its configuration" do
    Settings::SMTP.address = nil
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SENDGRID_API_KEY").and_return("saved-key")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("SENDGRID_API_KEY", nil).and_return("saved-key")
    Settings::SMTP.delivery_enabled = false

    expect { verification_email.deliver_now }.not_to change(ActionMailer::Base.deliveries, :size)
    expect(Settings::SMTP.settings[:password]).to eq("saved-key")
  end
end

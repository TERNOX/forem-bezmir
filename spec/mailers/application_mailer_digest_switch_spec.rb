require "rails_helper"

RSpec.describe ApplicationMailer do
  let(:user) { create(:user) }

  before do
    Settings::SMTP.address = "smtp.example.com"
    Settings::SMTP.user_name = "sender"
    Settings::SMTP.password = "saved-password"
    Settings::SMTP.automatic_digests_enabled = false
  end

  after { Settings::SMTP.clear_cache }

  it "continues sending verification emails" do
    expect do
      VerificationMailer.with(user_id: user.id).account_ownership_verification_email.deliver_now
    end.to change(ActionMailer::Base.deliveries, :size).by(1)
  end

  it "continues sending password reset emails" do
    expect do
      DeviseMailer.reset_password_instructions(user, "test-token").deliver_now
    end.to change(ActionMailer::Base.deliveries, :size).by(1)
  end
end

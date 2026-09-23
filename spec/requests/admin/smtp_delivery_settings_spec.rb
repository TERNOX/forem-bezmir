require "rails_helper"

RSpec.describe "SMTP delivery settings" do
  let(:admin) { create(:user, :super_admin) }
  let(:credentials) do
    { address: "smtp.example.com", port: 587, authentication: "plain", user_name: "sender",
      password: "saved-password", domain: "example.com", from_email_address: "mail@example.com",
      reply_to_email_address: "reply@example.com" }
  end

  before do
    sign_in admin
    credentials.each { |key, value| Settings::SMTP.public_send(:"#{key}=", value) }
  end

  after { Settings::SMTP.clear_cache }

  it "disables and re-enables sending without clearing credentials or bypassing email confirmation" do
    %w[0 1].each do |value|
      post admin_settings_smtp_settings_path, params: { settings_smtp: { delivery_enabled: value } }

      expect(response).to have_http_status(:ok)
      expect(Settings::SMTP.delivery_enabled).to eq(value == "1")
      expect(Settings::SMTP.settings).to eq(credentials)
      expect(ForemInstance.smtp_enabled?).to be(true)
      expect(build(:user, confirmed_at: nil).__send__(:confirmation_required?)).to be(true)
    end
  end

  it "does not allow a regular admin to change delivery settings" do
    sign_in create(:user, :admin)

    expect do
      post admin_settings_smtp_settings_path, params: { settings_smtp: { delivery_enabled: "0" } }
    end.to raise_error(Pundit::NotAuthorizedError)
    expect(Settings::SMTP.delivery_enabled).to be(true)
  end
end

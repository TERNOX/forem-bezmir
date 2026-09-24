require "rails_helper"

RSpec.describe Authentication::Authenticator do
  before do
    omniauth_mock_providers_payload
    allow(Settings::Authentication).to receive(:providers).and_return(Authentication::Providers.available)
    allow(ForemInstance).to receive(:smtp_enabled?).and_return(true)
    allow(DeviseMailer).to receive(:confirmation_instructions).and_call_original
    allow(Images::SafeRemoteProfileImageUrl).to receive(:call).and_return(nil)
  end

  %i[google_oauth2 apple github].each do |provider|
    it "does not send a redundant confirmation email after #{provider} registration" do
      auth_payload = OmniAuth.config.mock_auth[provider].deep_dup
      auth_payload.info.image = nil
      user = described_class.call(auth_payload)

      expect(user).to be_persisted
      expect(user.reload).to be_confirmed
      expect(user.confirmation_token).to be_nil
      expect(user.identities.pluck(:provider)).to include(provider.to_s)
      expect(DeviseMailer).not_to have_received(:confirmation_instructions)
    end
  end
end

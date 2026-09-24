require "rails_helper"

RSpec.describe User do
  before do
    allow(ForemInstance).to receive(:smtp_enabled?).and_return(true)
    allow(DeviseMailer).to receive(:confirmation_instructions).and_call_original
  end

  it "sends confirmation instructions for an unconfirmed email registration" do
    user = create(:user, confirmed_at: nil)

    expect(user).not_to be_confirmed
    expect(user.confirmation_token).to be_present
    expect(DeviseMailer).to have_received(:confirmation_instructions).with(user, kind_of(String), {})
  end

  it "does not send confirmation instructions for an already confirmed user" do
    user = create(:user)

    expect(user).to be_confirmed
    expect(user.confirmation_token).to be_nil
    expect(DeviseMailer).not_to have_received(:confirmation_instructions)
  end

  it "honors skip_confirmation! when SMTP is enabled" do
    user = build(:user, confirmed_at: nil)
    user.skip_confirmation!
    user.save!

    expect(user.reload).to be_confirmed
    expect(user.confirmation_token).to be_nil
    expect(DeviseMailer).not_to have_received(:confirmation_instructions)
  end

  it "still requires confirmation of a changed email address" do
    user = create(:user)
    original_email = user.email
    user.update!(email: "changed@example.com")

    expect(user.reload.email).to eq(original_email)
    expect(user.unconfirmed_email).to eq("changed@example.com")
    expect(user).to be_pending_reconfirmation
    expect(DeviseMailer).to have_received(:confirmation_instructions)
      .with(user, kind_of(String), to: "changed@example.com")

    confirmed_user = described_class.confirm_by_token(user.confirmation_token)
    expect(confirmed_user.errors).to be_empty
    expect(confirmed_user.reload.email).to eq("changed@example.com")
    expect(confirmed_user).not_to be_pending_reconfirmation
  end

  it "does not require or send confirmation when SMTP is disabled" do
    allow(ForemInstance).to receive(:smtp_enabled?).and_return(false)
    user = create(:user, confirmed_at: nil)

    expect(user).to be_active_for_authentication
    expect(user.confirmation_token).to be_nil
    expect(DeviseMailer).not_to have_received(:confirmation_instructions)
  end
end

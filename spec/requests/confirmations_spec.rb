require "rails_helper"

RSpec.describe "Email confirmation links" do
  before { allow(ForemInstance).to receive(:smtp_enabled?).and_return(true) }

  it "confirms and signs in an unconfirmed user with a valid token" do
    user = create(:user, confirmed_at: nil)

    get user_confirmation_path, params: { confirmation_token: user.confirmation_token }

    expect(response).to have_http_status(:redirect)
    expect(user.reload).to be_confirmed
    expect(controller.current_user).to eq(user)
  end

  it "directs an already confirmed user to sign in without authenticating them" do
    user = create(:user)
    user.update_columns(confirmation_token: "previous-confirmation-token", confirmation_sent_at: Time.current)

    get user_confirmation_path, params: { confirmation_token: user.confirmation_token }

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:notice]).to include(I18n.t("errors.messages.already_confirmed"))
    expect(controller.current_user).to be_nil
  end

  it "does not switch accounts when an already confirmed link is opened while signed in" do
    current_user = create(:user)
    other_user = create(:user)
    other_user.update_columns(confirmation_token: "other-confirmation-token", confirmation_sent_at: Time.current)
    sign_in current_user

    get user_confirmation_path, params: { confirmation_token: other_user.confirmation_token }

    expect(response).to redirect_to(new_user_session_path)
    expect(controller.current_user).to eq(current_user)
  end

  [nil, "invalid-token"].each do |token|
    it "rejects an invalid or missing token (#{token.inspect})" do
      get user_confirmation_path, params: { confirmation_token: token }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(controller.current_user).to be_nil
    end
  end

  it "rejects an expired token for an unconfirmed user" do
    allow(User).to receive(:confirm_within).and_return(1.day)
    user = create(:user, confirmed_at: nil)
    user.update_column(:confirmation_sent_at, 2.days.ago)

    get user_confirmation_path, params: { confirmation_token: user.confirmation_token }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload).not_to be_confirmed
    expect(controller.current_user).to be_nil
  end

  it "confirms a pending new email even when the account is already confirmed" do
    user = create(:user)
    user.update!(email: "new-address@example.com")

    get user_confirmation_path, params: { confirmation_token: user.confirmation_token }

    expect(response).to have_http_status(:redirect)
    expect(user.reload.email).to eq("new-address@example.com")
    expect(user).not_to be_pending_reconfirmation
    expect(controller.current_user).to eq(user)
  end

  it "rejects an expired email-change token without changing the confirmed address" do
    allow(User).to receive(:confirm_within).and_return(1.day)
    user = create(:user)
    original_email = user.email
    user.update!(email: "new-address@example.com")
    user.update_column(:confirmation_sent_at, 2.days.ago)

    get user_confirmation_path, params: { confirmation_token: user.confirmation_token }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.email).to eq(original_email)
    expect(user).to be_pending_reconfirmation
    expect(controller.current_user).to be_nil
  end
end

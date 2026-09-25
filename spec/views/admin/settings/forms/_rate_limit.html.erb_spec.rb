require "rails_helper"

RSpec.describe "admin/settings/forms/_rate_limit" do
  before do
    allow(view).to receive(:current_user).and_return(create(:user, :super_admin))
    view.lookup_context.prefixes = ["admin/settings"]
  end

  it "renders the AI moderation toggle, model field, setup steps and allowlists" do
    allow(Settings::RateLimit).to receive_messages(spam_exempt_usernames: %w[ben jess],
                                                   spam_exempt_organization_slugs: ["my-org"],
                                                   ai_moderation_model: "gemini-2.5-flash")

    render partial: "admin/settings/forms/rate_limit"

    form = Nokogiri::HTML(rendered)
    expect(form.at_css("#settings_rate_limit_ai_spam_moderation_enabled[checked]")).to be_present
    expect(form.at_css("#settings_rate_limit_ai_moderation_model")["value"]).to eq("gemini-2.5-flash")
    expect(form.at_css("#settings_rate_limit_spam_exempt_usernames").text.strip).to eq("ben, jess")
    expect(form.at_css("#settings_rate_limit_spam_exempt_organization_slugs").text.strip).to eq("my-org")
    expect(rendered).to include("aistudio.google.com/apikey")
  end

  it "warns when no Gemini API key is configured" do
    stub_const("Ai::Base::DEFAULT_KEY", nil)

    render partial: "admin/settings/forms/rate_limit"

    expect(rendered).to include(I18n.t("lib.constants.settings.rate_limit.ai_moderation.key_missing"))
  end

  it "confirms when a Gemini API key is configured" do
    stub_const("Ai::Base::DEFAULT_KEY", "present")

    render partial: "admin/settings/forms/rate_limit"

    expect(rendered).to include(I18n.t("lib.constants.settings.rate_limit.ai_moderation.key_present"))
  end
end

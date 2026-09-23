require "rails_helper"

RSpec.describe "admin/settings/forms/_smtp" do
  it "keeps saved fields visible and editable when sending is disabled" do
    Settings::SMTP.delivery_enabled = false
    Settings::SMTP.user_name = "sender"
    Settings::SMTP.password = "saved-password"
    allow(view).to receive(:current_user).and_return(create(:user, :super_admin))
    view.lookup_context.prefixes = ["admin/settings"]

    render partial: "admin/settings/forms/smtp"

    form = Nokogiri::HTML(rendered).at_css('form[data-testid="emailServerSettings"]')
    expect(form.at_css("#settings_smtp_delivery_enabled[checked]")).to be_nil
    expect(form.at_css("#settings_smtp_delivery_enabled")["aria-describedby"]).to eq("smtp-delivery-description")
    expect(form.at_css("#settings_smtp_user_name")["value"]).to eq("sender")
    expect(form.at_css("#settings_smtp_password")["value"]).to eq("saved-password")
    expect(form.at_css("#settings_smtp_password[disabled]")).to be_nil
  end
end

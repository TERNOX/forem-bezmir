require "rails_helper"

RSpec.describe "Admin configures payment provider", :js do
  let(:admin) { create(:user, :super_admin) }

  before do
    sign_in admin
  end

  it "toggles provider-specific fields" do
    visit admin_config_path
    find("summary", text: "Monetization").click

    within("form") do
      expect(page).to have_select("Payment provider", selected: "Stripe")
      expect(page).to have_field("Stripe API key", visible: :visible)
      expect(page).to have_field("Monobank API key", visible: :hidden)

      select "Monobank", from: "Payment provider"

      expect(page).to have_field("Monobank API key", visible: :visible)
      expect(page).to have_field("Monobank publishable key", visible: :visible)
      expect(page).to have_field("Stripe API key", visible: :hidden)
    end
  end
end

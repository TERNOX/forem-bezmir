require "rails_helper"

RSpec.describe "Authentication provider icons" do
  before do
    allow(Authentication::Providers).to receive(:enabled).and_return(%i[apple google_oauth2])
    allow(Settings::Authentication).to receive(:allow_email_password_registration).and_return(true)
    allow(ForemInstance).to receive(:invitation_only?).and_return(false)
  end

  [nil, "new-user"].each do |state|
    it "uses the theme text color for Apple while preserving Google colors (state: #{state.inspect})" do
      get sign_up_path, params: { state: state }

      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      apple_icon = document.at_css(".brand-apple svg")
      google_icon = document.at_css(".brand-google_oauth2 svg")

      expect(apple_icon["class"].split).to include("crayons-icon", "color-primary")
      expect(apple_icon["class"].split).not_to include("crayons-icon--default")
      expect(google_icon["class"].split).to include("crayons-icon--default")
      expect(google_icon.css("path[fill]").map { |path| path["fill"] }.uniq.size).to be > 1
    end
  end

  it "uses the theme text color for the email signup icon" do
    get sign_up_path, params: { state: "new-user" }

    expect(response).to have_http_status(:ok)
    icon = Nokogiri::HTML(response.body).at_css(".registration__actions-providers > a svg")

    expect(icon["class"].split).to include("crayons-icon", "color-primary")
    expect(icon["class"].split).not_to include("crayons-icon--default")
  end
end

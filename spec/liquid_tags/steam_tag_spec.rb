require "rails_helper"

RSpec.describe SteamTag, type: :liquid_tag do
  describe "#render" do
    let(:app_id) { "1539140" }
    let(:steam_url) { "https://store.steampowered.com/app/#{app_id}/STONKS9800_Stock_Market_Simulator/" }

    before do
      allow(UnifiedEmbed::Tag).to receive(:validate_link).and_return(steam_url)
    end

    it "renders the Steam widget iframe" do
      rendered = Liquid::Template.parse("{% embed #{steam_url} %}").render

      expect(rendered).to include("src=\"https://store.steampowered.com/widget/#{app_id}/\"")
      expect(rendered).to include("width=\"100%\"")
      expect(rendered).to include("height=\"200\"")
    end

    it "raises an error for invalid steam urls" do
      expect { Liquid::Template.parse("{% steam invalid %}") }.to raise_error(StandardError, "Invalid Steam URL")
    end
  end
end

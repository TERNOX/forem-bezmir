require "rails_helper"

RSpec.describe SocialImageHelper do
  describe "#user_social_image_url" do
    let(:user) { build_stubbed(:user) }
    let(:card_url) { "https://example.com/profile-card.png" }

    before { allow(user).to receive(:social_image).and_return(card_url) }

    after { Settings::General.quote_card_social_images = true }

    it "uses the user's generated profile card when quote cards are on" do
      allow(Images::Optimizer).to receive(:call).and_return("optimized-card")

      expect(helper.user_social_image_url(user)).to eq("optimized-card")
    end

    it "falls back to the site social image when quote cards are switched off" do
      Settings::General.quote_card_social_images = false

      expect(helper.user_social_image_url(user)).to eq(Settings::General.main_social_image.to_s)
    end

    it "falls back to the site social image when the user has no card yet" do
      allow(user).to receive(:social_image).and_return(nil)

      expect(helper.user_social_image_url(user)).to eq(Settings::General.main_social_image.to_s)
    end
  end
end

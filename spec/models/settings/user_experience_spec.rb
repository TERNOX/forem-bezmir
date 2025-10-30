require "rails_helper"

RSpec.describe Settings::UserExperience do
  describe "validating hex string format" do
    it "allows 3 character hex strings" do
      expect do
        described_class.primary_brand_color_hex = "#000"
      end.not_to raise_error
    end

    it "allows 6 character hex strings" do
      expect do
        described_class.primary_brand_color_hex = "#000000"
      end.not_to raise_error
    end

    it "rejects strings without leading #" do
      expect do
        described_class.primary_brand_color_hex = "000000"
      end.to raise_error(/must be be a 3 or 6 character hex \(starting with #\)/)
    end

    it "rejects invalid character" do
      expect do
        described_class.primary_brand_color_hex = "#00000g"
      end.to raise_error(/must be be a 3 or 6 character hex \(starting with #\)/)
    end
  end

  describe "validating color contrast" do
    it "allows high enough color contrast" do
      expect do
        described_class.primary_brand_color_hex = "#000"
      end.not_to raise_error
    end

    it "rejects too low color contrast" do
      expect do
        described_class.primary_brand_color_hex = "#fff"
      end.to raise_error(/must be darker for accessibility/)
    end
  end

  describe "default locale syncing" do
    around do |example|
      original_locale = I18n.default_locale
      I18n.default_locale = :en
      example.run
      I18n.default_locale = original_locale
    end

    it "applies a valid configured locale" do
      allow(described_class).to receive(:default_locale).and_return("fr")

      expect do
        described_class.apply_default_locale!
      end.to change(I18n, :default_locale).from(:en).to(:fr)
    end

    it "falls back to the model default when the stored value is blank" do
      allow(described_class).to receive(:default_locale).and_return("")
      allow(described_class).to receive(:get_default).with(:default_locale).and_return("uk")

      expect do
        described_class.apply_default_locale!
      end.to change(I18n, :default_locale).from(:en).to(:uk)
    end

    it "does not change the locale when the value is invalid" do
      allow(described_class).to receive(:default_locale).and_return("zz")

      expect do
        described_class.apply_default_locale!
      end.not_to change(I18n, :default_locale)
    end

    it "silently skips syncing when the database is unavailable" do
      allow(described_class).to receive(:default_locale).and_raise(ActiveRecord::ConnectionNotEstablished.new("test"))

      expect do
        described_class.apply_default_locale!
      end.not_to change(I18n, :default_locale)
    end

    it "syncs locale changes when updating the setting" do
      expect(described_class).to receive(:set_default_locale_without_i18n_sync).with("pt", subforem_id: nil).and_return("pt")
      allow(described_class).to receive(:default_locale).and_return("pt")

      expect do
        described_class.set_default_locale("pt")
      end.to change(I18n, :default_locale).from(:en).to(:pt)
    end
  end
end

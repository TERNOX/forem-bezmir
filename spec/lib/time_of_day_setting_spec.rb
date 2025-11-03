require "rails_helper"

RSpec.describe TimeOfDaySetting do
  describe ".matches?" do
    it "returns true when the hour and minute match" do
      time = Time.zone.local(2024, 6, 17, 10, 0, 0)

      expect(described_class.matches?(time, "10:00")).to be(true)
    end

    it "returns false when the configuration is invalid" do
      time = Time.zone.local(2024, 6, 17, 10, 0, 0)

      expect(described_class.matches?(time, "99:99")).to be(false)
    end

    context "when the application time zone differs from UTC" do
      around do |example|
        Time.use_zone("Eastern Time (US & Canada)") { example.run }
      end

      it "compares configured values with the UTC hour and minute" do
        time = Time.zone.local(2024, 6, 17, 12, 30, 0)

        expect(described_class.matches?(time, "16:30")).to be(true)
      end

      it "does not match when only the local hour and minute align" do
        time = Time.zone.local(2024, 6, 17, 12, 30, 0)

        expect(described_class.matches?(time, "12:30")).to be(false)
      end
    end
  end

  describe ".normalize" do
    it "formats values using two-digit hour and minute" do
      expect(described_class.normalize("7:5")).to eq("07:05")
    end

    it "returns nil when the value cannot be parsed" do
      expect(described_class.normalize("invalid")).to be_nil
    end
  end
end

require "rails_helper"

describe DateHelper do
  describe ".local_date" do
    it "renders date" do
      time = Time.now.in_time_zone('Kyiv') 
      date = time.strftime("%b %-e (%H:%M), %Y")
      tag = (time)
      expect(tag).to eq "<time datetime=\"#{time.iso8601}\" class=\"date\">#{date}</time>"
    end

    it "renders date without year" do
      time = Time.now.in_time_zone('Kyiv') 
      date = time.strftime("%b %-e (%H:%M)")
      tag = (time, show_year: false)
      expect(tag).to eq "<time datetime=\"#{time.iso8601}\" class=\"date-no-year\">#{date}</time>"
    end

    it "returns nil when datetime is nil" do
      expect(helper.local_date(nil)).to be_nil
    end

    it "returns nil when datetime is empty string" do
      expect(helper.local_date("")).to be_nil
    end

    it "returns nil when datetime is a space-only string" do
      expect(helper.local_date("   ")).to be_nil
    end

    it "returns nil when datetime string is unparsable" do
      expect(helper.local_date("not-a-date")).to be_nil
    end
  end
end

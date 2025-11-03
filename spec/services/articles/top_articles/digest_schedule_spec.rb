require "rails_helper"

RSpec.describe Articles::TopArticles::DigestSchedule do
  subject(:schedule) { described_class.new(reference_time: reference_time) }

  let(:schedule_zone) { described_class.time_zone }

  describe "#next_run_at" do
    context "when the reference time is before the weekly window" do
      let(:reference_time) { schedule_zone.local(2024, 6, 17, 19, 15).in_time_zone(Time.zone) }

      it "returns the upcoming Monday at 20:00 Kyiv" do
        next_run = schedule.next_run_at

        expect(next_run.in_time_zone(schedule_zone)).to eq(schedule_zone.local(2024, 6, 17, 20, 0, 0))
      end
    end

    context "when the reference time is after the weekly window" do
      let(:reference_time) { schedule_zone.local(2024, 6, 17, 21, 30).in_time_zone(Time.zone) }

      it "returns the following Monday at 20:00 Kyiv" do
        next_run = schedule.next_run_at

        expect(next_run.in_time_zone(schedule_zone)).to eq(schedule_zone.local(2024, 6, 24, 20, 0, 0))
      end
    end

    context "when the application time zone differs" do
      around do |example|
        Time.use_zone("Eastern Time (US & Canada)") { example.run }
      end

      let(:reference_time) { schedule_zone.local(2024, 6, 17, 18, 55).in_time_zone(Time.zone) }

      it "still bases the run on the Kyiv schedule" do
        next_run = schedule.next_run_at

        expect(next_run.in_time_zone(schedule_zone)).to eq(schedule_zone.local(2024, 6, 17, 20, 0, 0))
      end
    end
  end

  describe ".scheduled_time_for" do
    let(:reference_time) { schedule_zone.local(2024, 6, 18, 12, 0).in_time_zone(Time.zone) }

    it "returns the Kyiv Monday at 20:00 for the given week" do
      scheduled = described_class.scheduled_time_for(reference_time)

      expect(scheduled).to eq(schedule_zone.local(2024, 6, 17, 20, 0, 0))
    end
  end

  describe ".window" do
    it "is one hour" do
      expect(described_class.window).to eq(1.hour)
    end
  end
end

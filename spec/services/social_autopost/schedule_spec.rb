require "rails_helper"

RSpec.describe SocialAutopost::Schedule do
  let(:kyiv) { described_class.time_zone }
  let(:schedule) { described_class.new }

  describe ".parse" do
    it "reads several windows" do
      windows = described_class.parse("13:00-16:00, 18:30-22:00")
      expect(windows.map { |w| [w.start_minute, w.end_minute] }).to eq([[780, 960], [1110, 1320]])
    end

    it "treats an empty value as no windows" do
      expect(described_class.parse("  ")).to eq([])
    end

    it "rejects malformed and reversed windows" do
      expect { described_class.parse("19-21") }.to raise_error(ArgumentError)
      expect { described_class.parse("22:00-19:00") }.to raise_error(ArgumentError)
      expect { described_class.parse("19:75-21:00") }.to raise_error(ArgumentError)
    end
  end

  describe "#open_at?" do
    # 2026-11-11 is a Wednesday, 2026-11-14 a Saturday.
    it "uses the weekday windows by default" do
      expect(schedule.open_at?(kyiv.local(2026, 11, 11, 18, 59))).to be(false)
      expect(schedule.open_at?(kyiv.local(2026, 11, 11, 19, 0))).to be(true)
      expect(schedule.open_at?(kyiv.local(2026, 11, 11, 21, 29))).to be(true)
      expect(schedule.open_at?(kyiv.local(2026, 11, 11, 21, 30))).to be(false)
    end

    it "uses the weekend windows on Saturday" do
      expect(schedule.open_at?(kyiv.local(2026, 11, 14, 13, 0))).to be(true)
      expect(schedule.open_at?(kyiv.local(2026, 11, 14, 12, 59))).to be(false)
    end

    it "is closed on a day left empty" do
      Settings::SocialAutopost.schedule_wednesday = ""
      expect(described_class.new.open_at?(kyiv.local(2026, 11, 11, 20, 0))).to be(false)
    end

    it "works from a UTC time" do
      expect(schedule.open_at?(kyiv.local(2026, 11, 11, 20, 0).utc)).to be(true)
    end
  end

  describe "#next_open_at" do
    it "returns the next window start" do
      expect(schedule.next_open_at(kyiv.local(2026, 11, 11, 22, 0))).to eq(kyiv.local(2026, 11, 12, 19, 0))
    end

    it "returns the time itself inside a window" do
      time = kyiv.local(2026, 11, 14, 15, 0)
      expect(schedule.next_open_at(time)).to eq(time)
    end

    it "is nil when no day has a window" do
      Settings::SocialAutopost::WEEKDAYS.each { |day| Settings::SocialAutopost.public_send(:"schedule_#{day}=", "") }
      expect(described_class.new.next_open_at(Time.current)).to be_nil
    end
  end
end

require "rails_helper"

RSpec.describe Users::CalculateMonthlyReputationWorker do
  let(:worker) { described_class.new }

  it "parses the provided period" do
    expect(Users::CalculateMonthlyReputation).to receive(:call).with(period: Date.new(2025, 10, 1))

    worker.perform("2025-10-15")
  end

  it "falls back to default period on invalid input" do
    default_period = Date.new(2025, 9, 1)
    allow(Users::CalculateMonthlyReputation).to receive(:default_period).and_return(default_period)

    expect(Users::CalculateMonthlyReputation).to receive(:call).with(period: default_period)

    worker.perform("not-a-date")
  end

  it "uses the default period when none provided" do
    default_period = Date.new(2025, 8, 1)
    allow(Users::CalculateMonthlyReputation).to receive(:default_period).and_return(default_period)

    expect(Users::CalculateMonthlyReputation).to receive(:call).with(period: default_period)

    worker.perform
  end
end

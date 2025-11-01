require "rails_helper"

RSpec.describe Users::MonthlyTopUsersAwardWorker do
  describe "#perform" do
    subject(:perform) { described_class.new.perform }

    let(:schedule) { instance_double(Users::MonthlyTopUsersSchedule, current_period: period, due?: due) }
    let(:period) { Date.new(2024, 10, 1) }

    before do
      allow(Users::MonthlyTopUsersSchedule).to receive(:new).and_return(schedule)
    end

    context "when the job is due" do
      let(:due) { true }

      it "invokes the reputation calculation" do
        expect(Users::CalculateMonthlyReputation).to receive(:call).with(period: period)

        perform
      end
    end

    context "when the job is not due" do
      let(:due) { false }

      it "does not call the calculator" do
        expect(Users::CalculateMonthlyReputation).not_to receive(:call)

        perform
      end
    end
  end
end

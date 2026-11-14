require "rails_helper"

RSpec.describe SocialAutopost::TickWorker do
  it "records a failure for the admin page before re-raising it" do
    allow(SocialAutopost::Ticker).to receive(:call).and_raise(ArgumentError, "broken window")

    expect { described_class.new.perform }.to raise_error(ArgumentError)
    expect(Settings::SocialAutopost.last_error).to eq("ArgumentError: broken window")
  end
end

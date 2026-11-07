require "rails_helper"

RSpec.describe FeedEvents::FeedbackWorker do
  it "keeps accepted events durable when a counter refresh fails and retries feedback separately" do
    event = create(:feed_event)
    allow(FeedEvent).to receive(:bulk_update_counters_by_article_id).and_raise(ActiveRecord::QueryCanceled)
    expect { described_class.new.perform([event.id]) }.to raise_error(ActiveRecord::QueryCanceled)
    expect(FeedEvent.exists?(event.id)).to be(true)
    expect(described_class.get_sidekiq_options).to include("retry" => 10, "lock" => :until_executing)
  end

  it "ignores events removed before the job executes" do
    expect { described_class.new.perform([0]) }.not_to raise_error
  end
end

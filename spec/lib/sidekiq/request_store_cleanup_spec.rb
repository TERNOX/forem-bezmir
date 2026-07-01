require "rails_helper"
require "sidekiq/request_store_cleanup"

RSpec.describe Sidekiq::RequestStoreCleanup do
  subject(:middleware) { described_class.new }

  it "clears RequestStore before the job runs" do
    RequestStore.store[:stale] = "left over from a previous job"

    seen_inside = :not_run
    middleware.call(nil, {}, "default") do
      seen_inside = RequestStore.store[:stale]
    end

    expect(seen_inside).to be_nil
  end

  it "clears RequestStore after the job runs" do
    middleware.call(nil, {}, "default") do
      RequestStore.store[:during] = "value set during the job"
    end

    expect(RequestStore.store[:during]).to be_nil
  end

  it "still clears RequestStore when the job raises" do
    RequestStore.store[:during] = nil

    expect do
      middleware.call(nil, {}, "default") do
        RequestStore.store[:during] = "value"
        raise "boom"
      end
    end.to raise_error("boom")

    expect(RequestStore.store[:during]).to be_nil
  end

  it "yields the block result" do
    result = middleware.call(nil, {}, "default") { 42 }

    expect(result).to eq(42)
  end
end

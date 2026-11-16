require "rails_helper"

RSpec.describe Novelnya::SyncProfilesWorker, type: :worker do
  let(:user) { create(:user) }

  it "purges the profile pages whose РќРѕРІРµР»СЊРЅСЏ block changed" do
    allow(Novelnya::Profiles).to receive(:refresh!).and_return([user.id])
    allow(EdgeCache::BustUser).to receive(:call)

    described_class.new.perform

    expect(EdgeCache::BustUser).to have_received(:call).with(user)
  end

  it "does nothing when the fetch failed" do
    allow(Novelnya::Profiles).to receive(:refresh!).and_return([])
    allow(EdgeCache::BustUser).to receive(:call)

    described_class.new.perform

    expect(EdgeCache::BustUser).not_to have_received(:call)
  end
end

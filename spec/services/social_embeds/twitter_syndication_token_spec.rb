require "rails_helper"

RSpec.describe SocialEmbeds::TwitterSyndicationToken do
  it "produces a base36 token with zeros and dots stripped" do
    token = described_class.call("1671839966572290048")

    expect(token).to match(/\A[1-9a-z]+\z/)
    expect(token).not_to include(".")
    expect(token).not_to include("0")
  end

  it "is deterministic for the same id" do
    id = "1671839966572290048"
    first_token = described_class.call(id)

    expect(described_class.call(id)).to eq(first_token)
  end

  it "differs for different ids" do
    expect(described_class.call("123")).not_to eq(described_class.call("456"))
  end
end

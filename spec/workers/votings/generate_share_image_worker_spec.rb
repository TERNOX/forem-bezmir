require "rails_helper"

RSpec.describe Votings::GenerateShareImageWorker, type: :worker do
  let(:voting) { create(:voting) }
  let(:category) { create(:voting_category, voting: voting) }
  let(:nominee) { create(:voting_nominee, category: category) }
  let(:ballot) do
    Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                  selections: { category.id.to_s => { "nominee_ids" => [nominee.id] } }).ballot
  end
  let(:image_path) { Rails.root.join("spec/fixtures/files/800x600.png") }

  before { Sidekiq::Worker.clear_all }

  def scheduled
    described_class.jobs.map { |job| [job["args"], job["at"].present?] }
  end

  it "renders the image of a submitted ballot without one" do
    allow(Votings::GenerateShareImage).to receive(:call).and_return(true)

    described_class.new.perform(ballot.id)

    expect(Votings::GenerateShareImage).to have_received(:call).with(ballot)
    expect(described_class.jobs).to be_empty
  end

  it "tries again later when the render did not happen and the ballot still has no image" do
    allow(Votings::GenerateShareImage).to receive(:call).and_return(false)

    described_class.new.perform(ballot.id)

    expect(scheduled).to eq([[[ballot.id, 2], true]])
    expect(described_class.jobs.first["at"]).to be_within(5).of(described_class::RETRY_DELAY.from_now.to_f)

    described_class.new.perform(ballot.id, 2)
    expect(scheduled.last).to eq([[ballot.id, 3], true])
  end

  it "gives up once the attempts are used up" do
    allow(Votings::GenerateShareImage).to receive(:call).and_return(false)

    described_class.new.perform(ballot.id, described_class::MAX_ATTEMPTS)

    expect(Votings::GenerateShareImage).to have_received(:call)
    expect(described_class.jobs).to be_empty
  end

  it "does not try again when the image appeared meanwhile (drawn by another render)" do
    allow(Votings::GenerateShareImage).to receive(:call) do |rendered|
      VotingBallot.find(rendered.id).update!(share_image: Rack::Test::UploadedFile.new(image_path, "image/png"))
      false
    end

    described_class.new.perform(ballot.id)

    expect(described_class.jobs).to be_empty
  end

  it "does nothing for a ballot that already has an image" do
    ballot.update!(share_image: Rack::Test::UploadedFile.new(image_path, "image/png"))
    allow(Votings::GenerateShareImage).to receive(:call)

    described_class.new.perform(ballot.id)

    expect(Votings::GenerateShareImage).not_to have_received(:call)
    expect(described_class.jobs).to be_empty
  end

  it "does not try again when the render succeeded" do
    described_class.new.perform(ballot.id)

    expect(ballot.reload.share_image).to be_present
    expect(described_class.jobs).to be_empty
  end

  it "does nothing for a ballot that is gone" do
    allow(Votings::GenerateShareImage).to receive(:call)

    described_class.new.perform(0)

    expect(Votings::GenerateShareImage).not_to have_received(:call)
    expect(described_class.jobs).to be_empty
  end
end

require "rails_helper"

RSpec.describe Votings::GenerateShareImage do
  it "renders a 1200x630 card even when nominees have no pictures" do
    voting = create(:voting, title: "Гра року 2026 — «тест» 100% @home")
    ranked = create(:voting_category, voting: voting, ranked: true, max_choices: 3)
    other = create(:voting_category, voting: voting, max_choices: 2)
    ranked_nominees = create_list(:voting_nominee, 3, category: ranked)
    other_nominee = create(:voting_nominee, category: other, game: nil, title: "Steam Deck")
    user = create(:user)
    ballot = Votings::BallotSubmitter.call(
      voting: voting, user: user,
      selections: {
        ranked.id.to_s => { "nominee_ids" => ranked_nominees.map(&:id) },
        other.id.to_s => { "nominee_ids" => [other_nominee.id] }
      }
    ).ballot

    described_class.call(ballot)

    expect(ballot.reload.share_image).to be_present
    image = MiniMagick::Image.open(ballot.share_image.path)
    expect([image.width, image.height]).to eq([1200, 630])
  end

  it "drops a stale render when the voter changed their picks meanwhile" do
    voting = create(:voting)
    category = create(:voting_category, voting: voting)
    nominees = create_list(:voting_nominee, 2, category: category)
    user = create(:user)
    submit = lambda do |nominee|
      Votings::BallotSubmitter.call(voting: voting, user: user,
                                    selections: { category.id.to_s => { "nominee_ids" => [nominee.id] } }).ballot
    end
    ballot = VotingBallot.find(submit.call(nominees[0]).id)
    stale = described_class.new(ballot) # captured the first revision
    Timecop.travel(0.2.seconds.from_now) { submit.call(nominees[1]) } # same second

    expect(stale.call).to be(false)
    expect(ballot.reload.share_image).to be_blank
  end

  it "skips the render while another one holds the ballot's lock" do
    voting = create(:voting)
    category = create(:voting_category, voting: voting)
    nominee = create(:voting_nominee, category: category)
    ballot = Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                           selections: { category.id.to_s => { "nominee_ids" => [nominee.id] } }).ballot
    allow(Rails.cache).to receive(:write).and_call_original
    allow(Rails.cache).to receive(:write)
      .with(described_class.lock_key(ballot), anything, hash_including(unless_exist: true)).and_return(false)

    expect(described_class.call(ballot)).to be(false)
    expect(ballot.reload.share_image).to be_blank
  end
end

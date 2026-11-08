require "rails_helper"

RSpec.describe Votings::Results do
  let(:voting) { create(:voting) }
  let(:ranked) { create(:voting_category, voting: voting, max_choices: 3, ranked: true) }
  let(:plain) { create(:voting_category, voting: voting, max_choices: 2, allow_other: true) }
  let!(:hades) { create(:voting_nominee, category: ranked) }
  let!(:silksong) { create(:voting_nominee, category: ranked) }
  let!(:clair) { create(:voting_nominee, category: ranked) }
  let!(:doom) { create(:voting_nominee, category: plain) }

  def vote(user, ranked_ids, other: nil)
    selections = { ranked.id.to_s => { "nominee_ids" => ranked_ids } }
    selections[plain.id.to_s] = { "nominee_ids" => [doom.id], "other" => other } if other
    Votings::BallotSubmitter.call(voting: voting, user: user, selections: selections).tap do |result|
      raise result.errors.inspect unless result.success?
    end
  end

  it "scores ranked places 3-2-1 and orders by points" do
    vote(create(:user), [hades.id, silksong.id, clair.id])   # hades 3, silksong 2, clair 1
    vote(create(:user), [silksong.id, hades.id])             # silksong 3, hades 2
    vote(create(:user), [clair.id])                          # clair 3

    result = described_class.call(voting)
    rows = result[:categories].detect { |c| c.category == ranked }.rows

    expect(result[:ballots_count]).to eq(3)
    expect(rows.map { |row| [row.nominee, row.points, row.votes, row.firsts] }).to eq(
      [[hades, 5, 2, 1], [silksong, 5, 2, 1], [clair, 4, 2, 1]],
    )
  end

  it "groups other answers case-insensitively" do
    vote(create(:user), [hades.id], other: "Steam Deck")
    vote(create(:user), [hades.id], other: "steam deck ")

    plain_result = described_class.call(voting)[:categories].detect { |c| c.category == plain }
    expect(plain_result.other_answers).to eq([["steam deck", 2]])
    expect(plain_result.voters).to eq(2)
  end

  it "drops ballots of voters who lost eligibility after voting" do
    sockpuppet = create(:user)
    vote(sockpuppet, [clair.id])
    vote(create(:user), [hades.id])
    sockpuppet.update_column(:score, -20)

    result = described_class.call(voting)
    rows = result[:categories].detect { |c| c.category == ranked }.rows
    expect(result[:ballots_count]).to eq(1)
    expect(rows.detect { |row| row.nominee == clair }.points).to eq(0)
  end

  it "treats a missing score like zero, as eligibility does" do
    voter = create(:user)
    vote(voter, [clair.id])
    voter.update_column(:score, nil)

    expect(described_class.call(voting)[:ballots_count]).to eq(1)
  end

  it "does not count ballots of spam or suspended members" do
    spammer = create(:user)
    vote(spammer, [clair.id])
    vote(create(:user), [hades.id])
    spammer.add_role(:spam)

    result = described_class.call(voting)
    rows = result[:categories].detect { |c| c.category == ranked }.rows
    expect(result[:ballots_count]).to eq(1)
    expect(rows.detect { |row| row.nominee == clair }.points).to eq(0)
  end
end

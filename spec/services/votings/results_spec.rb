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

  it "scores ranked places by the category's custom points" do
    ranked.update!(rank_points: [5, 3, 1])
    vote(create(:user), [hades.id, silksong.id, clair.id])   # hades 5, silksong 3, clair 1
    vote(create(:user), [silksong.id, hades.id])             # silksong 5, hades 3
    vote(create(:user), [clair.id])                          # clair 5

    rows = described_class.call(voting)[:categories].detect { |c| c.category == ranked }.rows
    expect(rows.map { |row| [row.nominee, row.points, row.votes, row.firsts] }).to eq(
      [[hades, 8, 2, 1], [silksong, 8, 2, 1], [clair, 6, 2, 1]],
    )
  end

  it "gives a pick without a rank (voted before the category became ranked) the lowest place's points" do
    ranked.update!(ranked: false)
    vote(create(:user), [hades.id, silksong.id])
    # Data from before the structure lock (the model no longer allows this once people have voted).
    ranked.update_columns(ranked: true, rank_points: [5, 3, 1])
    vote(create(:user), [clair.id])

    rows = described_class.call(voting)[:categories].detect { |c| c.category == ranked }.rows
    expect(VotingChoice.where(voting_nominee_id: [hades.id, silksong.id]).pluck(:rank)).to eq([nil, nil])
    expect(rows.map { |row| [row.nominee, row.points, row.votes, row.firsts] }).to eq(
      [[clair, 5, 1, 1], [hades, 1, 1, 0], [silksong, 1, 1, 0]],
    )
  end

  describe "places" do
    def ranked_rows
      described_class.call(voting)[:categories].detect { |c| c.category == ranked }.rows
    end

    it "breaks a points tie by first places" do
      vote(create(:user), [hades.id, silksong.id])               # hades 3, silksong 2
      vote(create(:user), [clair.id, silksong.id, hades.id])     # clair 3, silksong 2, hades 1

      expect(ranked_rows.map { |row| [row.nominee, row.points, row.firsts, row.place] }).to eq(
        [[hades, 4, 1, 1], [silksong, 4, 0, 2], [clair, 3, 1, 3]],
      )
    end

    it "shares a place on a complete tie and skips the next one" do
      vote(create(:user), [hades.id, silksong.id, clair.id])     # hades 3, silksong 2, clair 1
      vote(create(:user), [clair.id, silksong.id, hades.id])     # clair 3, silksong 2, hades 1

      expect(ranked_rows.map { |row| [row.nominee, row.points, row.firsts, row.votes, row.place] }).to eq(
        [[hades, 4, 1, 2, 1], [clair, 4, 1, 2, 1], [silksong, 4, 0, 2, 3]],
      )
    end

    it "gives no place to a nominee nobody voted for" do
      vote(create(:user), [hades.id])

      expect(ranked_rows.map { |row| [row.nominee, row.place] }).to eq([[hades, 1], [silksong, nil], [clair, nil]])
      plain_rows = described_class.call(voting)[:categories].detect { |c| c.category == plain }.rows
      expect(plain_rows.map(&:place)).to eq([nil])
    end
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

  it "also reports how many ballots were submitted in total" do
    vote(create(:user), [hades.id])
    vote(create(:user), [clair.id]).ballot.user.update_column(:confirmed_at, nil)
    create(:voting_ballot, voting: voting, submitted_at: nil) # started, never sent

    result = described_class.call(voting)
    expect(result).to include(ballots_count: 1, submitted_count: 2)
  end

  it "drops accounts created after the opening when the voting asks for that" do
    veteran = create(:user, created_at: 1.month.ago)
    vote(veteran, [hades.id])
    vote(create(:user), [clair.id])
    voting.update!(require_account_before_start: true, opens_at: 1.week.ago)

    expect(described_class.call(voting)).to include(ballots_count: 1, submitted_count: 2)
  end
end

require "rails_helper"

RSpec.describe Votings::PagePayload do
  let(:voting) { create(:voting, results_published_at: Time.current) }
  let(:category) { create(:voting_category, voting: voting, max_choices: 3, ranked: true) }
  let!(:hades) { create(:voting_nominee, category: category) }
  let!(:silksong) { create(:voting_nominee, category: category) }
  let!(:clair) { create(:voting_nominee, category: category) }

  def vote(ids)
    Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                  selections: { category.id.to_s => { "nominee_ids" => ids } })
  end

  it "gives each published result row its place and first places" do
    vote([hades.id, silksong.id])    # hades 3, silksong 2
    vote([silksong.id, hades.id])    # silksong 3, hades 2

    rows = described_class.call(voting)[:results]["categories"][category.id.to_s]["rows"]
    expect(rows.map { |row| row.slice("nomineeId", "place", "points", "votes", "firsts") }).to eq(
      [
        { "nomineeId" => hades.id, "place" => 1, "points" => 5, "votes" => 2, "firsts" => 1 },
        { "nomineeId" => silksong.id, "place" => 1, "points" => 5, "votes" => 2, "firsts" => 1 },
        { "nomineeId" => clair.id, "place" => nil, "points" => 0, "votes" => 0, "firsts" => 0 },
      ],
    )
  end

  it "has no results until they are published" do
    voting.update!(results_published_at: nil)
    expect(described_class.call(voting)[:results]).to be_nil
  end

  describe "published results" do
    let(:voter) { create(:user) }

    before do
      vote([hades.id, silksong.id])
      Votings::BallotSubmitter.call(voting: voting, user: voter,
                                    selections: { category.id.to_s => { "nominee_ids" => [silksong.id] } })
      voting.publish_results!
    end

    it "serves the snapshot taken on publishing without counting again" do
      published = described_class.call(voting.reload)[:results]
      expect(published).to eq(voting.results_snapshot)
      expect(published["ballotsCount"]).to eq(2)

      allow(Votings::Results).to receive(:call).and_call_original
      described_class.call(voting.reload)
      expect(Votings::Results).not_to have_received(:call)
    end

    it "keeps the published numbers when the live count changes afterwards" do
      published = described_class.call(voting.reload)[:results]

      voter.add_role(:suspended)
      vote([clair.id]) # the voting is still open

      expect(Votings::Results.call(voting)[:ballots_count]).to eq(2) # one dropped out, one joined...
      live = Votings::PublicResults.call(voting)
      expect(live).not_to eq(published) # ...and the live count moved...
      expect(described_class.call(voting.reload)[:results]).to eq(published) # ...but the public one didn't
    end

    it "falls back to the live count for results published before snapshots existed" do
      voting.update_columns(results_snapshot: nil)
      vote([clair.id])

      expect(described_class.call(voting.reload)[:results]).to eq(Votings::PublicResults.call(voting))
      expect(described_class.call(voting)[:results]["ballotsCount"]).to eq(3)
    end
  end
end

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

    rows = described_class.call(voting)[:results][:categories][category.id][:rows]
    expect(rows.map { |row| row.slice(:nomineeId, :place, :points, :votes, :firsts) }).to eq(
      [
        { nomineeId: hades.id, place: 1, points: 5, votes: 2, firsts: 1 },
        { nomineeId: silksong.id, place: 1, points: 5, votes: 2, firsts: 1 },
        { nomineeId: clair.id, place: nil, points: 0, votes: 0, firsts: 0 },
      ],
    )
  end

  it "has no results until they are published" do
    voting.update!(results_published_at: nil)
    expect(described_class.call(voting)[:results]).to be_nil
  end
end

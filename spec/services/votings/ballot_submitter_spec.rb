require "rails_helper"

RSpec.describe Votings::BallotSubmitter do
  let(:voting) { create(:voting) }
  let(:user) { create(:user) }
  let(:single) { create(:voting_category, voting: voting, max_choices: 1) }
  let(:multi) { create(:voting_category, voting: voting, max_choices: 2, allow_other: true) }
  let(:ranked) { create(:voting_category, voting: voting, max_choices: 3, ranked: true) }
  let(:single_nominees) { create_list(:voting_nominee, 3, category: single) }
  let(:multi_nominees) { create_list(:voting_nominee, 3, category: multi) }
  let(:ranked_nominees) { create_list(:voting_nominee, 4, category: ranked) }

  def submit(selections, voter = user)
    described_class.call(voting: voting, user: voter, selections: selections)
  end

  it "stores the picks and marks the ballot submitted" do
    result = submit({
                      single.id.to_s => { "nominee_ids" => [single_nominees.first.id] },
                      multi.id.to_s => { "nominee_ids" => [multi_nominees[0].id], "other" => "Silksong DLC" }
                    })

    expect(result).to be_success
    ballot = result.ballot
    expect(ballot.submitted_at).to be_present
    expect(ballot.choices.where(voting_category_id: single.id).pluck(:voting_nominee_id))
      .to eq([single_nominees.first.id])
    expect(ballot.choices.where(voting_category_id: multi.id).pluck(:other_text).compact).to eq(["Silksong DLC"])
  end

  it "stores ranked picks in place order" do
    ids = [ranked_nominees[2].id, ranked_nominees[0].id, ranked_nominees[3].id]
    ballot = submit({ ranked.id.to_s => { "nominee_ids" => ids } }).ballot

    expect(ballot.choices.order(:rank).pluck(:voting_nominee_id, :rank))
      .to eq([[ids[0], 1], [ids[1], 2], [ids[2], 3]])
  end

  it "replaces the previous answers on resubmission" do
    submit({ single.id.to_s => { "nominee_ids" => [single_nominees[0].id] } })
    result = submit({ single.id.to_s => { "nominee_ids" => [single_nominees[1].id] } })

    expect(VotingBallot.where(voting: voting, user: user).count).to eq(1)
    expect(result.ballot.choices.pluck(:voting_nominee_id)).to eq([single_nominees[1].id])
  end

  it "rejects more picks than allowed, counting the other answer" do
    result = submit({ multi.id.to_s => { "nominee_ids" => multi_nominees.first(2).map(&:id), "other" => "x" } })
    expect(result).not_to be_success
    expect(result.errors[multi.id]).to include(:too_many)
  end

  it "rejects nominees from another nomination" do
    result = submit({ single.id.to_s => { "nominee_ids" => [multi_nominees.first.id] } })
    expect(result.errors[single.id]).to include(:unknown_nominee)
  end

  it "ignores other answers where they are not allowed" do
    single_nominees
    result = submit({ single.id.to_s => { "nominee_ids" => [], "other" => "nope" } })
    expect(result.errors[:base]).to eq([:empty])
  end

  it "requires answers for required nominations" do
    single.update!(required: true)
    multi_nominees
    result = submit({ multi.id.to_s => { "nominee_ids" => [multi_nominees.first.id] } })
    expect(result.errors[single.id]).to include(:required)
  end

  it "rejects ineligible users and closed votings" do
    expect(submit({}, create(:user, :spam)).errors[:base]).to eq([:restricted])

    voting.update!(opens_at: 2.days.ago, closes_at: 1.minute.ago)
    expect(submit({ single.id.to_s => { "nominee_ids" => [single_nominees.first.id] } }).errors[:base]).to eq([:closed])
  end

  it "accepts ActionController::Parameters" do
    params = ActionController::Parameters.new(single.id.to_s => { nominee_ids: [single_nominees.first.id.to_s] })
    expect(submit(params)).to be_success
  end
end

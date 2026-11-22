require "rails_helper"

RSpec.describe Votings::NomineeRemover do
  let(:voting) { create(:voting) }
  let(:ranked) { create(:voting_category, voting: voting, max_choices: 3, ranked: true, rank_points: [5, 3, 1]) }
  let(:plain) { create(:voting_category, voting: voting, max_choices: 3, allow_other: true) }
  let!(:x_game) { create(:voting_nominee, category: ranked) }
  let!(:b_game) { create(:voting_nominee, category: ranked) }
  let!(:c_game) { create(:voting_nominee, category: ranked) }
  let!(:plain_x) { create(:voting_nominee, category: plain) }
  let!(:plain_y) { create(:voting_nominee, category: plain) }

  def vote(ranked_ids, plain_ids: [], other: nil)
    selections = { ranked.id.to_s => { "nominee_ids" => ranked_ids } }
    selections[plain.id.to_s] = { "nominee_ids" => plain_ids, "other" => other } if plain_ids.any? || other
    Votings::BallotSubmitter.call(voting: voting, user: create(:user), selections: selections).tap do |result|
      raise result.errors.inspect unless result.success?
    end.ballot
  end

  def ranks(ballot, category = ranked)
    ballot.choices.reload.where(voting_category_id: category.id).where.not(voting_nominee_id: nil)
      .order(:rank).pluck(:voting_nominee_id, :rank)
  end

  it "moves the lower places up on every ballot that had the removed nominee" do
    first = vote([x_game.id, b_game.id, c_game.id])
    middle = vote([b_game.id, x_game.id, c_game.id])
    last = vote([c_game.id, b_game.id, x_game.id])
    untouched = vote([b_game.id, c_game.id])

    expect(described_class.call(x_game)).to eq(3)

    expect(VotingNominee.exists?(x_game.id)).to be(false)
    expect(VotingChoice.where(voting_nominee_id: x_game.id)).to be_empty
    expect(ranks(first)).to eq([[b_game.id, 1], [c_game.id, 2]])
    expect(ranks(middle)).to eq([[b_game.id, 1], [c_game.id, 2]])
    expect(ranks(last)).to eq([[c_game.id, 1], [b_game.id, 2]])
    expect(ranks(untouched)).to eq([[b_game.id, 1], [c_game.id, 2]])
  end

  it "gives the promoted pick first-place points in the results" do
    vote([x_game.id, b_game.id, c_game.id])

    described_class.call(x_game)

    rows = Votings::Results.call(voting)[:categories].detect { |c| c.category == ranked }.rows
    expect(rows.map { |row| [row.nominee, row.points, row.firsts] }).to eq([[b_game, 5, 1], [c_game, 3, 0]])
  end

  it "only deletes the choices in an unranked nomination and leaves other answers and nominations alone" do
    ballot = vote([b_game.id, c_game.id], plain_ids: [plain_x.id, plain_y.id], other: "Steam Deck")
    ranked_before = ranks(ballot)

    described_class.call(plain_x)

    plain_choices = ballot.choices.reload.where(voting_category_id: plain.id)
    expect(plain_choices.pluck(:voting_nominee_id, :rank, :other_text))
      .to contain_exactly([plain_y.id, nil, nil], [nil, nil, "Steam Deck"])
    expect(ranks(ballot)).to eq(ranked_before)
  end

  it "keeps other answers and other nominations of the same ballots as they were in a ranked removal" do
    ranked.update!(allow_other: true)
    ballot = Votings::BallotSubmitter.call(
      voting: voting, user: create(:user),
      selections: {
        ranked.id.to_s => { "nominee_ids" => [x_game.id, b_game.id], "other" => "Мій варіант" },
        plain.id.to_s => { "nominee_ids" => [plain_y.id] }
      }
    ).ballot

    described_class.call(x_game)

    expect(ranks(ballot)).to eq([[b_game.id, 1]])
    expect(ballot.choices.where(voting_category_id: ranked.id, voting_nominee_id: nil).pluck(:rank, :other_text))
      .to eq([[nil, "Мій варіант"]])
    expect(ballot.choices.where(voting_category_id: plain.id).pluck(:voting_nominee_id, :rank))
      .to eq([[plain_y.id, nil]])
  end

  it "leaves picks without a rank (cast before the nomination became ranked) unranked" do
    ballot = vote([x_game.id, b_game.id, c_game.id])
    ballot.choices.where(voting_nominee_id: c_game.id).update_all(rank: nil)

    described_class.call(x_game)

    expect(ranks(ballot)).to contain_exactly([b_game.id, 1], [c_game.id, nil])
  end

  it "drops the affected ballots' share images and queues new ones, without touching submitted_at" do
    affected = vote([x_game.id, b_game.id])
    other = vote([b_game.id])
    image_path = Rails.root.join("spec/fixtures/files/800x600.png")
    [affected, other].each do |ballot|
      ballot.update!(share_image: Rack::Test::UploadedFile.new(image_path, "image/png"))
    end
    old_path = affected.reload.share_image.path
    submitted_at = affected.submitted_at
    Sidekiq::Worker.clear_all

    described_class.call(x_game)

    expect(affected.reload.share_image).to be_blank
    expect(File.exist?(old_path)).to be(false)
    expect(affected.submitted_at).to eq(submitted_at)
    expect(other.reload.share_image).to be_present
    expect(Votings::GenerateShareImageWorker.jobs.pluck("args")).to eq([[affected.id]])
  end

  it "queues nothing for a nominee without votes" do
    vote([b_game.id])
    Sidekiq::Worker.clear_all

    expect(described_class.call(x_game)).to eq(0)
    expect(Votings::GenerateShareImageWorker.jobs).to be_empty
  end
end

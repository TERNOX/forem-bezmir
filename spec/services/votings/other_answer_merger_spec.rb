require "rails_helper"

RSpec.describe Votings::OtherAnswerMerger do
  let(:voting) { create(:voting) }
  let(:ranked) do
    create(:voting_category, voting: voting, max_choices: 3, ranked: true, rank_points: [5, 3, 1], allow_other: true)
  end
  let(:plain) { create(:voting_category, voting: voting, max_choices: 3, allow_other: true) }
  let!(:silksong) { create(:voting_nominee, category: ranked) }
  let!(:hades) { create(:voting_nominee, category: ranked) }
  let!(:plain_x) { create(:voting_nominee, category: plain) }

  def vote(ranked_ids = [], other: nil, plain_ids: [], plain_other: nil)
    selections = { ranked.id.to_s => { "nominee_ids" => ranked_ids, "other" => other } }
    selections[plain.id.to_s] = { "nominee_ids" => plain_ids, "other" => plain_other }
    Votings::BallotSubmitter.call(voting: voting, user: create(:user), selections: selections).tap do |result|
      raise result.errors.inspect unless result.success?
    end.ballot
  end

  def picks(ballot, category = ranked)
    ballot.choices.reload.where(voting_category_id: category.id)
      .order(:rank, :id).pluck(:voting_nominee_id, :rank, :other_text)
  end

  def merge(text, nominee: silksong, category: ranked)
    described_class.call(category: category, text: text, nominee: nominee)
  end

  it "merges every case and whitespace variant of the text and leaves other texts alone" do
    lower = vote(other: "silksong")
    upper = vote(other: "SilkSong")
    other_text = vote(other: "Hollow Knight: Silksong")
    # BallotSubmitter strips answers; older data may still carry the spaces.
    spaced = vote(other: "Silksong")
    spaced.choices.where(voting_nominee_id: nil).update_all(other_text: "  Silksong ")

    result = merge("silksong")

    expect(result.to_h).to eq(merged: 3, dropped: 0)
    [lower, upper, spaced].each { |ballot| expect(picks(ballot)).to eq([[silksong.id, 1, nil]]) }
    expect(picks(other_text)).to eq([[nil, nil, "Hollow Knight: Silksong"]])
  end

  it "drops the answer on a ballot that already picked the nominee" do
    ballot = vote([hades.id, silksong.id], other: "Silksong")

    result = merge("silksong")

    expect(result.to_h).to eq(merged: 0, dropped: 1)
    expect(result.total).to eq(1)
    expect(picks(ballot)).to eq([[hades.id, 1, nil], [silksong.id, 2, nil]])
  end

  it "gives the merged answer the place after the ballot's last ranked pick" do
    third = create(:voting_nominee, category: ranked)
    two_picks = vote([hades.id, third.id], other: "silksong")
    only_other = vote(other: "silksong")

    merge("silksong")

    expect(picks(two_picks)).to eq([[hades.id, 1, nil], [third.id, 2, nil], [silksong.id, 3, nil]])
    expect(picks(only_other)).to eq([[silksong.id, 1, nil]])
  end

  it "keeps the rank empty in an unranked nomination" do
    plain_y = create(:voting_nominee, category: plain)
    ballot = vote(plain_ids: [plain_x.id], plain_other: "Steam Deck")

    expect(merge("steam deck", nominee: plain_y, category: plain).to_h).to eq(merged: 1, dropped: 0)

    expect(picks(ballot, plain)).to contain_exactly([plain_x.id, nil, nil], [plain_y.id, nil, nil])
  end

  it "leaves the ballot's other nominations untouched" do
    ballot = vote([hades.id], other: "silksong", plain_ids: [plain_x.id], plain_other: "silksong")

    merge("silksong")

    expect(picks(ballot)).to eq([[hades.id, 1, nil], [silksong.id, 2, nil]])
    expect(picks(ballot, plain)).to contain_exactly([plain_x.id, nil, nil], [nil, nil, "silksong"])
  end

  it "rejects a nominee from another nomination" do
    ballot = vote(other: "silksong")

    expect { merge("silksong", nominee: plain_x) }.to raise_error(ArgumentError)
    expect(picks(ballot)).to eq([[nil, nil, "silksong"]])
  end

  it "merges answers on ballots that are not counted too" do
    ballot = vote(other: "silksong")
    ballot.user.add_role(:spam)

    expect(merge("silksong").merged).to eq(1)
    expect(picks(ballot)).to eq([[silksong.id, 1, nil]])
  end

  it "drops the affected ballots' share images and queues new ones" do
    affected = vote(other: "silksong")
    untouched = vote([hades.id], other: "hades 2")
    image_path = Rails.root.join("spec/fixtures/files/800x600.png")
    [affected, untouched].each do |ballot|
      ballot.update!(share_image: Rack::Test::UploadedFile.new(image_path, "image/png"))
    end
    old_path = affected.reload.share_image.path
    submitted_at = affected.submitted_at
    Sidekiq::Worker.clear_all

    merge("silksong")

    expect(affected.reload.share_image).to be_blank
    expect(File.exist?(old_path)).to be(false)
    expect(affected.submitted_at).to eq(submitted_at)
    expect(untouched.reload.share_image).to be_present
    expect(Votings::GenerateShareImageWorker.jobs.pluck("args")).to eq([[affected.id]])
  end

  it "moves updated_at of every affected ballot, with or without an image, but not submitted_at" do
    affected = vote([hades.id], other: "silksong")
    untouched = vote(other: "hades 2")
    affected.update!(share_image: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/800x600.png"),
                                                               "image/png"))
    without_image = vote(other: "Silksong")
    before = [affected, without_image, untouched].map { |ballot| ballot.reload.slice(:updated_at, :submitted_at) }

    Timecop.travel(1.second.from_now) { merge("silksong") }

    after = [affected, without_image, untouched].map { |ballot| ballot.reload.slice(:updated_at, :submitted_at) }
    expect(after[0]["updated_at"]).to be > before[0]["updated_at"]
    expect(after[1]["updated_at"]).to be > before[1]["updated_at"]
    expect(after[2]).to eq(before[2])
    expect(after.first(2).pluck("submitted_at")).to eq(before.first(2).pluck("submitted_at"))
  end

  it "does nothing and queues nothing when no answer matches" do
    vote(other: "hades 2")
    Sidekiq::Worker.clear_all

    expect(merge("silksong").to_h).to eq(merged: 0, dropped: 0)
    expect(merge("  ").to_h).to eq(merged: 0, dropped: 0)
    expect(Votings::GenerateShareImageWorker.jobs).to be_empty
  end

  it "moves the answers into the nominee's score in the results" do
    vote([silksong.id])
    vote([hades.id], other: "Silksong")
    vote([hades.id, silksong.id], other: "silksong")
    vote(other: "Hades 2")

    before = Votings::Results.call(voting)[:categories].detect { |c| c.category == ranked }
    expect(before.other_answers).to eq([["silksong", 2], ["hades 2", 1]])

    merge("silksong")

    after = Votings::Results.call(voting)[:categories].detect { |c| c.category == ranked }
    row = after.rows.detect { |r| r.nominee == silksong }
    # 5 (1st) + 3 (2nd, merged) + 3 (2nd, already picked; its answer dropped)
    expect([row.votes, row.points, row.firsts]).to eq([3, 11, 1])
    expect(after.other_answers).to eq([["hades 2", 1]])
  end
end

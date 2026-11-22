require "rails_helper"

RSpec.describe Votings::Cloner do
  let(:voting) { create(:voting) }

  def copied_category(source)
    described_class.call(voting).categories.detect { |category| category.title == source.title }
  end

  it "gives the copy of a legacy three-place ranked nomination without points the 5-3-1 default" do
    legacy = create(:voting_category, voting: voting, max_choices: 3, ranked: true)
    legacy.update_column(:rank_points, [])
    expect(legacy.reload.rank_points_list).to eq([3, 2, 1])

    expect(copied_category(legacy)).to have_attributes(ranked: true, max_choices: 3, rank_points: [5, 3, 1])
    expect(legacy.reload.rank_points).to eq([])
  end

  it "copies explicit points per place unchanged" do
    linear = create(:voting_category, voting: voting, max_choices: 3, ranked: true, rank_points: [3, 2, 1])
    custom = create(:voting_category, voting: voting, max_choices: 3, ranked: true, rank_points: [5, 3, 1])

    copy = described_class.call(voting)
    by_title = copy.categories.index_by(&:title)
    expect(by_title[linear.title].rank_points).to eq([3, 2, 1])
    expect(by_title[custom.title].rank_points).to eq([5, 3, 1])
  end

  it "keeps the linear fallback for other numbers of places" do
    four = create(:voting_category, voting: voting, max_choices: 4, ranked: true)

    expect(copied_category(four)).to have_attributes(rank_points: [], rank_points_list: [4, 3, 2, 1])
  end
end

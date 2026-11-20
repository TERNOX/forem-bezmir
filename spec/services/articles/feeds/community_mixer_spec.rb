require "rails_helper"

RSpec.describe Articles::Feeds::CommunityMixer, type: :service do
  let(:editorial_org) { create(:organization) }
  let(:other_org) { create(:organization) }

  def editorial(**attrs)
    create(:article, organization: editorial_org, **attrs)
  end

  def community(*traits, **attrs)
    create(:article, *traits, **attrs)
  end

  def mix(articles, interval: 3, page: 1, user: nil)
    described_class.call(
      articles,
      user: user,
      page: page,
      editorial_organization_ids: [editorial_org.id],
      interval: interval,
    )
  end

  def count_queries(&block)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    queries
  end

  def longest_editorial_run(articles)
    articles.chunk_while { |a, b| [a, b].all? { |art| art.organization_id == editorial_org.id } }
      .filter_map { |chunk| chunk.size if chunk.first.organization_id == editorial_org.id }
      .max.to_i
  end

  describe "the interval rule" do
    it "moves a later community post up so no more than interval - 1 editorial posts run in a row" do
      e1, e2, e3, e4 = Array.new(4) { editorial }
      c1 = community

      expect(mix([e1, e2, e3, c1, e4])).to eq([e1, e2, c1, e3, e4])
    end

    it "treats an organization other than the editorial ones as community" do
      e1, e2, e3 = Array.new(3) { editorial }
      other = community(organization: other_org)

      expect(mix([e1, e2, e3, other])).to eq([e1, e2, other, e3])
    end

    it "lets a community post in its natural position reset the run" do
      e1, e2, e3, e4 = Array.new(4) { editorial }
      c1 = community
      base = [e1, e2, c1, e3, e4]

      expect(mix(base)).to eq(base)
    end

    it "keeps the relative order of community posts" do
      e1, e2, e3 = Array.new(3) { editorial }
      c1, c2 = Array.new(2) { community }

      expect(mix([e1, e2, e3, c1, c2])).to eq([e1, e2, c1, e3, c2])
    end

    it "honours other intervals" do
      editorials = Array.new(4) { editorial }
      c1 = community

      expect(mix([*editorials, c1], interval: 2)).to eq([editorials[0], c1, *editorials[1..]])
    end
  end

  describe "supplementary community posts" do
    it "fills the slots with the hottest recent community posts when the page has none" do
      editorials = Array.new(5) { editorial }
      hot = community(hotness_score: 100)
      warm = community(hotness_score: 50)

      result = mix(editorials)

      expect(result).to eq([editorials[0], editorials[1], hot, editorials[2], editorials[3], warm, editorials[4]])
      expect(longest_editorial_run(result)).to eq(2)
    end

    it "never drops or reorders editorial posts and leaves the page alone when nothing is available" do
      editorials = Array.new(4) { editorial }

      result = mix(editorials)

      expect(result).to eq(editorials)
    end

    it "does not reuse posts that are already on the page" do
      c1 = community(hotness_score: 1000)
      e1, e2, e3 = Array.new(3) { editorial }
      supplement = community(hotness_score: 10)

      expect(mix([c1, e1, e2, e3])).to eq([c1, e1, e2, supplement, e3])
    end

    it "skips posts older than the lookback window, negative-score posts and editorial posts" do
      editorials = Array.new(3) { editorial }
      community(:past, past_published_at: (described_class::LOOKBACK + 1.day).ago, hotness_score: 1000)
      community(score: -5, hotness_score: 900)
      editorial(hotness_score: 800)
      eligible = community(hotness_score: 1)

      expect(mix(editorials)).to eq([editorials[0], editorials[1], eligible, editorials[2]])
    end

    it "offsets supplements by page so later pages do not repeat earlier ones" do
      editorials = Array.new(5) { editorial }
      supplements = [400, 300, 200, 100].map { |hotness| community(hotness_score: hotness) }

      page_two = mix(editorials, page: 2)

      expect(page_two - editorials).to eq(supplements[2..3])
    end

    it "loads supplements with the same limited feed columns as the base feeds" do
      editorials = Array.new(3) { editorial }
      community(hotness_score: 10)

      supplement = (mix(editorials) - editorials).first

      expect(supplement.attributes.keys).to match_array(Article.limited_column_select.to_a.first.attributes.keys)
      expect(supplement.attributes.keys).to include("cached_user", "processed_html", "subforem_id", "edited_at")
      expect(supplement.attributes.keys).not_to include("body_markdown", "semantic_embedding")
    end

    context "with a signed-in user" do
      let(:user) { create(:user) }

      it "excludes posts with tags the user has hidden" do
        antitag = Tag.find_by(name: "notme") || create(:tag, name: "notme")
        user.follows_by_type("ActsAsTaggableOn::Tag").create!(followable: antitag, explicit_points: -5.0)
        editorials = Array.new(3) { editorial }
        community(tags: "notme", hotness_score: 1000)
        visible = community(tags: "surewhynot", hotness_score: 1)

        expect(mix(editorials, user: user)).to eq([editorials[0], editorials[1], visible, editorials[2]])
      end

      it "excludes posts by authors the user has blocked" do
        blocked_author = create(:user)
        create(:user_block, blocker: user, blocked: blocked_author, config: "default")
        editorials = Array.new(3) { editorial }
        community(user: blocked_author, hotness_score: 1000)
        visible = community(hotness_score: 1)

        expect(mix(editorials, user: user)).to eq([editorials[0], editorials[1], visible, editorials[2]])
      end
    end
  end

  describe "when there is nothing to do" do
    it "returns the input untouched without queries when the interval disables mixing" do
      base = Array.new(4) { editorial }

      [0, 1, nil].each do |interval|
        result = nil
        expect(count_queries { result = mix(base, interval: interval) }).to be_empty
        expect(result).to equal(base)
      end
    end

    it "returns empty input untouched" do
      expect(mix([])).to eq([])
    end

    it "does not query when the page has no long editorial run" do
      e1, e2 = Array.new(2) { editorial }
      c1, c2 = Array.new(2) { community }
      base = [e1, c1, e2, c2]

      result = nil
      expect(count_queries { result = mix(base) }).to be_empty
      expect(result).to eq(base)
    end

    it "does not query when a later community post can fill the slot" do
      e1, e2, e3 = Array.new(3) { editorial }
      c1 = community

      expect(count_queries { mix([e1, e2, e3, c1]) }).to be_empty
    end
  end
end

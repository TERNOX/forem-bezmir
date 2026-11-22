require "rails_helper"

RSpec.describe Votings::ShareCard do
  let(:voting) { create(:voting, title: "Гра року 2026") }
  # A factory user's avatar is a local upload under public/, read from disk;
  # the site has no logo by default. So, unless an example stubs a remote URL,
  # a render makes no HTTP requests.
  let(:user) { create(:user) }
  let(:ballot) { create(:voting_ballot, voting: voting, user: user) }
  let(:output) { Tempfile.new(["share_card_spec", ".png"]) }

  after { output.close! }

  # Unsaved nominations: the card only reads the picks it is given, so even a
  # full ballot needs no database rows.
  def nomination(ranked: false, max_choices: 1, title: nil)
    attributes = { voting: voting, ranked: ranked, max_choices: max_choices }
    attributes[:title] = title if title
    build(:voting_category, **attributes)
  end

  def nominees(category, count, title: "Nominee")
    Array.new(count) { |index| build(:voting_nominee, category: category, game: nil, title: "#{title} #{index + 1}") }
  end

  def pick(category, picked, other: nil)
    Votings::BallotPicks::Pick.new(category: category, nominees: picked, other: other)
  end

  def single_picks(count)
    Array.new(count) do
      category = nomination
      pick(category, nominees(category, 1))
    end
  end

  def ranked_pick
    category = nomination(ranked: true, max_choices: 3)
    pick(category, nominees(category, 3))
  end

  def render(picks, layout: :card)
    described_class.call(ballot: ballot, picks: picks, layout: layout, path: output.path)
    image = MiniMagick::Image.open(output.path)
    [image.width, image.height]
  end

  describe "the vote card" do
    it "is 1080px wide and grows with the number of answered nominations" do
      small = render(single_picks(2))
      large = render(single_picks(10))

      expect(small[0]).to eq(1080)
      expect(large[0]).to eq(1080)
      expect(large[1]).to be > small[1]
    end

    it "is exactly the 1080x1920 story size for a ranked nomination plus 32 single-choice ones" do
      expect(render([ranked_pick] + single_picks(32))).to eq([1080, 1920])
    end

    it "makes room for the ranked nomination on top" do
      without = render(single_picks(4))
      with = render([ranked_pick] + single_picks(4))

      expect(with[1]).to be > without[1]
    end

    it "renders without any pictures, without a logo, and with an 'other'-only or two-pick answer" do
      two = nomination(max_choices: 2)
      other = nomination
      picks = [pick(two, nominees(two, 2)), pick(other, [], other: "Silksong")]

      expect(render(picks)).to eq([1080, render(single_picks(2))[1]])
    end

    it "renders titles with @, %, a backslash and emoji" do
      voting.update!(title: "@/etc/passwd 100% \\n 🎮 Гра року")
      tricky = nomination(title: "@cover %[pixel:p{0,0}] \\ 🏆")
      other = nomination(title: "100% «інше» 🎉")
      picks = [
        pick(tricky, nominees(tricky, 1, title: "@nominee 50% \\x 🕹️")),
        pick(other, [], other: "@home 99% \\ 👾"),
        ranked_pick,
      ]

      expect(render(picks)[0]).to eq(1080)
      expect(render(picks, layout: :preview)).to eq([1200, 630])
    end

    it "renders an empty ballot" do
      expect(render([])[0]).to eq(1080)
    end
  end

  describe "the link preview" do
    it "is 1200x630 with a ranked nomination" do
      expect(render([ranked_pick] + single_picks(5), layout: :preview)).to eq([1200, 630])
    end

    it "is 1200x630 without one" do
      expect(render(single_picks(5), layout: :preview)).to eq([1200, 630])
    end

    it "is 1200x630 with an 'other'-only answer and no pictures" do
      category = nomination
      expect(render([pick(category, [], other: "Silksong")], layout: :preview)).to eq([1200, 630])
    end

    it "counts the answered nominations it has no room for" do
      allow(I18n).to receive(:t).and_call_original

      render([ranked_pick] + single_picks(4), layout: :preview)

      expect(I18n).to have_received(:t).with("views.votings.share.image_total", count: 5)
    end
  end

  describe "remote pictures" do
    let(:png) { Rails.root.join("spec/fixtures/files/800x600.png").binread }
    let(:avatar_url) { "https://images.example.com/avatar.png" }
    let(:logo_url) { "https://images.example.com/logo.png" }
    let(:cover_url) { "https://images.example.com/cover.png" }
    let(:picks) do
      category = nomination(ranked: true, max_choices: 3)
      picked = nominees(category, 3)
      allow(picked.first).to receive(:image_url_for).and_return(cover_url)
      [pick(category, picked)] + single_picks(2)
    end

    before do
      allow(user).to receive(:profile_image_url_for).and_return(avatar_url)
      allow(Settings::General).to receive(:resized_logo).and_return(logo_url)
    end

    it "downloads the avatar, the logo and the covers" do
      stub = stub_request(:get, %r{\Ahttps://images\.example\.com/}).to_return(status: 200, body: png)

      expect(render(picks)[0]).to eq(1080)
      expect(render(picks, layout: :preview)).to eq([1200, 630])
      expect(stub).to have_been_requested.times(6)
      [avatar_url, logo_url, cover_url].each do |url|
        expect(a_request(:get, url)).to have_been_made.twice
      end
    end

    it "still renders when they cannot be loaded" do
      stub_request(:get, avatar_url).to_return(status: 404)
      stub_request(:get, logo_url).to_return(status: 200, body: "not an image")
      stub_request(:get, cover_url).to_timeout

      expect(render(picks)[0]).to eq(1080)
      expect(render(picks, layout: :preview)).to eq([1200, 630])
    end
  end
end

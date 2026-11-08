require "rails_helper"

RSpec.describe "Votings" do
  let(:voting) { create(:voting, slug: "gra-roku-2026", title: "Гра року 2026") }
  let!(:category) { create(:voting_category, voting: voting, title: "Гра року", max_choices: 3, ranked: true) }
  let!(:nominees) { create_list(:voting_nominee, 3, category: category) }
  let(:user) { create(:user) }

  describe "GET /vote/:slug" do
    it "renders a published voting with its nominees in the app payload" do
      get "/vote/gra-roku-2026"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Гра року 2026")
      payload = JSON.parse(Nokogiri::HTML(response.body).at_css("#voting-app")["data-voting"])
      expect(payload["categories"].first["nominees"].pluck("id")).to eq(nominees.map(&:id))
      expect(payload["categories"].first["points"]).to eq([3, 2, 1])
      expect(payload["results"]).to be_nil
    end

    it "does not expose results until they are published" do
      voting.update!(results_published_at: Time.current)
      get "/vote/gra-roku-2026"
      payload = JSON.parse(Nokogiri::HTML(response.body).at_css("#voting-app")["data-voting"])
      expect(payload["results"]).to include("ballotsCount" => 0)
    end

    it "hides drafts from members but lets admins preview" do
      voting.update!(published: false)
      expect { get "/vote/gra-roku-2026" }.to raise_error(ActiveRecord::RecordNotFound)

      sign_in create(:user, :super_admin)
      get "/vote/gra-roku-2026"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "top-level path" do
    it "serves a top-level voting at /:slug without edge caching" do
      voting.update!(top_level_path: true)
      get "/gra-roku-2026"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("voting-app")
      expect(response.headers["X-Accel-Expires"]).to be_nil
    end

    it "does not serve a voting at /:slug unless it is top-level" do
      voting
      expect { get "/gra-roku-2026" }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /vote/:slug/ballot" do
    it "tells guests to sign in" do
      get "/vote/gra-roku-2026/ballot"
      expect(response.parsed_body).to include("signedIn" => false, "eligible" => false, "reason" => "sign_in")
    end

    it "returns the member's saved picks" do
      Votings::BallotSubmitter.call(voting: voting, user: user,
                                    selections: {
                                      category.id.to_s => { "nominee_ids" => [nominees[1].id, nominees[0].id] }
                                    })
      sign_in user
      get "/vote/gra-roku-2026/ballot"

      body = response.parsed_body
      expect(body["eligible"]).to be(true)
      expect(body.dig("ballot", "selections", category.id.to_s, "nominee_ids")).to eq([nominees[1].id, nominees[0].id])
      token = VotingBallot.find_by(user: user).share_token
      expect(body["shareUrl"]).to end_with("/vote/gra-roku-2026/u/#{user.username}/#{token}")
    end
  end

  describe "PUT /vote/:slug/ballot" do
    before { sign_in user }

    it "saves the ballot and queues the share image" do
      sidekiq_assert_enqueued_with(job: Votings::GenerateShareImageWorker) do
        put "/vote/gra-roku-2026/ballot",
            params: { selections: { category.id => { nominee_ids: [nominees[2].id] } } }, as: :json
      end
      expect(response).to have_http_status(:ok)
      expect(VotingBallot.find_by(voting: voting, user: user).choices.pluck(:voting_nominee_id)).to eq([nominees[2].id])
    end

    it "does not re-render the share image when the same picks are sent again" do
      selections = { category.id => { nominee_ids: [nominees[2].id] } }
      put "/vote/gra-roku-2026/ballot", params: { selections: selections }, as: :json
      submitted_at = VotingBallot.find_by(user: user).submitted_at

      sidekiq_assert_no_enqueued_jobs(only: Votings::GenerateShareImageWorker) do
        put "/vote/gra-roku-2026/ballot", params: { selections: selections }, as: :json
      end
      expect(response).to have_http_status(:ok)
      expect(VotingBallot.find_by(user: user).submitted_at).to eq(submitted_at)
    end

    it "returns validation errors" do
      put "/vote/gra-roku-2026/ballot", params: { selections: {} }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq("base" => ["empty"])
    end

    it "refuses members who may not vote" do
      user.update_column(:score, -10)
      put "/vote/gra-roku-2026/ballot",
          params: { selections: { category.id => { nominee_ids: [nominees[0].id] } } }, as: :json
      expect(response.parsed_body["errors"]).to eq("base" => ["low_score"])
    end
  end

  it "requires signing in to vote" do
    put "/vote/gra-roku-2026/ballot", params: { selections: {} }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  describe "share page" do
    let(:ballot) do
      Votings::BallotSubmitter.call(voting: voting, user: user,
                                    selections: { category.id.to_s => { "nominee_ids" => [nominees[0].id] } }).ballot
    end
    let(:share_path) { "/vote/gra-roku-2026/u/#{user.username}/#{ballot.share_token}" }

    it "shows the member's picks with an og:image" do
      get share_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(nominees[0].display_title)
      og_image = Nokogiri::HTML(response.body).at_css('meta[property="og:image"]')["content"]
      expect(og_image).to match(%r{#{Regexp.escape(share_path)}/image\?v=\d+\z})
    end

    it "can't be found by guessing the username alone" do
      expect { get "/vote/gra-roku-2026/u/#{user.username}/#{'0' * ballot.share_token.size}" }
        .to raise_error(ActiveRecord::RecordNotFound)
      expect { get "/vote/gra-roku-2026/u/#{user.username}/#{'0' * ballot.share_token.size}/image" }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it "uses a different token for every ballot" do
      other = Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                            selections: { category.id.to_s => { "nominee_ids" => [nominees[1].id] } })
      expect(other.ballot.share_token).not_to eq(ballot.share_token)
      expect(ballot.valid_share_token?(other.ballot.share_token)).to be(false)
    end

    it "404s for members without a ballot" do
      expect { get "/vote/gra-roku-2026/u/#{create(:user).username}/#{ballot.share_token}" }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it "generates the image on demand and redirects to it" do
      get "#{share_path}/image"
      expect(response).to have_http_status(:redirect)
      expect(ballot.reload.share_image).to be_present
    end

    context "when the image is still being drawn elsewhere" do
      before { allow(Votings::GenerateShareImage).to receive(:call).and_return(false) }

      it "sends crawlers to the generic image without caching the redirect" do
        get "#{share_path}/image"

        expect(response).to redirect_to(Settings::General.main_social_image.to_s)
        expect(response.headers["Cache-Control"]).to include("no-store")
      end

      it "asks the voting app to retry" do
        get "#{share_path}/image", params: { attempt: 0 }

        expect(response).to have_http_status(:service_unavailable)
        expect(response.headers["Retry-After"]).to eq("3")
      end
    end

    it "falls back instead of failing when rendering raises" do
      allow(Votings::GenerateShareImage).to receive(:call).and_raise(MiniMagick::Error)

      get "#{share_path}/image"

      expect(response).to redirect_to(Settings::General.main_social_image.to_s)
    end
  end
end

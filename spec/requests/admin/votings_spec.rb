require "rails_helper"

RSpec.describe "Admin::Votings" do
  let(:admin) { create(:user, :super_admin) }
  let(:voting) { create(:voting, published: false) }

  before do
    sign_in admin
    allow(Igdb::Client).to receive(:configured?).and_return(false)
  end

  it "denies regular members" do
    sign_in create(:user)
    expect { get admin_votings_path }.to raise_error(Pundit::NotAuthorizedError)
  end

  it "lists, creates and shows votings" do
    get admin_votings_path
    expect(response).to have_http_status(:ok)

    post admin_votings_path, params: { voting: { title: "Гра року 2026", slug: "gra-roku-2026", published: "1" } }
    created = Voting.find_by(slug: "gra-roku-2026")
    expect(response).to redirect_to(admin_voting_path(created))

    get admin_voting_path(created)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("IGDB is not configured")
  end

  it "re-renders the form on invalid input" do
    post admin_votings_path, params: { voting: { title: "", slug: "Bad slug" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "adds, reorders and copies nominations" do
    post admin_voting_voting_categories_path(voting),
         params: { voting_category: { title: "Найкращий горрор", max_choices: 2, allow_other: "1" } }
    first = voting.categories.last
    expect(first).to have_attributes(title: "Найкращий горрор", max_choices: 2, allow_other: true)

    second = create(:voting_category, voting: voting)
    patch move_admin_voting_voting_category_path(voting, second, direction: "up")
    expect(voting.categories.reload).to eq([second, first])

    create(:voting_nominee, category: first)
    post copy_nominees_admin_voting_voting_category_path(voting, second), params: { source_category_id: first.id }
    expect(second.nominees.count).to eq(1)
  end

  it "saves points per place for a ranked nomination from the form" do
    post admin_voting_voting_categories_path(voting),
         params: { voting_category: { title: "Гра року", max_choices: 3, ranked: "1", rank_points_text: "5,3,1" } }
    category = voting.categories.last
    expect(category).to have_attributes(ranked: true, rank_points: [5, 3, 1])

    get edit_admin_voting_voting_category_path(voting, category)
    expect(response.body).to include('value="5,3,1"')
    get admin_voting_path(voting)
    expect(response.body).to include("(5-3-1 pts)")

    category_path = admin_voting_voting_category_path(voting, category)
    patch category_path, params: { voting_category: { rank_points_text: "" } }
    expect(category.reload.rank_points).to eq([])

    patch category_path, params: { voting_category: { rank_points_text: "5,x,1" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("5,x,1")
    expect(category.reload.rank_points).to eq([])
  end

  it "adds catalog games, custom cards and bulk titles as nominees" do
    category = create(:voting_category, voting: voting)
    game = create(:game, title: "Hades II")

    post admin_voting_voting_category_voting_nominees_path(voting, category, format: :json),
         params: { game_id: game.id }
    expect(response).to have_http_status(:created)

    post admin_voting_voting_category_voting_nominees_path(voting, category),
         params: { voting_nominee: { title: "Steam Deck", link_url: "https://store.steampowered.com" } }
    expect(category.nominees.reload.map(&:display_title)).to eq(["Hades II", "Steam Deck"])

    create(:game, title: "Hollow Knight: Silksong")
    post bulk_create_admin_voting_voting_category_voting_nominees_path(voting, category),
         params: { titles: "hollow knight: silksong\nHades II\nUnknown Game\n!Інше" }
    expect(flash[:notice]).to include("Added 2").and include("Unknown Game").and include("Hades II")
    expect(category.nominees.reload.map(&:display_title)).to include("Hollow Knight: Silksong", "Інше")
  end

  it "shows results, exports CSV and publishes them" do
    category = create(:voting_category, voting: voting)
    nominee = create(:voting_nominee, category: category)
    voting.update!(published: true)
    Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                  selections: { category.id.to_s => { "nominee_ids" => [nominee.id] } })

    get results_admin_voting_path(voting)
    expect(response.body).to include(nominee.display_title)

    get results_admin_voting_path(voting, format: :csv)
    expect(response.body).to include("#{category.title},1,#{nominee.display_title},1,1,0")

    patch publish_results_admin_voting_path(voting)
    expect(voting.reload.results_published_at).to be_present
  end

  it "numbers result rows by place, sharing it on a tie, and explains what is not counted" do
    category = create(:voting_category, voting: voting)
    first, second, unvoted = create_list(:voting_nominee, 3, category: category)
    voting.update!(published: true)
    [first, second].each do |nominee|
      Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                    selections: { category.id.to_s => { "nominee_ids" => [nominee.id] } })
    end
    Votings::BallotSubmitter.call(voting: voting, user: create(:user),
                                  selections: { category.id.to_s => { "nominee_ids" => [unvoted.id] } })
      .ballot.user.add_role(:spam)

    get results_admin_voting_path(voting)
    page = Nokogiri::HTML(response.body)
    expect(page.css("tbody tr").map { |tr| tr.at_css("td").text.strip }).to eq(%w[1 1 —])
    expect(page.text.squish).to include("2 counted of 3 submitted ballots")
      .and include("Not counted: unconfirmed accounts; spam, suspended and banished members; " \
                   "members with a score below 0.")
    expect(response.body).not_to include("accounts created after the voting opened")

    get results_admin_voting_path(voting, format: :csv)
    expect(response.body).to include("#{category.title},1,#{first.display_title},1,1,0")
      .and include("#{category.title},1,#{second.display_title},1,1,0")
      .and include("#{category.title},,#{unvoted.display_title},0,0,0")

    get admin_voting_path(voting)
    expect(response.body).to include("3 submitted ballots")
  end

  it "mentions the account age rule on the results page only when it is on" do
    voting.update!(require_account_before_start: true, opens_at: 1.day.ago)
    get results_admin_voting_path(voting)
    expect(response.body).to include("accounts created after the voting opened")
  end

  it "requires an opening time for the account age rule" do
    patch admin_voting_path(voting), params: { voting: { require_account_before_start: "1", opens_at: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(voting.reload.require_account_before_start).to be(false)
  end

  it "clones a voting without ballots" do
    category = create(:voting_category, voting: voting, ranked: true, max_choices: 3, rank_points: [5, 3, 1])
    create(:voting_nominee, category: category)

    expect { post clone_admin_voting_path(voting) }.to change(Voting, :count).by(1)
    copy = Voting.order(:id).last
    expect(copy).to have_attributes(published: false, slug: "#{voting.slug}-copy")
    expect(copy.categories.first).to have_attributes(ranked: true, max_choices: 3, rank_points: [5, 3, 1])
    expect(copy.categories.first.nominees.count).to eq(1)
  end

  it "clones a legacy voting that has the account-age rule on without an opening date" do
    voting.update_columns(require_account_before_start: true, opens_at: nil)

    expect { post clone_admin_voting_path(voting) }.to change(Voting, :count).by(1)
    expect(Voting.order(:id).last).to have_attributes(require_account_before_start: false, opens_at: nil)
  end

  it "keeps uploaded images when cloning, as the copy's own files" do
    voting.update!(banner_image: fixture_file_upload("800x600.png", "image/png"))
    category = create(:voting_category, voting: voting)
    create(:voting_nominee, category: category, game: nil, title: "Custom card",
                            image: fixture_file_upload("podcast.png", "image/png"))

    post clone_admin_voting_path(voting)

    copy = Voting.order(:id).last
    copied_nominee = copy.categories.first.nominees.first
    expect(copy.banner_image).to be_present
    expect(copied_nominee.image).to be_present
    expect(copied_nominee.image.path).not_to eq(category.nominees.first.image.path)
  end

  describe "nominations and nominees that already have votes" do
    let(:ranked) { create(:voting_category, voting: voting, max_choices: 3, ranked: true, rank_points: [5, 3, 1]) }
    let!(:first_game) { create(:voting_nominee, category: ranked) }
    let!(:second_game) { create(:voting_nominee, category: ranked) }
    let!(:ballot) do
      voting.update!(published: true)
      Votings::BallotSubmitter.call(
        voting: voting, user: create(:user),
        selections: { ranked.id.to_s => { "nominee_ids" => [first_game.id, second_game.id] } }
      ).ballot
    end

    # What a browser would send for the form: enabled fields only, unchecked boxes left out.
    def submitted_fields(html, action, overrides = {})
      form = Nokogiri::HTML(html).css("form").detect { |candidate| candidate["action"] == action }
      toggles = %w[checkbox radio]
      form.css("input, select, textarea").filter_map do |field|
        next if field["name"].blank? || field.key?("disabled") || field["type"] == "submit"
        next if toggles.include?(field["type"]) && !field.key?("checked")

        value = case field.name
                when "select" then (field.at_css("option[selected]") || field.at_css("option"))&.[]("value")
                when "textarea" then field.text
                else field["value"]
                end
        [field["name"], overrides.fetch(field["name"], value.to_s)]
      end
    end

    it "saves the edit form of a locked ranked nomination when only the title changes" do
      get edit_admin_voting_voting_category_path(voting, ranked)
      expect(response.body).to include("People have already voted here")
      action = admin_voting_voting_category_path(voting, ranked)
      fields = submitted_fields(response.body, action, "voting_category[title]" => "Гра року 2026")
      expect(fields.map(&:first)).not_to include("voting_category[ranked]", "voting_category[max_choices]")

      post action, params: URI.encode_www_form(fields),
                   headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

      expect(response).to redirect_to(admin_voting_path(voting, anchor: "category-#{ranked.id}"))
      expect(ranked.reload).to have_attributes(title: "Гра року 2026", ranked: true, max_choices: 3,
                                               rank_points: [5, 3, 1])
    end

    it "rejects a structural change with the reason" do
      patch admin_voting_voting_category_path(voting, ranked), params: { voting_category: { ranked: "0" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("models.voting_category.ranked_locked")))
      expect(ranked.reload.ranked).to be(true)
    end

    it "removes a nominee through the remover, moving the lower places up" do
      get admin_voting_path(voting)
      expect(response.body).to include("It has 1 vote;")

      allow(Votings::NomineeRemover).to receive(:call).and_call_original
      delete admin_voting_voting_category_voting_nominee_path(voting, ranked, first_game)

      expect(Votings::NomineeRemover).to have_received(:call).with(first_game)

      expect(response).to redirect_to(admin_voting_path(voting, anchor: "category-#{ranked.id}"))
      expect(ballot.choices.reload.pluck(:voting_nominee_id, :rank)).to eq([[second_game.id, 1]])
    end

    it "does not replace the game of a nominee that has votes" do
      original_game = first_game.game
      get edit_admin_voting_voting_category_voting_nominee_path(voting, ranked, first_game)
      expect(response.body).not_to include("replace_game_id")

      patch admin_voting_voting_category_voting_nominee_path(voting, ranked, first_game),
            params: { replace_game_id: create(:game).id, voting_nominee: { subtitle: "DLC" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("models.voting_nominee.game_locked")))
      expect(first_game.reload).to have_attributes(game: original_game, subtitle: nil)
    end
  end

  it "searches the catalog (and reports IGDB as not configured)" do
    create(:game, title: "Hades II")
    get search_admin_games_path(q: "hades", format: :json)
    body = response.parsed_body
    expect(body["local"].pluck("title")).to eq(["Hades II"])
    expect(body["igdb_configured"]).to be(false)
  end
end

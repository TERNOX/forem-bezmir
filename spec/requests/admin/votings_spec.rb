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

  it "clones a voting without ballots" do
    category = create(:voting_category, voting: voting, ranked: true, max_choices: 3)
    create(:voting_nominee, category: category)

    expect { post clone_admin_voting_path(voting) }.to change(Voting, :count).by(1)
    copy = Voting.order(:id).last
    expect(copy).to have_attributes(published: false, slug: "#{voting.slug}-copy")
    expect(copy.categories.first).to have_attributes(ranked: true, max_choices: 3)
    expect(copy.categories.first.nominees.count).to eq(1)
  end

  it "searches the catalog (and reports IGDB as not configured)" do
    create(:game, title: "Hades II")
    get search_admin_games_path(q: "hades", format: :json)
    body = response.parsed_body
    expect(body["local"].pluck("title")).to eq(["Hades II"])
    expect(body["igdb_configured"]).to be(false)
  end
end

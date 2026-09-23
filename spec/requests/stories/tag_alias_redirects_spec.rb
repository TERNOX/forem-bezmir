require "rails_helper"

RSpec.describe "Tag alias redirects" do
  let!(:canonical_tag) { create(:tag, name: "геймдев") }
  let!(:alias_tag) { create(:tag, name: "ґеймдев", alias_for: canonical_tag.name) }
  let(:canonical_path) { "/t/%D0%B3%D0%B5%D0%B9%D0%BC%D0%B4%D0%B5%D0%B2" }
  let(:alias_path) { "/t/%D2%91%D0%B5%D0%B9%D0%BC%D0%B4%D0%B5%D0%B2" }

  before do
    allow(Stories::TaggedArticlesController).to receive(:raise_on_open_redirects).and_return(true)
  end

  [false, true].each do |signed_in|
    context "when signed #{signed_in ? 'in' : 'out'}" do
      before do
        sign_in create(:user) if signed_in
      end

      it "redirects a Unicode alias to an encoded same-host URL and renders the tag", :aggregate_failures do
        get alias_path

        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(canonical_path)
        expect(URI.parse(response.location).host).to eq(request.host)

        follow_redirect!

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(canonical_tag.name)
      end
    end
  end

  it "preserves the internal navigation marker" do
    get alias_path, params: { i: "i" }

    expect(response).to redirect_to("#{canonical_path}?i=i")
  end

  it "continues redirecting ASCII aliases" do
    canonical_tag.update!(name: "gamedev")
    alias_tag.update!(alias_for: canonical_tag.name)

    get alias_path

    expect(response).to redirect_to("/t/gamedev")
  end
end

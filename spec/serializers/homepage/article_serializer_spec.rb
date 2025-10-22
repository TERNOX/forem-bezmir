require "rails_helper"

RSpec.describe Homepage::ArticleSerializer, type: :serializer do
  describe "#serialized_collection_from" do
    let(:user) { create(:user, name: "\"Rowdy\" Roddy Piper \\:/") }
    let(:organization) { create(:organization) }
    let(:tag) { create(:tag, name: "ama", bg_color_hex: "#f3f3f3", text_color_hex: "#cccccc") }
    let(:article) { create(:article, user: user, organization: organization, tags: tag.name) }

    before do
      article
      stub_const("FlareTag::FLARE_TAG_IDS_HASH", { "ama" => tag.id })
    end

    it "is parseable as JSON (once converted to_json)" do
      response = described_class.serialized_collection_from(relation: Article.all)
      expect(JSON.parse(response.to_json)[0].dig("user", "name")).to eq(user.name)
    end

    it "includes cover image attributes when available" do
      article.update!(
        main_image: "https://example.com/test.png",
        main_image_background_hex_color: "#123456",
        main_image_height: 420,
      )

      allow(ApplicationController.helpers).to receive(:cloud_cover_url).and_call_original

      response = described_class.serialized_collection_from(relation: Article.where(id: article.id))
      serialized_article = response.first

      expect(serialized_article[:main_image]).to eq(
        ApplicationController.helpers.cloud_cover_url(article.main_image, article.subforem_id),
      )
      expect(serialized_article[:main_image_background_hex_color]).to eq("#123456")
      expect(serialized_article[:main_image_height]).to eq(420)
    end

    it "marks an article as pinned when it matches the pinned article id" do
      allow(PinnedArticle).to receive(:id).and_return(article.id)

      response = described_class.serialized_collection_from(relation: Article.where(id: article.id))

      expect(response.first[:pinned]).to be(true)
    end

    it "includes the sanitized first paragraph text when present" do
      article.update!(processed_html: "<p>Hello <a href='/'>link</a></p><p>Next</p>")

      response = described_class.serialized_collection_from(relation: Article.where(id: article.id))

      expect(response.first[:first_paragraph_text]).to eq("Hello link")
    end
  end
end

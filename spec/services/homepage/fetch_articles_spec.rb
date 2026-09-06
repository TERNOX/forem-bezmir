require "rails_helper"

RSpec.describe Homepage::FetchArticles, type: :service do
  describe ".call" do
    it "returns results in the correct format", :aggregate_failures do
      tag = create(:tag, name: "ama", bg_color_hex: "#f3f3f3", text_color_hex: "#cccccc")
      article = create(:article, video_thumbnail_url: "https://example.com", tags: tag.name)

      stub_const("FlareTag::FLARE_TAG_IDS_HASH", { "ama" => tag.id })

      result = described_class.call.first

      base_keys = %i[
        class_name cloudinary_video_url comments_count favorited_by_user_id flare_tag id path
        pinned public_reactions_count public_reaction_categories
        published_at_int readable_publish_date reading_time tag_list title
        user user_id video_duration_string
      ]
      expect(result.keys).to include(*base_keys)

      expect(result[:class_name]).to eq("Article")
      expect(result[:cloudinary_video_url]).to eq(article.cloudinary_video_url)
      expect(result[:comments_count]).to eq(article.comments.size)
      expect(result[:id]).to eq(article.id)
      expect(result[:path]).to eq(article.path)
      expect(result[:public_reactions_count]).to eq(article.public_reactions_count)
      expect(result[:pinned]).to be(false)

      expect(result[:published_at_int]).to eq(article.published_at.to_i)
      expect(result[:readable_publish_date]).to eq(article.readable_publish_date)
      expect(result[:reading_time]).to eq(article.reading_time)
      expect(result[:flare_tag]).to eq(Homepage::FetchTagFlares.call([article])[article.id])
      expect(result[:tag_list]).to eq(article.tag_list)
      expect(result[:title]).to eq(article.title)

      expect(result[:user_id]).to eq(article.user_id)
      expect(result[:video_duration_string]).to eq(article.video_duration_in_minutes)
    end

    it "returns the user object in the correct format", :aggregate_failures do
      article = create(:article)

      result = described_class.call.first
      user = result[:user]

      expect(user[:name]).to eq(article.user.name)
      expect(user[:profile_image_90]).to eq(article.user.profile_image_90)
      expect(user[:username]).to eq(article.user.username)
    end

    it "returns the organization object in the correct format", :aggregate_failures do
      article = create(:article, organization: create(:organization))

      result = described_class.call.first
      organization = result[:organization]

      expect(organization[:name]).to eq(article.organization.name)
      expect(organization[:profile_image_90]).to eq(article.organization.profile_image_90)
      expect(organization[:slug]).to eq(article.organization.slug)
    end

    it "returns cover metadata when available" do
      article = create(
        :article,
        main_image: "https://res.cloudinary.com/demo/image/upload/sample.jpg",
        main_image_background_hex_color: "#123456",
        main_image_height: 420,
      )

      result = described_class.call(user_id: article.user_id).find { |attrs| attrs[:id] == article.id }

      expect(result[:main_image]).to eq(
        ApplicationController.helpers.cloud_cover_url(article.main_image, article.subforem_id),
      )
      expect(result[:main_image_background_hex_color]).to eq("#123456")
      expect(result[:main_image_height]).to eq(420)
    end

    it "excludes articles from the provided organizations" do
      excluded_org = create(:organization)
      allowed_org = create(:organization)
      excluded_article = create(:article, organization: excluded_org)
      allowed_article = create(:article, organization: allowed_org)
      personal_article = create(:article, organization: nil)

      result = described_class.call(excluded_organization_ids: [excluded_org.id])
      result_ids = result.map { |attrs| attrs[:id] }

      expect(result_ids).not_to include(excluded_article.id)
      expect(result_ids).to include(allowed_article.id, personal_article.id)
    end
  end
end

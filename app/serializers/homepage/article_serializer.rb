module Homepage
  class ArticleSerializer < ApplicationSerializer
    # @param relation [ActiveRecord::Relation<Article>]
    #
    # @return [Hash]
    def self.serialized_collection_from(relation:)
      # Unfortunately the FlareTag class sends one SQL query per each article,
      # as we want to optimize by loading them in one query, we're using a different class
      tag_flares = Homepage::FetchTagFlares.call(relation)

      # including user and organization as the last step as they are not needed
      # by the query that fetches tag flares, they are only needed by the serializer
      relation = relation.includes(:user, :organization)

      new(relation, params: { tag_flares: tag_flares }, is_collection: true)
        .serializable_hash[:data]
        .pluck(:attributes)
    end

    def self.attribute_value(article, attribute_name)
      if article.respond_to?(:has_attribute?) && article.has_attribute?(attribute_name)
        article[attribute_name]
      elsif article.respond_to?(attribute_name)
        article.public_send(attribute_name)
      end
    end

    attributes(
      :class_name,
      :cloudinary_video_url,
      :id,
      :path,
      :public_reactions_count,
      :readable_publish_date,
      :reading_time,
      :title,
      :user_id,
      :video,
      :public_reaction_categories,
    )

    attribute :video_source_url do |article|
      if article.video_source_url.present?
        article.video_source_url
      elsif article.video.present? && article.video.match?(%r{\.(mp4|webm|mov|m4v|qt|m3u8)(?:$|[?#])}i)
        article.video
      end
    end

    # return displayed_comments_count (excluding low score comments) if it was calculated earlier
    attribute :comments_count, (lambda do |article|
      article.displayed_comments_count? ? article.displayed_comments_count : article.comments_count
    end)
    attribute :video_duration_string, &:video_duration_in_minutes
    attribute :published_at_int, ->(article) { article.published_at.to_i }
    attribute :tag_list, ->(article) { article.cached_tag_list.to_s.split(", ") }
    attribute :flare_tag, ->(article, params) { params.dig(:tag_flares, article.id) }

    attribute :first_paragraph_text,
              if: proc { |article| article.respond_to?(:first_paragraph_text) } do |article|
      article.first_paragraph_text
    end

    attribute :pinned, if: proc { |article| article.is_a?(::Article) } do |article|
      article.id == PinnedArticle.id
    end

    attribute :main_image_background_hex_color,
              if: proc { |article| Homepage::ArticleSerializer.attribute_value(article, :main_image_background_hex_color).present? } do |article|
      Homepage::ArticleSerializer.attribute_value(article, :main_image_background_hex_color)
    end

    attribute :main_image_height,
              if: proc { |article| Homepage::ArticleSerializer.attribute_value(article, :main_image_height).present? } do |article|
      Homepage::ArticleSerializer.attribute_value(article, :main_image_height)
    end

    attribute :main_image,
              if: proc { |article| Homepage::ArticleSerializer.attribute_value(article, :main_image).present? } do |article|
      main_image = Homepage::ArticleSerializer.attribute_value(article, :main_image)
      subforem_id = Homepage::ArticleSerializer.attribute_value(article, :subforem_id)

      ApplicationController.helpers.cloud_cover_url(main_image, subforem_id)
    end

    # Only include special title methods for status articles
    attribute :title_finalized_for_feed, if: proc { |article| article.type_of == "status" }
    attribute :title_for_metadata, if: proc { |article| article.type_of == "status" }

    attribute :user do |article|
      user = article.user

      {
        name: user.name,
        profile_image_90: user.profile_image_90,
        username: user.username
      }
    end

    attribute :organization, if: proc { |a| a.organization.present? } do |article|
      organization = article.organization

      {
        name: organization.name,
        profile_image_90: article.organization.profile_image_90,
        slug: organization.slug
      }
    end
  end
end

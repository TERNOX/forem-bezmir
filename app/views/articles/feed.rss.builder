# encoding: UTF-8

# rubocop:disable Metrics/BlockLength

xml.instruct! :xml, version: "1.0"
xml.rss(:version => "2.0",
        "xmlns:atom" => "http://www.w3.org/2005/Atom",
        "xmlns:dc" => "http://purl.org/dc/elements/1.1/",
        "xmlns:media" => "http://search.yahoo.com/mrss/") do
  xml.channel do
    if user
      xml.title "#{community_name}: #{user.name}"
      xml.description "The latest articles on #{community_name} by #{user.name} (@#{user.username})."
      xml.link app_url(user.path)
      xml.image do
        xml.url app_url(user.profile_image_90)
        xml.title "#{community_name}: #{user.name}"
        xml.link app_url(user.path)
      end
    elsif tag
      xml.title "#{community_name}: #{tag.name}"
      xml.description "The latest articles tagged '#{tag.name}' on #{community_name}."
      xml.link tag_url(tag)
      # NOTE: there exists a `tag.profile_image`, but unsure if it's in use.
      # xml.image do
      #   xml.url app_url(tag.profile_image)
      #   xml.title "#{community_name}: #{tag.name}"
      #   xml.link tag_url(tag)
      # end
    elsif latest
      xml.title "#{community_name}: Latest"
      xml.description "The most recent articles on #{community_name}."
      xml.link "#{app_url}/latest"
    else
      xml.title community_name
      xml.description "The most recent home feed on #{community_name}."
      xml.link app_url
    end
    xml.tag! "atom:link", rel: "self", type: "application/rss+xml", href: request.original_url
    xml.language "uk" # TODO: [yheuhtozr] support localized feeds (see #15136)
    articles.each do |article|
      xml.item do
        xml.title article.title
        xml.tag!("dc:creator", user.instance_of?(User) ? user.name : article.user.name)
        xml.pubDate article.published_at.to_fs(:rfc822) if article.published_at
        short_link = short_article_path(article.id)
        xml.link app_url(short_link)
        xml.guid app_url(short_link)
        xml.description sanitize(article.plain_html,
                                 tags: allowed_tags, attributes: allowed_attributes, scrubber: scrubber)
        image_url = article_social_image_url(article)
        if image_url.present?
          image_url = app_url(image_url) unless image_url.start_with?("http://", "https://")
          xml.tag!("media:content", url: image_url, medium: "image")
          xml.tag!("media:thumbnail", url: image_url)
        end
        article.tag_list.each do |tag_name|
          xml.category tag_name
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength

# Fork-only: deep-copies a voting's structure (nominations + nominees, no ballots)
# into a new unpublished voting.
module Votings
  class Cloner
    def self.call(voting)
      Voting.transaction do
        copy = voting.dup
        copy.assign_attributes(
          title: "#{voting.title} (copy)",
          slug: unique_slug("#{voting.slug}-copy"),
          published: false,
          top_level_path: false,
          results_published_at: nil,
        )
        copy[:banner_image] = nil # the file lives under the original voting's id
        copy.save!
        voting.categories.includes(:nominees).each do |category|
          new_category = copy.categories.create!(category.attributes.except("id", "voting_id", "created_at",
                                                                            "updated_at"))
          category.nominees.each do |nominee|
            new_category.nominees.create!(
              nominee.attributes.slice("game_id", "title", "subtitle", "link_url", "position"),
            )
          end
        end
        copy
      end
    end

    def self.unique_slug(base)
      slug = base
      counter = 2
      while Voting.exists?(slug: slug)
        slug = "#{base}-#{counter}"
        counter += 1
      end
      slug
    end
  end
end

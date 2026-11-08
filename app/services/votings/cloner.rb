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
        copy[:banner_image] = nil # the file lives under the original voting's id...
        copy_upload(voting.banner_image, copy, :banner_image) # ...so upload it again for the copy
        copy = save_dropping_lost_upload!(copy, :banner_image)
        voting.categories.includes(:nominees).each do |category|
          new_category = copy.categories.create!(category.attributes.except("id", "voting_id", "created_at",
                                                                            "updated_at"))
          category.nominees.each do |nominee|
            new_nominee = new_category.nominees.new(
              nominee.attributes.slice("game_id", "title", "subtitle", "link_url", "position"),
            )
            copy_upload(nominee.image, new_nominee, :image) # custom cards / cover overrides
            save_dropping_lost_upload!(new_nominee, :image)
          end
        end
        copy
      end
    end

    # Stored files live under the source record's id, so the copy gets its own
    # upload of the same file (fetched again when storage is remote).
    def self.copy_upload(uploader, record, attribute)
      return if uploader.blank?

      url = uploader.url.to_s
      if url.start_with?("http")
        record.public_send(:"remote_#{attribute}_url=", url)
      elsif uploader.path && File.exist?(uploader.path)
        record.public_send(:"#{attribute}=", File.open(uploader.path))
      end
    end

    # A file that can't be fetched again shouldn't abort the whole copy: save
    # the record without it instead. Any other validation error still raises.
    def self.save_dropping_lost_upload!(record, attribute)
      return record if record.save
      raise ActiveRecord::RecordInvalid, record unless record.errors.attribute_names == [attribute]

      record.class.create!(record.attributes.except("id", attribute.to_s))
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

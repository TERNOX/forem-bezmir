# Fork-only: shared catalog of games used as voting nominees. Filled from IGDB
# (see Igdb::Client / Games::ImportFromIgdb); images are re-hosted on our storage
# by Games::FetchImagesWorker, with the IGDB CDN as a fallback until then.
class Game < ApplicationRecord
  IGDB_IMAGE_URL = "https://images.igdb.com/igdb/image/upload/%<size>s/%<image_id>s.jpg".freeze

  mount_uploader :cover_image, GameImageUploader
  mount_uploader :artwork_image, GameImageUploader

  has_many :voting_nominees, dependent: :restrict_with_error

  validates :title, presence: true, length: { maximum: 255 }
  validates :igdb_id, uniqueness: true, allow_nil: true
  validates :release_year, numericality: { only_integer: true, in: 1950..2100 }, allow_nil: true

  scope :title_matching, lambda { |query|
    where("title ILIKE ?", "%#{sanitize_sql_like(query.to_s.strip)}%")
  }

  def self.find_by_title_ci(title)
    where("lower(title) = ?", title.to_s.strip.downcase).order(:id).first
  end

  def self.igdb_image_url(image_id, size)
    return if image_id.blank?

    format(IGDB_IMAGE_URL, size: size, image_id: image_id)
  end

  # Vertical 2:3 box art.
  def cover_url
    cover_image.url.presence || self.class.igdb_image_url(igdb_cover_image_id, "t_cover_big_2x")
  end

  # Horizontal 16:9 key art / screenshot. Falls back to the cover.
  def artwork_url
    artwork_image.url.presence ||
      self.class.igdb_image_url(igdb_artwork_image_id, "t_screenshot_huge") ||
      cover_url
  end

  def images_pending?
    (igdb_cover_image_id.present? && cover_image.blank?) ||
      (igdb_artwork_image_id.present? && artwork_image.blank?)
  end
end

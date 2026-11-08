# Fork-only: a nominee in a VotingCategory. Usually a Game from the catalog;
# can also be a custom card (title + optional image + link), e.g. a news story
# for "Найбільший прикол року" or a device for "Улюблений ігровий девайс".
class VotingNominee < ApplicationRecord
  belongs_to :category, class_name: "VotingCategory", foreign_key: :voting_category_id, inverse_of: :nominees
  belongs_to :game, optional: true
  has_many :choices, class_name: "VotingChoice", dependent: :delete_all, inverse_of: :nominee

  mount_uploader :image, VotingImageUploader

  validates :title, length: { maximum: 200 }
  validates :subtitle, length: { maximum: 200 }
  validates :link_url, length: { maximum: 500 },
                       format: { with: %r{\Ahttps?://\S+\z}i }, allow_blank: true
  validate :game_or_title_present
  validates :game_id, uniqueness: { scope: :voting_category_id }, allow_nil: true

  before_create :set_default_position

  def display_title
    title.presence || game&.title
  end

  def image_url_for(style = category&.card_style)
    return image.url if image.present?
    return unless game

    style.to_s == "artwork" ? game.artwork_url : game.cover_url
  end

  private

  def game_or_title_present
    return if game.present? || title.present?

    errors.add(:base, I18n.t("models.voting_nominee.game_or_title"))
  end

  def set_default_position
    return if position.to_i.positive? || category.nil?

    self.position = (category.nominees.maximum(:position) || -1) + 1
  end
end

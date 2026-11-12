# Fork-only: one article in the Telegram autoposting queue (and, once sent,
# its history entry). Each article is posted at most once.
class SocialAutopostItem < ApplicationRecord
  SOURCES = %w[auto manual digest].freeze
  KINDS = %w[community staff digest].freeze
  STATUSES = %w[queued sending posted skipped failed].freeze
  MAX_ATTEMPTS = 3

  belongs_to :article

  validates :source, inclusion: { in: SOURCES }
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :article_id, uniqueness: true
  validates :custom_message, length: { maximum: SocialAutopost::MessageBuilder::MAX_LENGTH }

  scope :queued, -> { where(status: "queued") }
  scope :posted, -> { where(status: "posted") }
  scope :history, -> { where(status: %w[posted skipped failed]).order(updated_at: :desc) }

  def self.ordered_queue(order = Settings::SocialAutopost.queue_order)
    article_order =
      case order
      when "oldest" then "articles.published_at ASC"
      when "newest" then "articles.published_at DESC"
      else "articles.score DESC, articles.published_at ASC"
      end

    queued
      .joins(:article)
      .order(Arel.sql("social_autopost_items.priority DESC, #{article_order}, social_autopost_items.id ASC"))
  end

  STATUSES.each do |value|
    define_method(:"#{value}?") { status == value }
  end

  # Atomically take a queued item for sending, so overlapping jobs never
  # post the same article twice.
  def claim!
    claimed = self.class.where(id: id, status: "queued").update_all(status: "sending", updated_at: Time.current)
    reload if claimed == 1
    claimed == 1
  end

  def message
    custom_message.presence || SocialAutopost::MessageBuilder.new(article, kind: kind).call
  end
end

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

  # Last autopost time of every author who has one.
  AUTHOR_TURNS_JOIN = <<~SQL.squish.freeze
    LEFT JOIN (
      SELECT posted_articles.user_id AS author_id, MAX(posted_items.posted_at) AS last_posted_at
      FROM social_autopost_items posted_items
      INNER JOIN articles posted_articles ON posted_articles.id = posted_items.article_id
      WHERE posted_items.status = 'posted'
      GROUP BY posted_articles.user_id
    ) author_turns ON author_turns.author_id = articles.user_id
  SQL

  # The order scheduled posts go out in: "To top" first, then (with
  # rotate_authors) the author who waited longest, then the queue order.
  def self.ordered_queue(order = Settings::SocialAutopost.queue_order,
                         rotate: Settings::SocialAutopost.rotate_authors)
    article_order =
      case order
      when "oldest" then "articles.published_at ASC"
      when "newest" then "articles.published_at DESC"
      else "articles.score DESC, articles.published_at ASC"
      end

    scope = queued.joins(:article)
    turn_order = ""
    if rotate
      scope = scope.joins(AUTHOR_TURNS_JOIN)
      turn_order = "author_turns.last_posted_at ASC NULLS FIRST, "
    end
    order_sql = "social_autopost_items.priority DESC, #{turn_order}#{article_order}, social_autopost_items.id ASC"
    scope.order(Arel.sql(order_sql))
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

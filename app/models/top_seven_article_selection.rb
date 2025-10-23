class TopSevenArticleSelection < ApplicationRecord
  WEEK_LENGTH = 1.week
  FREQUENCIES = %w[daily weekly biweekly monthly].freeze

  belongs_to :digest_article, class_name: "Article", optional: true

  alias_attribute :period_start, :week_of

  validates :week_of, presence: true, uniqueness: { scope: :frequency }
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES }

  scope :ordered, -> { order(week_of: :desc) }
  scope :for_frequency, ->(frequency) { where(frequency: frequency) }

  def self.for_week(week_start_date)
    ensure_for_week!(week_start_date)
  end

  def self.ensure_for_week!(week_start_date, &block)
    ensure_for_period!(frequency: "weekly", period_start: week_start_date, &block)
  end

  def self.ensure_for_period!(frequency:, period_start:, badge_slug: nil, &block)
    period_date = period_start.to_date
    selection = find_or_initialize_by(week_of: period_date, frequency: frequency)

    ids = Array(block ? block.call : []).map(&:to_i).reject(&:zero?)
    if ids.present?
      selection.article_ids = ids
      selection.badge_slug = badge_slug if badge_slug.present?
      selection.save! if selection.new_record? || selection.changed?
    elsif badge_slug.present? && selection.badge_slug != badge_slug
      selection.badge_slug = badge_slug
      selection.save!
    end

    selection
  end

  def period_range
    start_date = period_start.to_date
    end_date = period_end_date
    start_date..end_date
  end

  def week_range
    period_range
  end

  def period_label
    start_date = period_start.to_date
    end_date = period_end_date
    if start_date == end_date
      I18n.l(start_date, format: :long)
    else
      "#{I18n.l(start_date, format: :long)} – #{I18n.l(end_date, format: :long)}"
    end
  end

  def week_label
    period_label
  end

  private

  def period_end_date
    case frequency
    when "daily"
      period_start.to_date
    when "weekly"
      period_start.to_date + 6.days
    when "biweekly"
      period_start.to_date + 13.days
    when "monthly"
      (period_start.to_date + 1.month) - 1.day
    else
      period_start.to_date + 6.days
    end
  end
end

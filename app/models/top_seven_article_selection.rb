class TopSevenArticleSelection < ApplicationRecord
  WEEK_LENGTH = 1.week

  validates :week_of, presence: true, uniqueness: true

  scope :ordered, -> { order(week_of: :desc) }

  def self.for_week(week_start_date)
    week_date = week_start_date.to_date
    find_by(week_of: week_date)
  end

  def self.ensure_for_week!(week_start_date, &block)
    week_date = week_start_date.to_date
    selection = find_or_initialize_by(week_of: week_date)

    if selection.article_ids.blank?
      ids = Array(block ? block.call : []).map(&:to_i).reject(&:zero?)

      if ids.present?
        selection.article_ids = ids
        selection.save!
      end
    end

    selection
  end

  def week_range
    start_date = week_of.to_date
    start_date..(start_date + 6.days)
  end

  def week_label
    start_date = week_of.to_date
    end_date = start_date + 6.days
    "#{I18n.l(start_date, format: :long)} – #{I18n.l(end_date, format: :long)}"
  end
end

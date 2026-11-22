# Fork-only: one nomination ("Найкращий горрор") inside a Voting.
#
# * max_choices — how many nominees a voter may pick (1 = single choice).
# * ranked      — voters order their picks; place N earns rank_points[N - 1]
#                 points, or (max_choices - N + 1) when rank_points is empty.
# * rank_points — points per place for a ranked nomination (e.g. [5, 3, 1]);
#                 always [] for an unranked one. A three-place ranked nomination
#                 saved with it blank gets DEFAULT_THREE_PLACE_POINTS (5-3-1)
#                 when it is new or just became ranked / three-place; older ones
#                 left empty keep the linear 3-2-1 their votes were cast at.
# * allow_other — voters may type their own answer instead of / besides the nominees.
# * card_style  — cover (vertical 2:3 box art) or artwork (horizontal 16:9).
#
# Once anyone has voted, the structure that existing picks depend on is locked:
# `ranked` can't change, and `max_choices` can't be lowered (or changed at all
# in a ranked nomination, where it is the number of places).
class VotingCategory < ApplicationRecord
  MAX_CHOICES_LIMIT = 20
  OTHER_TEXT_MAX_LENGTH = 100
  RANK_POINTS_MAX = 1000
  DEFAULT_THREE_PLACE_POINTS = [5, 3, 1].freeze

  belongs_to :voting, inverse_of: :categories
  has_many :nominees, -> { order(:position, :id) },
           class_name: "VotingNominee", dependent: :destroy, inverse_of: :category
  has_many :choices, class_name: "VotingChoice", dependent: :delete_all, inverse_of: :category

  enum :card_style, { cover: 0, artwork: 1 }

  validates :title, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 1000 }
  validates :max_choices, numericality: { only_integer: true, in: 1..MAX_CHOICES_LIMIT }
  validate :rank_points_valid
  validate :structure_locked_once_voted, on: :update

  before_validation :clear_rank_points_unless_ranked
  before_validation :default_three_place_rank_points
  before_create :set_default_position

  # Points per place, 1st place first: the custom list, else the linear
  # max_choices..1 scale; [] for an unranked nomination.
  def rank_points_list
    return [] unless ranked?
    return rank_points if rank_points.present?

    max_choices.to_i.downto(1).to_a
  end

  # A rank that isn't a valid place (nil, 0, past the last place — e.g. votes
  # cast before the nomination became ranked) earns the lowest place's points.
  def points_for(rank)
    return 1 unless ranked?

    list = rank_points_list
    rank.to_i.between?(1, list.size) ? list[rank.to_i - 1] : list.last.to_i
  end

  # The admin form edits rank_points as "5,3,1"; blank means the linear scale
  # (5-3-1 instead for a new three-place nomination, see above).
  def rank_points_text
    @rank_points_text || rank_points.join(",")
  end

  def rank_points_text=(value)
    @rank_points_text = value.to_s.strip
    parts = @rank_points_text.split(",").map(&:strip)
    @rank_points_text_invalid = parts.any? { |part| !part.match?(/\A\d+\z/) }
    self.rank_points = parts.map(&:to_i) unless @rank_points_text_invalid
  end

  def single_choice?
    max_choices == 1 && !ranked?
  end

  # Whether anyone has picked anything here (locks the structure, see above).
  def voted?
    persisted? && choices.exists?
  end

  private

  def clear_rank_points_unless_ranked
    self.rank_points = [] if rank_points.nil?
    return if ranked?

    self.rank_points = []
    @rank_points_text_invalid = false
  end

  # Only when the nomination is new or ranked / max_choices change, so an
  # unrelated edit never moves a legacy one with empty rank_points off the 3-2-1
  # it may have been voted at (those two attributes lock once anyone votes).
  def default_three_place_rank_points
    return unless ranked? && max_choices == 3 && rank_points.blank? && !@rank_points_text_invalid
    return unless new_record? || will_save_change_to_ranked? || will_save_change_to_max_choices?

    self.rank_points = DEFAULT_THREE_PLACE_POINTS.dup
  end

  def rank_points_valid
    return unless ranked?

    if @rank_points_text_invalid
      errors.add(:rank_points, I18n.t("models.voting_category.rank_points_format"))
    elsif rank_points.present?
      validate_rank_points_list
    end
  end

  def validate_rank_points_list
    if rank_points.size != max_choices
      errors.add(:rank_points, I18n.t("models.voting_category.rank_points_count", count: max_choices))
    elsif !rank_points.all? { |points| points.is_a?(Integer) && points.between?(1, RANK_POINTS_MAX) }
      errors.add(:rank_points, I18n.t("models.voting_category.rank_points_range", max: RANK_POINTS_MAX))
    elsif rank_points.each_cons(2).any? { |higher, lower| lower > higher }
      errors.add(:rank_points, I18n.t("models.voting_category.rank_points_order"))
    end
  end

  def structure_locked_once_voted
    return unless will_save_change_to_ranked? || will_save_change_to_max_choices?
    return unless choices.exists?

    errors.add(:ranked, I18n.t("models.voting_category.ranked_locked")) if will_save_change_to_ranked?
    return unless will_save_change_to_max_choices?

    if ranked_in_database || ranked?
      errors.add(:max_choices, I18n.t("models.voting_category.max_choices_locked_ranked"))
    elsif max_choices.to_i < max_choices_in_database.to_i
      errors.add(:max_choices, I18n.t("models.voting_category.max_choices_lowered", count: max_choices_in_database))
    end
  end

  def set_default_position
    return if position.to_i.positive? || voting.nil?

    self.position = (voting.categories.maximum(:position) || -1) + 1
  end
end

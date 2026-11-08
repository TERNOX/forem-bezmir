# Fork-only: one nomination ("Найкращий горрор") inside a Voting.
#
# * max_choices — how many nominees a voter may pick (1 = single choice).
# * ranked      — voters order their picks; place N earns (max_choices - N + 1) points.
# * allow_other — voters may type their own answer instead of / besides the nominees.
# * card_style  — cover (vertical 2:3 box art) or artwork (horizontal 16:9).
class VotingCategory < ApplicationRecord
  MAX_CHOICES_LIMIT = 20
  OTHER_TEXT_MAX_LENGTH = 100

  belongs_to :voting, inverse_of: :categories
  has_many :nominees, -> { order(:position, :id) },
           class_name: "VotingNominee", dependent: :destroy, inverse_of: :category
  has_many :choices, class_name: "VotingChoice", dependent: :delete_all, inverse_of: :category

  enum :card_style, { cover: 0, artwork: 1 }

  validates :title, presence: true, length: { maximum: 150 }
  validates :description, length: { maximum: 1000 }
  validates :max_choices, numericality: { only_integer: true, in: 1..MAX_CHOICES_LIMIT }

  before_create :set_default_position

  def points_for(rank)
    return 1 unless ranked?

    [max_choices - rank.to_i + 1, 1].max
  end

  def single_choice?
    max_choices == 1 && !ranked?
  end

  private

  def set_default_position
    return if position.to_i.positive? || voting.nil?

    self.position = (voting.categories.maximum(:position) || -1) + 1
  end
end

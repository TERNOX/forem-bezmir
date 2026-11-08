# Fork-only: one pick on a VotingBallot. Either a nominee (with a rank for ranked
# categories) or a free-text "other" answer.
class VotingChoice < ApplicationRecord
  belongs_to :ballot, class_name: "VotingBallot", foreign_key: :voting_ballot_id, inverse_of: :choices
  belongs_to :category, class_name: "VotingCategory", foreign_key: :voting_category_id, inverse_of: :choices
  belongs_to :nominee, class_name: "VotingNominee", foreign_key: :voting_nominee_id, optional: true,
                       inverse_of: :choices

  validates :other_text, length: { maximum: VotingCategory::OTHER_TEXT_MAX_LENGTH }
end

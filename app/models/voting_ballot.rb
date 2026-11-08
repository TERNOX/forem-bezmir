# Fork-only: one user's answers for a Voting. Editable until the voting closes.
class VotingBallot < ApplicationRecord
  belongs_to :voting, inverse_of: :ballots
  belongs_to :user
  has_many :choices, class_name: "VotingChoice", dependent: :delete_all, inverse_of: :ballot

  mount_uploader :share_image, VotingImageUploader

  validates :user_id, uniqueness: { scope: :voting_id }

  SHARE_TOKEN_LENGTH = 16 # hex chars = 64 bits

  def self.share_secret
    @share_secret ||= Rails.application.key_generator.generate_key("voting-ballot-share")
  end

  def submitted?
    submitted_at.present?
  end

  # Unguessable part of the public "my picks" URL, so ballots can't be read by
  # walking usernames (which would leak results before they are published).
  # Derived from the app secret, so it needs no column and never changes.
  def share_token
    return if new_record?

    OpenSSL::HMAC.hexdigest("SHA256", self.class.share_secret, "voting-ballot:#{id}").first(SHARE_TOKEN_LENGTH)
  end

  def valid_share_token?(token)
    token.present? && share_token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(token.to_s, share_token)
  end
end

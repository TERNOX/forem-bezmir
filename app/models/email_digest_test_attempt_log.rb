class EmailDigestTestAttemptLog < ApplicationRecord
  LEVELS = %w[info warn error].freeze

  belongs_to :attempt,
             class_name: "EmailDigestTestAttempt",
             foreign_key: :email_digest_test_attempt_id,
             inverse_of: :logs

  validates :level, inclusion: { in: LEVELS }
  validates :message, presence: true

  scope :chronological, -> { order(created_at: :asc) }

  def level
    super || "info"
  end
end

class EmailDigestTestAttempt < ApplicationRecord
  STATUSES = {
    queued: "queued",
    sent: "sent",
    skipped: "skipped",
    failed: "failed"
  }.freeze

  enum status: STATUSES, _suffix: true

  belongs_to :user

  validates :status, inclusion: { in: STATUSES.values }

  scope :recent_first, -> { order(created_at: :desc) }

  def mark_sent!
    update!(status: :sent, error_message: nil)
  end

  def mark_skipped!(reason)
    update!(status: :skipped, error_message: reason)
  end

  def mark_failed!(error, honeybadger_id = nil)
    update!(
      status: :failed,
      error_message: error.is_a?(String) ? error : error&.message,
      honeybadger_id: honeybadger_id,
    )
  end

  def status_label
    status.to_s
  end

  def display_timestamp
    updated_at || created_at
  end

  def display_email
    user&.email
  end
end

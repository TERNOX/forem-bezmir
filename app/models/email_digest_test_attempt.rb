class EmailDigestTestAttempt < ApplicationRecord
  STATUSES = {
    queued: "queued",
    sent: "sent",
    skipped: "skipped",
    failed: "failed"
  }.freeze

  enum status: STATUSES, _suffix: true

  belongs_to :user
  has_many :logs,
           class_name: "EmailDigestTestAttemptLog",
           foreign_key: :email_digest_test_attempt_id,
           inverse_of: :attempt,
           dependent: :destroy

  validates :status, inclusion: { in: STATUSES.values }

  scope :recent_first, -> { order(created_at: :desc) }

  def mark_sent!(note = nil)
    update!(status: :sent, error_message: nil, status_note: note)
  end

  def mark_skipped!(reason, note: nil)
    update!(status: :skipped, error_message: reason, status_note: note)
  end

  def mark_failed!(error, honeybadger_id = nil)
    update!(
      status: :failed,
      error_message: error.is_a?(String) ? error : error&.message,
      status_note: nil,
      honeybadger_id: honeybadger_id,
    )
  end

  def append_note!(note)
    update!(status_note: note)
  end

  def log_event(level, message, context = {})
    logs.create!(level: level.to_s, message: message, context: context || {})
  rescue StandardError => e
    Rails.logger.warn("Failed to log digest test attempt event: #{e.class}: #{e.message}")
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

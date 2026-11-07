class EmailDigest
  STATEMENT_TIMEOUT = ENV.fetch("EMAIL_DIGEST_STATEMENT_TIMEOUT", 60_000).to_i.seconds / 1_000.to_f

  def self.send_periodic_digest_email(users = [], starting_id = 1, ending_id = 50_000_000)
    new(users, starting_id, ending_id).send_periodic_digest_email
  end

  def initialize(users = [], starting_id = 1, ending_id = 50_000_000)
    @users = users.empty? ? get_users(starting_id, ending_id) : users
  end

  def send_periodic_digest_email
    return unless Settings::SMTP.automatic_digests_enabled

    ApplicationRecord.with_statement_timeout(STATEMENT_TIMEOUT) do
      @users.select(:id).in_batches do |batch|
        batch.each do |user|
          Emails::SendUserDigestWorker.perform_async(user.id)
        rescue StandardError => e
          Honeybadger.notify(e)
        end
      end
    end
  end

  private

  def get_users(starting_id, ending_id)
    excluded_role_user_ids = UserRole.joins(:role)
      .where(roles: { name: %i[suspended spam] })
      .select(:user_id)

    User.registered.joins(:notification_setting)
      .where(notification_setting: { email_digest_periodic: true })
      .where.not(email: "")
      .where.not(id: excluded_role_user_ids)
      .where("users.id >= ? AND users.id <= ?", starting_id, ending_id)
  end
end

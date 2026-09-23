class EmailDigest
  def self.send_periodic_digest_email(users = [], starting_id = 1, ending_id = 50_000_000)
    new(users, starting_id, ending_id).send_periodic_digest_email
  end

  def initialize(users = [], starting_id = 1, ending_id = 50_000_000)
    @users = users.empty? ? get_users(starting_id, ending_id) : users
  end

  def send_periodic_digest_email
    return unless Settings::SMTP.automatic_digests_enabled

    @users.select(:id).in_batches do |batch|
      batch.each do |user|
        Emails::SendUserDigestWorker.perform_async(user.id)
      rescue StandardError => e
        Honeybadger.notify(e)
      end
    end
  end

  private

  def get_users(starting_id, ending_id)
    User.registered.joins(:notification_setting)
      .where(notification_setting: { email_digest_periodic: true })
      .where.not(email: "")
      .where("users.id >= ? AND users.id <= ?", starting_id, ending_id)
  end
end

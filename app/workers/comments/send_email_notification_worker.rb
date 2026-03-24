module Comments
  class SendEmailNotificationWorker
    include Sidekiq::Job

    sidekiq_options queue: :mailers

    def perform(comment_id)
      comment = Comment.find_by(id: comment_id)
      return unless comment && comment.score > -1

      parent_user = comment.parent_user
      if parent_user.nil? || parent_user.email.blank?
        Rails.logger.info("SendEmailNotificationWorker skipped: missing parent user or email for comment ##{comment.id}")
        return
      end

      NotifyMailer.with(comment: comment).new_reply_email.deliver_now
    rescue ArgumentError => e
      raise unless e.message.include?("SMTP To address may not be blank")
    end
  end
end

module SocialAutopost
  # Fork-only: sends one queued item right away (the weekly digest, or an
  # admin's "post now"), outside the regular schedule.
  class PostItemWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: false

    def perform(item_id)
      return unless SocialAutopost.configured?

      item = SocialAutopostItem.find_by(id: item_id)
      return unless item&.queued?

      SocialAutopost::Poster.call(item)
    end
  end
end

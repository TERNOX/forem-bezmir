# Fork-only: (re)builds a ballot's share image after it is submitted or after
# an admin rewrote its picks.
#
# A render can come back without drawing anything: another render holds the
# ballot's lock (it may be a stale one that will drop its result), the ballot
# is cooling down after a failed render, or the picks changed while drawing.
# Then the job tries again later, up to MAX_ATTEMPTS times in all, so the
# ballot doesn't stay without an image. A render that raises goes through
# Sidekiq's own retries instead.
#
# The attempt number is part of the job's arguments, so the next attempt has
# its own uniqueness digest; with lock: :until_executing this job's lock is
# released as soon as it starts anyway.
module Votings
  class GenerateShareImageWorker
    include Sidekiq::Job

    MAX_ATTEMPTS = 4
    # Long enough for a render's lock (GenerateShareImage::LOCK_TTL) or its
    # failure cooldown to have passed within the attempts.
    RETRY_DELAY = 2.minutes

    sidekiq_options queue: :low_priority, retry: 3, lock: :until_executing

    def perform(ballot_id, attempt = 1)
      ballot = VotingBallot.find_by(id: ballot_id)
      return unless ballot&.submitted?
      return if ballot.share_image.present? # already drawn on demand by the image endpoint
      return if Votings::GenerateShareImage.call(ballot)
      return if attempt.to_i >= MAX_ATTEMPTS

      ballot = VotingBallot.find_by(id: ballot_id)
      return unless ballot&.submitted? && ballot.share_image.blank?

      self.class.perform_in(RETRY_DELAY, ballot_id, attempt.to_i + 1)
    end
  end
end

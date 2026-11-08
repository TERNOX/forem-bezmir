# Fork-only: (re)builds a ballot's share image after it is submitted.
module Votings
  class GenerateShareImageWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: 3, lock: :until_executing

    def perform(ballot_id)
      ballot = VotingBallot.find_by(id: ballot_id)
      return unless ballot&.submitted?
      return if ballot.share_image.present? # already drawn on demand by the image endpoint

      Votings::GenerateShareImage.call(ballot)
    end
  end
end

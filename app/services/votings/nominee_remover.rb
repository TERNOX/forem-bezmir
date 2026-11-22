# Fork-only: removes a nominee from its nomination, votes included, without
# leaving holes in ranked ballots. In a ranked nomination the remaining picks
# of every ballot that had the nominee move up (a ballot "X, B, C" without X
# becomes B = 1st, C = 2nd), so nobody's first place silently disappears.
#
# Each affected ballot's share images showed the removed pick, so they are
# dropped and queued for a re-render, like a re-submitted ballot (see
# Votings::BallotSubmitter#persist); every affected ballot's updated_at moves,
# so a render already in flight with the old picks is not stored.
#
# Deleting a whole nomination does not go through here (its ballots lose the
# nomination entirely, there is nothing to renumber).
module Votings
  class NomineeRemover
    def self.call(...)
      new(...).call
    end

    def initialize(nominee)
      @nominee = nominee
      @category = nominee.category
    end

    # @return [Integer] how many ballots had the nominee
    def call
      ballots_with_image = []
      ballot_ids = []
      VotingNominee.transaction do
        # Hold the affected ballots so a voter re-submitting meanwhile waits
        # for (and then fully replaces) the renumbered picks.
        ballots = VotingBallot.where(id: nominee.choices.select(:voting_ballot_id)).order(:id).lock.to_a
        ballot_ids = ballots.map(&:id)
        ballots_with_image = ballots.select do |ballot|
          ballot.share_image.present? || ballot.share_preview_image.present?
        end
        nominee.destroy!
        renumber_ranks(ballot_ids) if category.ranked? && ballot_ids.any?
        # Bumping updated_at on every affected ballot (not only those with an
        # image) makes a render that already read the old picks drop its
        # result (Votings::GenerateShareImage#store).
        VotingBallot.where(id: ballot_ids).update_all(share_image: nil, share_preview_image: nil,
                                                      updated_at: Time.current)
      end

      # The files go only once the transaction is committed, so a rollback
      # never leaves a ballot pointing at a deleted image.
      ballots_with_image.each do |ballot|
        ballot.share_image.remove!
        ballot.share_preview_image.remove!
      end
      ballot_ids.each { |ballot_id| Votings::GenerateShareImageWorker.perform_async(ballot_id) }
      ballot_ids.size
    end

    private

    attr_reader :nominee, :category

    # One statement for all ballots: renumber each ballot's ranked nominee
    # picks in this nomination 1..n, keeping their order. Picks without a rank
    # (cast before the nomination became ranked) and "other" answers keep theirs.
    def renumber_ranks(ballot_ids)
      numbered = VotingChoice
        .where(voting_category_id: category.id, voting_ballot_id: ballot_ids)
        .where.not(voting_nominee_id: nil)
        .where.not(rank: nil)
        .select(:id, "ROW_NUMBER() OVER (PARTITION BY voting_ballot_id ORDER BY rank, id) AS new_rank")

      VotingChoice.connection.exec_update(<<~SQL.squish, "Votings::NomineeRemover renumber")
        UPDATE voting_choices
        SET rank = numbered.new_rank, updated_at = #{VotingChoice.connection.quote(Time.current)}
        FROM (#{numbered.to_sql}) AS numbered
        WHERE voting_choices.id = numbered.id AND voting_choices.rank <> numbered.new_rank
      SQL
    end
  end
end

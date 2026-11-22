# Fork-only: counts a nomination's free-text "other" answer as one of its
# nominees, on every ballot that gave it (counted or not: Votings::Results
# decides eligibility at count time). Irreversible: the answers become ordinary
# nominee picks.
#
# The text is matched the way Votings::Results groups the "other" answers
# (lower(trim(other_text))), so the line the admin acts on is exactly what is
# merged. On each ballot with the answer:
#
# * the ballot already picked the nominee here -> the answer is deleted, so the
#   voter is not counted twice;
# * otherwise it becomes a pick of the nominee; in a ranked nomination it takes
#   the place after the ballot's last ranked pick (the voter never placed the
#   write-in, so it goes last: 1, 2 + other -> 3; only the other answer -> 1).
#
# Affected ballots' share images are dropped and re-queued the same way as in
# Votings::NomineeRemover.
module Votings
  class OtherAnswerMerger
    Result = Struct.new(:merged, :dropped, keyword_init: true) do
      def total
        merged + dropped
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(category:, text:, nominee:)
      raise ArgumentError, "the nominee is not in this nomination" unless nominee.voting_category_id == category.id

      @category = category
      @text = text.to_s
      @nominee = nominee
    end

    # @return [Result] merged: answers turned into picks of the nominee;
    #   dropped: answers deleted because the ballot already had the nominee.
    def call
      return Result.new(merged: 0, dropped: 0) if text.strip.empty?

      result = nil
      ballots_with_image = []
      ballot_ids = []
      VotingChoice.transaction do
        # Hold the ballots so a voter re-submitting meanwhile waits for (and
        # then fully replaces) the merged picks.
        ballots = VotingBallot.where(id: answers.select(:voting_ballot_id)).order(:id).lock.to_a
        ballot_ids = ballots.map(&:id)
        ballots_with_image = ballots.select { |ballot| ballot.share_image.present? }
        result = merge(ballot_ids)
        # Bumping updated_at on every affected ballot (not only those with an
        # image) makes a render that already read the old picks drop its
        # result (Votings::GenerateShareImage#store).
        VotingBallot.where(id: ballot_ids).update_all(share_image: nil, updated_at: Time.current)
      end

      # The files go only once the transaction is committed, so a rollback
      # never leaves a ballot pointing at a deleted image.
      ballots_with_image.each { |ballot| ballot.share_image.remove! }
      ballot_ids.each { |ballot_id| Votings::GenerateShareImageWorker.perform_async(ballot_id) }
      result
    end

    private

    attr_reader :category, :text, :nominee

    def answers
      VotingChoice.where(voting_category_id: category.id, voting_nominee_id: nil)
        .where("lower(trim(voting_choices.other_text)) = lower(trim(?))", text)
    end

    def merge(ballot_ids)
      return Result.new(merged: 0, dropped: 0) if ballot_ids.empty?

      locked = answers.where(voting_ballot_id: ballot_ids)
      already_picked = VotingChoice.where(voting_category_id: category.id, voting_nominee_id: nominee.id)
        .select(:voting_ballot_id)
      dropped = locked.where(voting_ballot_id: already_picked).delete_all
      merged = locked.update_all(merge_assignments)
      Result.new(merged: merged, dropped: dropped)
    end

    # The SET subquery reads the table as it was before this statement, and a
    # ballot holds at most one "other" answer per nomination, so the new rank
    # never collides with another merged answer of the same ballot.
    def merge_assignments
      rank_sql = if category.ranked?
                   VotingChoice.sanitize_sql_array([<<~SQL.squish, category.id])
                     COALESCE((SELECT MAX(picks.rank) FROM voting_choices picks
                               WHERE picks.voting_ballot_id = voting_choices.voting_ballot_id
                                 AND picks.voting_category_id = ?
                                 AND picks.voting_nominee_id IS NOT NULL), 0) + 1
                   SQL
                 else
                   "NULL"
                 end
      VotingChoice.sanitize_sql_array(
        ["voting_nominee_id = ?, other_text = NULL, rank = #{rank_sql}, updated_at = ?", nominee.id, Time.current],
      )
    end
  end
end

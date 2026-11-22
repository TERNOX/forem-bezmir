# Fork-only: tallies a voting. Only submitted ballots of users who still pass
# the voter rules count (see #counted_ballot_ids). Ranked categories score VotingCategory#points_for(rank)
# per pick (rank_points, or max_choices..1); other categories score 1 point per pick.
#
# Rows are ordered by points, then first places, then votes. Rows equal on all
# three share a place (1, 1, 3, ...); the winners are the rows with place 1. A
# nominee nobody voted for has no place.
module Votings
  class Results
    Row = Struct.new(:nominee, :points, :votes, :firsts, :place, keyword_init: true) do
      def tie_key
        [points, firsts, votes]
      end
    end
    CategoryResult = Struct.new(:category, :rows, :other_answers, :voters, keyword_init: true) do
      def max_points
        rows.map(&:points).max.to_i
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(voting)
      @voting = voting
    end

    # @return [Hash] { ballots_count:, submitted_count:, categories: [CategoryResult] }
    #   ballots_count: submitted ballots that pass the voter rules (the ones
    #   tallied); submitted_count: every submitted ballot.
    def call
      ballot_ids = counted_ballot_ids
      scope = VotingChoice.where(voting_ballot_id: ballot_ids)
      tallies = index_tallies(
        scope.where.not(voting_nominee_id: nil).group(:voting_category_id, :voting_nominee_id, :rank).count,
      )
      others = scope.where(voting_nominee_id: nil).where.not(other_text: [nil, ""])
        .group(:voting_category_id, Arel.sql("lower(trim(other_text))")).count
      voters = scope.group(:voting_category_id).distinct.count(:voting_ballot_id)

      categories = @voting.categories.includes(nominees: :game).map do |category|
        build_category(category, tallies, others, voters)
      end
      { ballots_count: ballot_ids.size, submitted_count: @voting.submitted_ballots.count, categories: categories }
    end

    private

    # The same voter rules as Votings::Eligibility, applied at counting time, so
    # accounts restricted or pushed below the score floor after voting drop out.
    def counted_ballot_ids
      restricted_user_ids = User.joins(:roles).where(roles: { name: %w[spam suspended] }).select(:id)
      voters = User.where.not(confirmed_at: nil)
        .where("COALESCE(users.score, 0) >= ?", @voting.min_user_score)
        .where.not(id: restricted_user_ids)
        .where.not("users.username LIKE ?", "spam\\_%")
      if @voting.require_account_before_start? && @voting.opens_at.present?
        voters = voters.where(created_at: ...@voting.opens_at)
      end
      @voting.submitted_ballots.where(user_id: voters.select(:id)).ids
    end

    # { [category_id, nominee_id] => [[rank, count], ...] }, so each nominee
    # only walks its own tallies.
    def index_tallies(counts)
      counts.each_with_object({}) do |((category_id, nominee_id, rank), count), index|
        (index[[category_id, nominee_id]] ||= []) << [rank, count]
      end
    end

    def build_category(category, tallies, others, voters)
      rows = category.nominees.map do |nominee|
        row = Row.new(nominee: nominee, points: 0, votes: 0, firsts: 0)
        tallies.fetch([category.id, nominee.id], []).each do |rank, count|
          row.votes += count
          row.points += category.points_for(rank) * count
          row.firsts += count if rank == 1
        end
        row
      end
      rows.sort_by! { |row| [-row.points, -row.firsts, -row.votes, row.nominee.position] }
      assign_places(rows)

      other_answers = others.filter_map { |(category_id, text), count| [text, count] if category_id == category.id }
        .sort_by { |text, count| [-count, text] }
      CategoryResult.new(category: category, rows: rows, other_answers: other_answers,
                         voters: voters[category.id].to_i)
    end

    # Standard competition numbering over the sorted rows: tied rows share the
    # place of the first of them and the next row skips ahead (1, 1, 3).
    def assign_places(rows)
      rows.each_with_index do |row, index|
        next if row.votes.zero?

        previous = rows[index - 1] if index.positive?
        row.place = previous&.place && previous.tie_key == row.tie_key ? previous.place : index + 1
      end
    end
  end
end

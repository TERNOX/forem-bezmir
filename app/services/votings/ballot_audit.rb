# Fork-only: the admin ballot audit (Admin::VotingBallotsController#index), for
# spotting ballot stuffing with throwaway accounts. For every submitted ballot it
# reports whether the ballot is counted (and if not, why) and a few plain account
# signals. It never exposes what a ballot voted for: "identical picks" is only a
# count of other ballots with the same picks.
#
# Assumes a voting has hundreds to a few thousand ballots: all of them are
# loaded with their voters (and roles) and picks in a fixed number of queries,
# the signals are computed in memory, and the caller paginates the sorted rows.
module Votings
  class BallotAudit
    # Why a ballot is not counted, in the order they are checked.
    REASONS = %i[disqualified unconfirmed restricted low_score account_too_new].freeze
    REASON_LABELS = {
      disqualified: "disqualified",
      unconfirmed: "unconfirmed",
      restricted: "restricted",
      low_score: "low score",
      account_too_new: "account too new"
    }.freeze
    SIGNALS = %i[joined_after_opening new_account no_activity shared_ip identical_picks].freeze
    NEW_ACCOUNT_WINDOW = 24.hours
    # Smaller ballots match by chance too often to mean anything.
    IDENTICAL_PICKS_MIN_CHOICES = 3

    # reason: nil when counted, otherwise one of REASONS.
    # signals: { signal => true, or the number of other voters/ballots }, only
    # the signals that apply, in SIGNALS order.
    Row = Struct.new(:ballot, :user, :reason, :signals, keyword_init: true) do
      def counted?
        reason.nil?
      end

      def signals?
        signals.any?
      end
    end

    # rows: sorted (most signals first, then newest), filtered when only_signals.
    # The counts always cover every submitted ballot. not_counted: { reason => count }
    # for every reason in REASONS.
    Report = Struct.new(:rows, :submitted_count, :counted_count, :not_counted, :flagged_count, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def self.reason_label(reason)
      REASON_LABELS.fetch(reason)
    end

    def self.signal_label(signal, value)
      case signal
      when :joined_after_opening then "Joined after the voting opened"
      when :new_account then "Account under 24h old when voting"
      when :no_activity then "No posts, comments or reactions"
      when :shared_ip then "Sign-in IP shared with #{value} other #{'voter'.pluralize(value)}"
      when :identical_picks then "Same picks as #{value} other #{'ballot'.pluralize(value)}"
      else raise ArgumentError, "unknown signal #{signal.inspect}"
      end
    end

    def initialize(voting, only_signals: false)
      @voting = voting
      @only_signals = only_signals
    end

    def call
      ballots = @voting.submitted_ballots.includes(user: :roles).to_a
      shared_ips = shared_ip_counts(ballots)
      identical_picks = identical_pick_counts(ballots)

      rows = ballots.map do |ballot|
        Row.new(ballot: ballot, user: ballot.user, reason: reason_for(ballot),
                signals: signals_for(ballot, shared_ips[ballot.id], identical_picks[ballot.id]))
      end
      rows.sort_by! { |row| [-row.signals.size, -row.ballot.submitted_at.to_f, -row.ballot.id] }

      not_counted = rows.reject(&:counted?).group_by(&:reason).transform_values(&:size)
      Report.new(
        rows: @only_signals ? rows.select(&:signals?) : rows,
        submitted_count: rows.size,
        counted_count: rows.count(&:counted?),
        not_counted: REASONS.index_with { |reason| not_counted.fetch(reason, 0) },
        flagged_count: rows.count(&:signals?),
      )
    end

    private

    # Must agree with Results#counted_ballot_ids (see the consistency spec).
    def reason_for(ballot)
      return :disqualified if ballot.disqualified?

      Votings::Eligibility.user_reason(@voting, ballot.user)
    end

    def signals_for(ballot, shared_ip_count, identical_count)
      user = ballot.user
      signals = {}
      signals[:joined_after_opening] = true if @voting.opens_at.present? && user.created_at >= @voting.opens_at
      # created_at is when the ballot was first sent; submitted_at moves on
      # every edit, which would let a throwaway account lose the signal.
      signals[:new_account] = true if ballot.created_at - user.created_at < NEW_ACCOUNT_WINDOW
      if [user.articles_count, user.comments_count, user.reactions_count].all? { |count| count.to_i.zero? }
        signals[:no_activity] = true
      end
      signals[:shared_ip] = shared_ip_count if shared_ip_count.to_i.positive?
      signals[:identical_picks] = identical_count if identical_count.to_i.positive?
      signals
    end

    # { ballot_id => number of other voters of this voting whose current or
    # last sign-in IP is one of this voter's }. The addresses stay here.
    def shared_ip_counts(ballots)
      user_ids_by_ip = Hash.new { |hash, ip| hash[ip] = Set.new }
      ballots.each { |ballot| sign_in_ips(ballot.user).each { |ip| user_ids_by_ip[ip] << ballot.user_id } }

      ballots.to_h do |ballot|
        others = sign_in_ips(ballot.user).each_with_object(Set.new) { |ip, ids| ids.merge(user_ids_by_ip[ip]) }
        others.delete(ballot.user_id)
        [ballot.id, others.size]
      end
    end

    def sign_in_ips(user)
      [user.current_sign_in_ip, user.last_sign_in_ip].compact.map(&:to_s).uniq
    end

    # { ballot_id => number of other ballots with exactly the same picks }, for
    # ballots with at least IDENTICAL_PICKS_MIN_CHOICES picks. A pick is its
    # category, nominee, rank and normalised "other" text; the fingerprints
    # never leave this method.
    def identical_pick_counts(ballots)
      picks = VotingChoice.where(voting_ballot_id: ballots.map(&:id))
        .pluck(:voting_ballot_id, :voting_category_id, :voting_nominee_id, :rank, :other_text)
        .group_by(&:first)

      fingerprints = picks.filter_map do |ballot_id, choices|
        next if choices.size < IDENTICAL_PICKS_MIN_CHOICES

        fingerprint = choices.map do |_, category_id, nominee_id, rank, other_text|
          [category_id, nominee_id, rank, other_text.to_s.strip.downcase].to_json
        end
        [ballot_id, fingerprint.sort]
      end.to_h
      sizes = fingerprints.values.tally
      fingerprints.transform_values { |fingerprint| sizes[fingerprint] - 1 }
    end
  end
end

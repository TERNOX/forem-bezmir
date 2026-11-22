# Fork-only: can this user vote in this voting right now?
#
# Voters need a confirmed email, must not be spam/suspended/banished, and need a
# user score of at least voting.min_user_score (0 by default: new accounts are
# fine, accounts pushed negative by flags/vomits are not). Optionally the account
# must predate the voting's opening.
module Votings
  class Eligibility
    REASONS = %i[draft upcoming closed sign_in unconfirmed restricted low_score account_too_new].freeze

    attr_reader :reason

    def self.call(...)
      new(...)
    end

    # Spam, suspended or banished: such members can't vote, and their public
    # "my picks" pages are hidden too (VotingBallotsController).
    def self.restricted_user?(user)
      user.spam_or_suspended? || user.banished?
    end

    # The member-level voter rules alone, whatever the voting's state (draft,
    # open or closed): nil when the member passes them, otherwise :unconfirmed,
    # :restricted, :low_score or :account_too_new. Results#counted_ballot_ids
    # applies the same rules in SQL; Votings::BallotAudit uses this per ballot
    # (with roles preloaded), and a spec keeps the two in agreement.
    def self.user_reason(voting, user)
      return :unconfirmed unless user.confirmed?
      return :restricted if restricted_user?(user)
      return :low_score if user.score.to_i < voting.min_user_score
      return :account_too_new if account_too_new?(voting, user)

      nil
    end

    def self.account_too_new?(voting, user)
      voting.require_account_before_start? && voting.opens_at.present? && user.created_at >= voting.opens_at
    end

    def initialize(voting, user, now: Time.current)
      @voting = voting
      @user = user
      @now = now
      @reason = compute_reason
    end

    def eligible?
      reason.nil?
    end

    private

    attr_reader :voting, :user, :now

    def compute_reason
      return :draft unless voting.published?
      return :upcoming if voting.upcoming?(now)
      return :closed if voting.closed?(now)
      return :sign_in unless user

      self.class.user_reason(voting, user)
    end
  end
end

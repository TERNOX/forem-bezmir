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
      return :unconfirmed unless user.confirmed?
      return :restricted if user.spam_or_suspended? || user.banished?
      return :low_score if user.score.to_i < voting.min_user_score
      return :account_too_new if account_too_new?

      nil
    end

    def account_too_new?
      voting.require_account_before_start? && voting.opens_at.present? && user.created_at >= voting.opens_at
    end
  end
end

require "rails_helper"

RSpec.describe Votings::BallotAudit do
  let(:voting) { create(:voting, opens_at: 3.days.ago) }
  let(:category) { create(:voting_category, voting: voting, max_choices: 3, ranked: true) }
  let(:extra) { create(:voting_category, voting: voting, max_choices: 1, allow_other: true) }
  let!(:nominees) { create_list(:voting_nominee, 4, category: category) }

  # An established, active member: no signals of their own.
  def member(**attrs)
    create(:user, created_at: 1.month.ago).tap do |user|
      user.update_columns(articles_count: 1, **attrs)
    end
  end

  def ballot_for(user, nominee_ids = [nominees.first.id], other: nil, **attrs)
    create(:voting_ballot, voting: voting, user: user, **attrs).tap do |ballot|
      nominee_ids.each_with_index do |nominee_id, index|
        VotingChoice.create!(ballot: ballot, category: category, voting_nominee_id: nominee_id, rank: index + 1)
      end
      VotingChoice.create!(ballot: ballot, category: extra, other_text: other) if other
    end
  end

  def row_for(report, ballot)
    report.rows.detect { |row| row.ballot == ballot }
  end

  def audit(**options)
    described_class.call(voting, **options)
  end

  describe "statuses" do
    let!(:ballots) do
      voting.update!(require_account_before_start: true)
      {
        counted: ballot_for(member),
        unconfirmed: ballot_for(member(confirmed_at: nil)),
        spam: ballot_for(create(:user, :spam, created_at: 1.month.ago)),
        suspended: ballot_for(create(:user, :suspended, created_at: 1.month.ago)),
        banished: ballot_for(member.tap { |user| user.update_column(:username, "spam_#{user.id}") }),
        low_score: ballot_for(member(score: -5)),
        too_new: ballot_for(create(:user, created_at: 1.day.ago)),
        disqualified: ballot_for(member, disqualified_at: Time.current),
        disqualified_low_score: ballot_for(member(score: -5), disqualified_at: Time.current)
      }
    end

    it "gives every ballot its reason, disqualification first" do
      report = audit
      reasons = ballots.transform_values { |ballot| row_for(report, ballot).reason }
      expect(reasons).to eq(
        counted: nil, unconfirmed: :unconfirmed, spam: :restricted, suspended: :restricted,
        banished: :restricted, low_score: :low_score, too_new: :account_too_new,
        disqualified: :disqualified, disqualified_low_score: :disqualified
      )
    end

    it "marks exactly the ballots Results counts as counted" do
      counted = audit.rows.filter_map { |row| row.ballot.id if row.counted? }

      expect(counted).to match_array(Votings::Results.new(voting).counted_ballot_ids)
      expect(counted).to eq([ballots[:counted].id])
    end

    it "totals submitted, counted and not counted ballots by reason" do
      create(:voting_ballot, voting: voting, submitted_at: nil) # started, never sent

      report = audit
      expect(report.submitted_count).to eq(9)
      expect(report.counted_count).to eq(1)
      expect(report.not_counted).to eq(disqualified: 2, unconfirmed: 1, restricted: 3, low_score: 1,
                                       account_too_new: 1)
    end
  end

  describe "signals" do
    it "reports none for an established, active member" do
      ballot = ballot_for(member)
      expect(row_for(audit, ballot).signals).to eq({})
    end

    it "flags accounts created after the voting opened, even without the account age rule" do
      user = member
      user.update_column(:created_at, 2.days.ago)
      ballot = ballot_for(user)
      expect(row_for(audit, ballot).signals).to eq(joined_after_opening: true)
    end

    it "does not flag the opening when the voting has no opening time" do
      voting.update!(opens_at: nil)
      user = member
      user.update_column(:created_at, 2.days.ago)
      ballot = ballot_for(user)
      expect(row_for(audit, ballot).signals).not_to have_key(:joined_after_opening)
    end

    it "flags accounts under 24 hours old when they first voted" do
      user = member
      user.update_column(:created_at, 30.hours.ago)
      quick = ballot_for(user, created_at: 10.hours.ago, submitted_at: 1.hour.ago) # created 20h before the vote
      expect(row_for(audit, quick).signals).to include(new_account: true)

      slow = ballot_for(member.tap { |other| other.update_column(:created_at, 30.hours.ago) },
                        created_at: 2.hours.ago)
      expect(row_for(audit, slow).signals).not_to have_key(:new_account)
    end

    it "flags members without posts, comments or reactions" do
      idle = ballot_for(member(articles_count: 0))
      commenter = ballot_for(member(articles_count: 0, comments_count: 2))
      reactor = ballot_for(member(articles_count: 0, reactions_count: 1))

      report = audit
      expect(row_for(report, idle).signals).to eq(no_activity: true)
      expect(row_for(report, commenter).signals).to eq({})
      expect(row_for(report, reactor).signals).to eq({})
    end

    it "counts the other voters sharing a current or last sign-in IP" do
      first = ballot_for(member(current_sign_in_ip: "10.0.0.1", last_sign_in_ip: "10.0.0.2"))
      second = ballot_for(member(current_sign_in_ip: "10.0.0.2"))
      third = ballot_for(member(last_sign_in_ip: "10.0.0.1"))
      alone = ballot_for(member(current_sign_in_ip: "10.0.0.9", last_sign_in_ip: "10.0.0.9"))
      no_ip = ballot_for(member)
      # A non-voter on the same IP does not count.
      create(:user, current_sign_in_ip: "10.0.0.9")

      report = audit
      expect(row_for(report, first).signals).to eq(shared_ip: 2)
      expect(row_for(report, second).signals).to eq(shared_ip: 1)
      expect(row_for(report, third).signals).to eq(shared_ip: 1)
      expect(row_for(report, alone).signals).to eq({})
      expect(row_for(report, no_ip).signals).to eq({})
    end

    it "counts other ballots with the same picks, only for ballots with at least 3 picks" do
      ids = nominees.first(3).map(&:id)
      first = ballot_for(member, ids)
      second = ballot_for(member, ids)
      # The same picks with the "other" text written differently.
      with_other = ballot_for(member, ids.first(2), other: "Steam Deck")
      with_other_again = ballot_for(member, ids.first(2), other: " steam deck")
      reordered = ballot_for(member, ids.reverse) # different ranks
      small = ballot_for(member, ids.first(2))
      small_again = ballot_for(member, ids.first(2))

      report = audit
      expect(row_for(report, first).signals).to eq(identical_picks: 1)
      expect(row_for(report, second).signals).to eq(identical_picks: 1)
      expect(row_for(report, with_other).signals).to eq(identical_picks: 1)
      expect(row_for(report, with_other_again).signals).to eq(identical_picks: 1)
      expect(row_for(report, reordered).signals).to eq({})
      expect(row_for(report, small).signals).to eq({})
      expect(row_for(report, small_again).signals).to eq({})
    end

    it "labels counts in the signals without the addresses or picks" do
      expect(described_class.signal_label(:shared_ip, 1)).to eq("Sign-in IP shared with 1 other voter")
      expect(described_class.signal_label(:identical_picks, 3)).to eq("Same picks as 3 other ballots")
    end
  end

  describe "order and filter" do
    let!(:clean_old) { ballot_for(member, submitted_at: 2.days.ago) }
    let!(:clean_new) { ballot_for(member, submitted_at: 1.hour.ago) }
    let!(:one_signal) { ballot_for(member(articles_count: 0), submitted_at: 2.days.ago) }
    let!(:two_signals) do
      user = member(articles_count: 0)
      user.update_column(:created_at, 2.days.ago) # after the opening, but not under 24h before voting
      ballot_for(user, submitted_at: 3.hours.ago)
    end

    it "puts the ballots with the most signals first, then the newest" do
      expect(audit.rows.map(&:ballot)).to eq([two_signals, one_signal, clean_new, clean_old])
    end

    it "can show only the ballots with signals, keeping the totals for all" do
      report = audit(only_signals: true)
      expect(report.rows.map(&:ballot)).to eq([two_signals, one_signal])
      expect(report).to have_attributes(submitted_count: 4, flagged_count: 2)
    end
  end

  it "loads the voting's ballots in a fixed number of queries" do
    count_queries = lambda do
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { audit.rows.each(&:signals) }
      queries
    end

    picks = nominees.first(3).map(&:id)
    # One member with a role, so the baseline already includes loading roles.
    ballot_for(create(:user, :spam, current_sign_in_ip: "10.0.0.1"), picks)
    baseline = count_queries.call
    3.times { ballot_for(member(current_sign_in_ip: "10.0.0.1"), picks) }
    2.times { ballot_for(create(:user, :suspended, current_sign_in_ip: "10.0.0.2"), picks) }

    expect(count_queries.call).to eq(baseline)
  end
end

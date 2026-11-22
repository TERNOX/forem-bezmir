module Admin
  # Fork-only: ballot audit of a voting. Lists submitted ballots with whether
  # they are counted and account signals (Votings::BallotAudit), never their
  # picks, and lets an admin disqualify or restore a single ballot.
  class VotingBallotsController < Admin::ApplicationController
    layout "admin"

    PER_PAGE = 50

    before_action :set_voting
    before_action :set_ballot, only: %i[disqualify restore]

    def index
      @only_signals = params[:signals] == "1"
      @audit = Votings::BallotAudit.call(@voting, only_signals: @only_signals)
      respond_to do |format|
        format.html do
          @rows = Kaminari.paginate_array(@audit.rows).page(params[:page]).per(PER_PAGE)
        end
        format.csv do
          send_data ballots_csv(@audit.rows), filename: "#{@voting.slug}-ballots-#{Date.current}.csv",
                                              type: "text/csv; charset=utf-8"
        end
      end
    end

    # The voter is not told and can still edit the ballot; it stays disqualified.
    def disqualify
      change_disqualification(Time.current, "Ballot of @#{@ballot.user.username} disqualified: it is not counted.")
    end

    def restore
      change_disqualification(nil, "Ballot of @#{@ballot.user.username} restored: it counts again " \
                                   "if the member passes the voter rules.")
    end

    protected

    def authorization_resource
      Voting
    end

    private

    def set_voting
      @voting = Voting.find(params[:voting_id])
    end

    def set_ballot
      @ballot = @voting.ballots.find(params[:id])
    end

    def change_disqualification(disqualified_at, notice)
      if @ballot.disqualified? == disqualified_at.present?
        return redirect_to(ballots_path, notice: "Nothing changed: the ballot already was in that state.")
      end

      @ballot.update!(disqualified_at: disqualified_at)
      Audit::Logger.log(:internal, current_user, {
                          "action" => params[:action],
                          "controller" => params[:controller],
                          "voting_id" => @voting.id,
                          "voting_ballot_id" => @ballot.id,
                          "voter_id" => @ballot.user_id
                        })
      redirect_to ballots_path, notice: notice
    end

    # Back to the same page and filter the button was pressed on.
    def ballots_path
      admin_voting_voting_ballots_path(@voting, signals: params[:signals].presence, page: params[:page].presence)
    end

    def ballots_csv(rows)
      require "csv"
      CSV.generate do |csv|
        csv << ["Username", "User ID", "Account created", "Ballot submitted", "Status", "Not counted because",
                "Joined after opening", "Account under 24h", "No activity", "Other voters on the same IP",
                "Other ballots with the same picks"]
        rows.each do |row|
          signals = row.signals
          csv << [row.user.username, row.user.id, row.user.created_at.iso8601, row.ballot.submitted_at.iso8601,
                  row.counted? ? "Counted" : "Not counted",
                  row.reason && Votings::BallotAudit.reason_label(row.reason),
                  csv_flag(signals[:joined_after_opening]), csv_flag(signals[:new_account]),
                  csv_flag(signals[:no_activity]), signals.fetch(:shared_ip, 0), signals.fetch(:identical_picks, 0)]
        end
      end
    end

    def csv_flag(value)
      value ? "yes" : "no"
    end
  end
end

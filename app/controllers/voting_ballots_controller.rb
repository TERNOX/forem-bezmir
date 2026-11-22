# Fork-only: the signed-in user's ballot for a voting (JSON), plus the public
# "my picks" share page and its pictures (vote card and link preview).
class VotingBallotsController < ApplicationController
  before_action :set_voting
  before_action :authenticate_user!, only: :update
  rate_limit to: 10, within: 1.minute, only: :update,
             by: -> { current_user&.id || request.remote_ip },
             with: -> { render json: { errors: { base: ["rate_limited"] } }, status: :too_many_requests }

  # GET /vote/:slug/ballot — eligibility + current answers of the signed-in user.
  def show
    eligibility = Votings::Eligibility.call(@voting, current_user)
    ballot = current_user && @voting.ballots.includes(:choices).find_by(user: current_user)
    # A restricted member's share page 404s (find_shared_ballot), so don't link to it.
    shareable = ballot&.submitted? && !Votings::Eligibility.restricted_user?(current_user)
    render json: {
      signedIn: current_user.present?,
      eligible: eligibility.eligible?,
      reason: eligibility.reason,
      ballot: ballot && ballot_json(ballot),
      shareUrl: (share_url_for(ballot) if shareable)
    }
  end

  # PUT /vote/:slug/ballot  { selections: { "<category_id>": { nominee_ids: [], other: "" } } }
  def update
    result = Votings::BallotSubmitter.call(voting: @voting, user: current_user,
                                           selections: params[:selections] || {})
    if result.success?
      Votings::GenerateShareImageWorker.perform_async(result.ballot.id) if result.changed
      render json: { ballot: ballot_json(result.ballot.reload), shareUrl: share_url_for(result.ballot) }
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end

  # GET /vote/:slug/u/:username/:token — public page with someone's picks (for sharing).
  def share
    @ballot = find_shared_ballot(includes: :choices)
    @user = @ballot.user
    @categories = @voting.categories.includes(nominees: :game).to_a
    @picks = Votings::BallotPicks.call(@ballot, @categories)
    @share_url = share_url_for(@ballot)
    @share_preview_url = voting_share_preview_url(@voting.slug, @user.username, @ballot.share_token,
                                                  v: @ballot.updated_at.to_i)
  end

  # GET /vote/:slug/u/:username/:token/image — the vote card (the picture
  # people download and post).
  def image
    serve_share_picture(:share_image)
  end

  # GET /vote/:slug/u/:username/:token/preview — the 1200x630 link preview
  # (the share page's og:image).
  def preview
    serve_share_picture(:share_preview_image)
  end

  private

  # Both pictures are normally made by the worker right after voting; if the
  # one asked for is missing we try to render it here (GenerateShareImage
  # allows one render per ballot at a time and always draws both, so a ballot
  # with only an old-style card gets its preview too). While it isn't ready
  # the voting app (which passes ?attempt=) gets a 503 to retry on; crawlers
  # get the voting's generic social image.
  def serve_share_picture(attribute)
    ballot = find_shared_ballot
    if ballot.public_send(attribute).blank?
      begin
        Votings::GenerateShareImage.call(ballot)
      rescue StandardError => e
        Rails.logger.error("[VotingBallotsController##{action_name}] #{e.class}: #{e.message}")
      end
      ballot.reload
    end

    picture = ballot.public_send(attribute)
    if picture.present?
      redirect_to picture.url, allow_other_host: true
    else
      response.headers["Cache-Control"] = "no-store"
      if params[:attempt].present?
        response.headers["Retry-After"] = "3"
        head :service_unavailable
      else
        redirect_to fallback_image_url, allow_other_host: true
      end
    end
  end

  def set_voting
    @voting = Voting.find_by(slug: params[:slug].to_s.downcase)
    not_found unless @voting && (@voting.published? || current_user&.any_admin?)
  end

  def ballot_json(ballot)
    selections = ballot.choices.group_by(&:voting_category_id).transform_values do |choices|
      {
        nominee_ids: choices.select(&:voting_nominee_id).sort_by { |c| c.rank || 0 }.map(&:voting_nominee_id),
        other: choices.find { |c| c.voting_nominee_id.nil? }&.other_text
      }
    end
    { submittedAt: ballot.submitted_at&.iso8601, selections: selections }
  end

  def share_url_for(ballot)
    voting_share_url(@voting.slug, ballot.user.username, ballot.share_token)
  end

  def find_shared_ballot(includes: nil)
    user = User.find_by!(username: params[:username])
    # The page shows the member's free-text answers, so it goes away with them.
    not_found if Votings::Eligibility.restricted_user?(user)
    scope = @voting.submitted_ballots
    scope = scope.includes(includes) if includes
    ballot = scope.find_by!(user: user)
    not_found unless ballot.valid_share_token?(params[:token])
    ballot
  end

  def fallback_image_url
    banner = @voting.banner_image.url
    return Settings::General.main_social_image.to_s if banner.blank?

    banner.start_with?("http") ? banner : URL.url(banner)
  end
end

# Fork-only: renders a voting page; shared by VotingsController (/vote/:slug)
# and StoriesController (top-level /:slug votings).
module VotingPage
  extend ActiveSupport::Concern

  private

  def render_voting_page(voting)
    @voting = voting
    @voting_payload = Votings::PagePayload.call(voting)
    render template: "votings/show"
  end

  def viewable_voting?(voting)
    voting.present? && (voting.published? || current_user&.any_admin?)
  end
end

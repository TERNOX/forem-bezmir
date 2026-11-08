# Fork-only: public voting page at /vote/:slug. Not edge-cached: results and
# nominees change while a voting runs, and admins may preview drafts here.
class VotingsController < ApplicationController
  include VotingPage

  def show
    voting = Voting.find_by(slug: params[:slug].to_s.downcase)
    not_found unless viewable_voting?(voting)

    render_voting_page(voting)
  end
end

class TopUsersController < ApplicationController
  def index
    skip_authorization

    @users = User.registered.member.order(reputation_score: :desc).limit(50)
  end
end

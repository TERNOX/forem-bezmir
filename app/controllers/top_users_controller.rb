class TopUsersController < ApplicationController
  def index
    skip_authorization

    @users = UserDecorator.decorate_collection(
      User.registered.member.order(reputation_score: :desc).limit(50),
    )
  end
end

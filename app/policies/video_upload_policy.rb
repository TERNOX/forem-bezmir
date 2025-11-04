class VideoUploadPolicy < ApplicationPolicy
  def create?
    VideoPolicy.new(user, nil).create?
  end
end

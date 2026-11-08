# Fork-only (votings). Voting banners, custom (non-game) nominee images and the
# generated "my picks" share images.
class VotingImageUploader < BaseUploader
  def store_dir
    "uploads/votings/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def filename
    "#{secure_token}.#{file.extension}" if file.present?
  end

  protected

  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) || model.instance_variable_set(var, SecureRandom.uuid)
  end
end

# Fork-only (votings). Re-hosted game covers/artworks fetched from IGDB, or uploaded
# by an admin to override a wrong match.
class GameImageUploader < BaseUploader
  def store_dir
    "uploads/games/#{mounted_as}/#{model.id}"
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

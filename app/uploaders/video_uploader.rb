class VideoUploader < CarrierWave::Uploader::Base
  EXTENSION_ALLOWLIST = %w[mp4 webm mov].freeze

  def store_dir
    "uploads/videos/"
  end

  def extension_allowlist
    EXTENSION_ALLOWLIST
  end

  def size_range
    1..max_size_in_bytes
  end

  def filename
    "#{Array.new(20) { rand(36).to_s(36) }.join}.#{file.extension}" if file.present?
  end

  private

  def max_size_in_bytes
    max_size = Settings::General.video_upload_max_file_size_mb
    (max_size.presence || 50).to_i.megabytes
  end
end

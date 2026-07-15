require "open-uri"

# Fork-only feature. Re-hosts photos from embedded social posts (Twitter/X, Bluesky)
# onto our own storage so they survive deletion of the original post. Mirrors
# ArticleImageUploader#upload_from_url. Deliberately does NOT inherit BaseUploader
# (bombshelter's image-bomb processing) because these are already-sized thumbnails
# fetched from trusted CDNs; we only want durable storage, not reprocessing.
class SocialEmbedImageUploader < CarrierWave::Uploader::Base
  EXTENSION_ALLOWLIST = %w[jpg jpeg png gif webp].freeze
  MAX_FILE_SIZE = 15.megabytes

  def store_dir
    "uploads/social_embeds/"
  end

  def extension_allowlist
    EXTENSION_ALLOWLIST
  end

  def size_range
    1..MAX_FILE_SIZE
  end

  def filename
    "#{Array.new(20) { rand(36).to_s(36) }.join}.#{file.extension}" if file.present?
  end

  # Downloads a remote image and stores it on our own storage.
  # @param url [String] the original (ephemeral) image URL from the platform
  # @return [String, nil] the durable URL on our storage, or nil on failure
  def upload_from_url(url)
    remote = URI.open(url, "User-Agent" => "ForemSocialEmbed/1.0", :read_timeout => 10) # rubocop:disable Security/Open
    return nil if remote.respond_to?(:meta) && remote.meta["content-length"].to_i > MAX_FILE_SIZE

    ext = File.extname(remote.base_uri.path).presence || content_type_extension(remote)
    temp_file = Tempfile.new(["social_embed", ext])
    temp_file.binmode
    temp_file.write(remote.read)
    temp_file.rewind

    store!(temp_file)
    self.url
  rescue StandardError => e
    Rails.logger.warn("SocialEmbedImageUploader failed for #{url}: #{e.class}: #{e.message}")
    nil
  ensure
    if defined?(temp_file) && temp_file
      temp_file.close
      temp_file.unlink
    end
  end

  private

  # Bluesky/Twitter thumbnail URLs sometimes omit an extension; fall back to the
  # content-type so the extension_allowlist has something to check.
  def content_type_extension(remote)
    type = remote.respond_to?(:content_type) ? remote.content_type : nil
    case type
    when "image/jpeg" then ".jpg"
    when "image/png" then ".png"
    when "image/gif" then ".gif"
    when "image/webp" then ".webp"
    else ".jpg"
    end
  end
end

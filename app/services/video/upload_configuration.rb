# frozen_string_literal: true

require "uri"
require "cgi"

module Video
  class UploadConfiguration
    class << self
      def apply_s3_direct_upload!
        S3DirectUpload.config do |config|
          config.access_key_id = access_key_id
          config.secret_access_key = secret_access_key
          config.bucket = bucket
          config.region = region
          config.url = upload_endpoint
        end
      end

      def configured?
        access_key_id.present? && secret_access_key.present? && bucket.present?
      end

      def video_code_for(upload_url)
        return if upload_url.blank?

        uri = URI.parse(upload_url)
        key = uri.path.to_s.split("/").last
        return if key.blank?

        CGI.unescape(key)
      rescue URI::InvalidURIError
        nil
      end

      def stream_url_for(video_code)
        return if video_code.blank?

        base = cdn_base_url
        return if base.blank?

        build_url(base, video_code, "#{video_code}.m3u8")
      end

      def thumbnail_url_for(video_code)
        return if video_code.blank?

        base = cdn_base_url
        return if base.blank?

        build_url(base, video_code, "thumbs-#{video_code}-00001.png")
      end

      def cdn_base_url
        Settings::General.video_cdn_base_url.to_s.presence
      end

      def access_key_id
        Settings::General.video_upload_access_key_id.to_s.presence
      end

      def secret_access_key
        Settings::General.video_upload_secret_access_key.to_s.presence
      end

      def bucket
        Settings::General.video_upload_bucket.to_s.presence
      end

      def region
        Settings::General.video_upload_region.to_s.presence
      end

      def upload_endpoint
        Settings::General.video_upload_custom_endpoint.to_s.presence
      end

      private

      def build_url(base, *segments)
        normalized_base = base.chomp("/")
        additional_segments = segments.compact.map { |segment| segment.to_s.gsub(%r{^/+|/+$}, "") }
        ([normalized_base] + additional_segments).join("/")
      end
    end
  end
end

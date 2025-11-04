class VideoUploadsController < ApplicationController
  include ImageUploads

  before_action :authenticate_user!
  before_action :limit_uploads, only: [:create]
  after_action :verify_authorized

  PERMITTED_MIME_TYPES = %w[video/mp4 video/webm].freeze

  def create
    authorize :video_upload

    raise CarrierWave::IntegrityError if params[:video].blank?

    invalid_video_error_message = validate_video
    if invalid_video_error_message.present?
      render json: { error: invalid_video_error_message }, status: :unprocessable_entity
      return
    end

    uploader = upload_video(params[:video])

    render json: { links: [uploader.url], kind: "video" }, status: :ok
  rescue CarrierWave::IntegrityError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue CarrierWave::ProcessingError
    render json: { error: I18n.t("video_uploads_controller.server_error") }, status: :unprocessable_entity
  end

  private

  def limit_uploads
    rate_limit!(:video_upload)
  end

  def validate_video
    videos = Array.wrap(params[:video])

    return is_not_file_message unless valid_video_files?(videos)
    return filename_too_long_message unless valid_filenames?(videos)
    return invalid_type_message unless valid_mime_types?(videos)
    return file_too_large_message unless valid_sizes?(videos)

    nil
  end

  def valid_video_files?(videos)
    videos.all? { |video| file?(video) }
  end

  def valid_filenames?(videos)
    videos.all? { |video| !long_filename?(video) }
  end

  def valid_mime_types?(videos)
    videos.all? { |video| PERMITTED_MIME_TYPES.include?(video.content_type) }
  end

  def valid_sizes?(videos)
    limit = Settings::General.video_upload_max_file_size_mb.to_i.megabytes
    videos.all? { |video| video.size <= limit }
  end

  def upload_video(video_param)
    file = Array.wrap(video_param).first
    VideoUploader.new.tap do |uploader|
      uploader.store!(file)
      rate_limiter.track_limit_by_action(:video_upload)
    end
  end

  def invalid_type_message
    I18n.t("video_uploads_controller.invalid_format")
  end

  def file_too_large_message
    max_size = Settings::General.video_upload_max_file_size_mb
    I18n.t("video_uploads_controller.too_large", max: max_size)
  end
end

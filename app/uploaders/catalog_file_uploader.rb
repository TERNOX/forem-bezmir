class CatalogFileUploader < CarrierWave::Uploader::Base
  def store_dir
    "uploads/catalog_files/#{model.catalog_item_id}"
  end

  def size_range
    1..max_size_in_bytes
  end

  def filename
    return unless original_filename.present?

    "#{Array.new(20) { rand(36).to_s(36) }.join}.#{file.extension}"
  end

  private

  def max_size_in_bytes
    max_size = Settings::General.catalog_upload_max_file_size_mb
    (max_size.presence || 100).to_i.megabytes
  end
end

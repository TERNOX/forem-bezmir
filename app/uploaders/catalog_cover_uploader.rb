class CatalogCoverUploader < BaseUploader
  def store_dir
    "uploads/catalog_covers/#{model.id}"
  end

  def size_range
    1..(25.megabytes)
  end
end

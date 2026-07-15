module SocialEmbeds
  # Normalized result of fetching a social post from a platform client.
  #   status: :ok          -> content present in this object
  #           :deleted      -> source confirmed gone (404 / tombstone / notFound)
  #           :unavailable  -> fetch failed but deletion is NOT confirmed
  # photos: Array<Hash> of { "url" => original_url, "alt" => "" } (re-hosting happens
  # later, in the Snapshotter).
  PostData = Struct.new(
    :status,
    :author_handle,
    :author_name,
    :author_avatar_url,
    :text_html,
    :text_content,
    :posted_at,
    :photos,
    :raw,
    keyword_init: true,
  ) do
    def self.deleted(raw: {})
      new(status: :deleted, photos: [], raw: raw)
    end

    def self.unavailable(raw: {})
      new(status: :unavailable, photos: [], raw: raw)
    end

    def ok?
      status == :ok
    end
  end
end

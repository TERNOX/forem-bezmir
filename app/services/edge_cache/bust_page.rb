module EdgeCache
  class BustPage
    def self.call(slug)
      return unless slug

      cache_bust = EdgeCache::Bust.new
      cache_bust.call("/page/#{slug}")
      cache_bust.call("/#{slug}")
      # The trailing-slash URL renders the same page but is a separate edge cache
      # entry, so without this purge it keeps serving the old page after an update.
      cache_bust.call("/#{slug}/")
      # Page responses carry this surrogate key on every URL that serves them,
      # including query variants such as the ?i= InstantClick fetch, which
      # the path purges above do not reach.
      EdgeCache::PurgeByKey.call("show-page-#{slug}")
    end
  end
end

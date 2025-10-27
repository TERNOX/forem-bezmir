# frozen_string_literal: true

module Articles
  class TopArticlesDigestWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10

    def perform(run_time = nil)
      digest_context_ids.each do |subforem_id|
        with_subforem_context(subforem_id) do
          next if Settings::General.top_articles_digest_bot_api_key.blank?

          Articles::TopArticles::DigestPublisher.new(reference_time: run_time).call
        end
      end
    ensure
      RequestStore.clear!
    end

    private

    def digest_context_ids
      ([nil] + Subforem.pluck(:id)).uniq
    end

    def with_subforem_context(subforem_id)
      RequestStore.clear!

      RequestStore.store[:default_subforem_id] = Subforem.cached_default_id
      RequestStore.store[:root_subforem_id] = Subforem.cached_root_id
      RequestStore.store[:root_subforem_domain] = Subforem.cached_root_domain
      RequestStore.store[:default_subforem_domain] = Subforem.cached_default_domain
      RequestStore.store[:subforem_id] = subforem_id

      if subforem_id
        RequestStore.store[:subforem_domain] = Subforem.cached_id_to_domain_hash[subforem_id]
      else
        RequestStore.store.delete(:subforem_domain)
      end

      yield
    ensure
      RequestStore.clear!
    end
  end
end

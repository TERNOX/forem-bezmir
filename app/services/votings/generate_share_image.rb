# Fork-only: draws a ballot's two "my picks" pictures with Votings::ShareCard
# and stores them together: the tall vote card (share_image, the picture
# people download and post) and the 1200x630 link preview
# (share_preview_image, the share page's og:image).
module Votings
  class GenerateShareImage
    # One render per ballot at a time, shared by the worker and the on-demand
    # image endpoints. Covers are downloaded in parallel with
    # ShareCard::DOWNLOAD_TIMEOUT each, so a render (two pictures) stays well
    # under LOCK_TTL. A failed render keeps the key for a short cooldown so a
    # known share URL can't be used to retry it in a loop.
    LOCK_TTL = 5.minutes
    FAILURE_COOLDOWN = 1.minute

    def self.call(ballot)
      new(ballot).call
    end

    def self.lock_key(ballot)
      "voting-share-image:#{ballot.id}"
    end

    def initialize(ballot)
      @ballot = ballot
      # The ballot row's updated_at is the revision of its picks: a re-submit
      # (Votings::BallotSubmitter) and the admin services that rewrite picks
      # (Votings::NomineeRemover, Votings::OtherAnswerMerger) all bump it in
      # the same transaction as the choices. Captured from the row as it was
      # loaded, i.e. no newer than the picks #render reads afterwards.
      @revision = ballot.updated_at
      @tempfiles = []
    end

    # @return [Boolean] whether this call stored the images (false: another
    # render holds the lock, it is cooling down after a failure, or it went
    # stale).
    def call
      key = self.class.lock_key(@ballot)
      owner = SecureRandom.hex(8)
      return false unless Rails.cache.write(key, owner, unless_exist: true, expires_in: LOCK_TTL)

      begin
        stored = I18n.with_locale(locale) { render }
        release(key, owner)
        stored
      rescue StandardError
        Rails.cache.write(key, "failed", expires_in: FAILURE_COOLDOWN) if Rails.cache.read(key) == owner
        raise
      end
    ensure
      @tempfiles.each(&:close!)
    end

    private

    # Only drop the lock if it is still ours (it may have expired and been
    # taken by another render meanwhile).
    def release(key, owner)
      Rails.cache.delete(key) if Rails.cache.read(key) == owner
    end

    # Workers run without a request locale; use the community's language.
    def locale
      candidate = Settings::UserExperience.default_locale.presence&.to_sym
      I18n.available_locales.include?(candidate) ? candidate : I18n.default_locale
    end

    def render
      # Read the picks now, after the revision was captured, even if the
      # caller preloaded them: picks older than the revision would let a
      # stale card pass the check in #store.
      @ballot.choices.reset
      picks = Votings::BallotPicks.call(@ballot)
      card = draw(picks, :card)
      preview = draw(picks, :preview)
      store(card, preview)
    end

    def draw(picks, layout)
      file = tempfile(".png")
      Votings::ShareCard.call(ballot: @ballot, picks: picks, layout: layout, path: file.path)
      file
    end

    # Both pictures are written by one save, so a ballot never has a card of
    # one revision and a preview of another.
    def store(card, preview)
      @ballot.with_lock do
        # The picks changed while we were drawing (the voter re-submitted, or
        # an admin removed a nominee / merged an "other" answer): the render
        # queued by that change owns the images, so drop these stale ones.
        # with_lock reloaded the row; compared at the database's microsecond
        # precision.
        next false if @ballot.updated_at&.floor(6) != @revision&.floor(6)

        @ballot.share_image = File.open(card.path)
        @ballot.share_preview_image = File.open(preview.path)
        @ballot.save!
        true
      end
    end

    def tempfile(ext)
      Tempfile.new(["voting_share", ext]).tap { |file| @tempfiles << file }
    end
  end
end

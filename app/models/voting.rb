# Fork-only: a community voting such as "Гра року" — an ordered list of
# nomination categories, each with nominees (usually games). Signed-in, eligible
# users fill one ballot, editable until the voting closes. Results stay hidden
# until an admin publishes them.
class Voting < ApplicationRecord
  SLUG_FORMAT = /\A[0-9a-z\-_]+\z/

  mount_uploader :banner_image, VotingImageUploader

  has_many :categories, -> { order(:position, :id) },
           class_name: "VotingCategory", dependent: :destroy, inverse_of: :voting
  has_many :nominees, through: :categories
  has_many :ballots, class_name: "VotingBallot", dependent: :destroy, inverse_of: :voting

  validates :title, presence: true, length: { maximum: 150 }
  validates :slug, presence: true, length: { maximum: 100 }, format: { with: SLUG_FORMAT },
                   uniqueness: { case_sensitive: false }
  validate :top_level_slug_available, if: -> { top_level_path? && (slug_changed? || top_level_path_changed?) }
  validates :min_user_score, numericality: { only_integer: true }
  validate :closes_after_opens
  # Checked only when one of the two changes, so a voting saved before this
  # rule can still have its results published (update!) without a 500.
  validate :opens_at_for_account_age_rule, if: :account_age_rule_changing?

  before_validation :normalize_slug
  before_save :render_description

  scope :published, -> { where(published: true) }

  def self.find_published_by_slug(slug)
    published.find_by(slug: slug.to_s.downcase)
  end

  def path
    top_level_path? ? "/#{slug}" : "/vote/#{slug}"
  end

  def upcoming?(now = Time.current)
    opens_at.present? && opens_at > now
  end

  def closed?(now = Time.current)
    closes_at.present? && closes_at <= now
  end

  def open?(now = Time.current)
    published? && !upcoming?(now) && !closed?(now)
  end

  def results_published?
    results_published_at.present?
  end

  # Publishes the results as they stand now: the public page keeps showing
  # this snapshot (see Votings::PublicResults) until it is taken again, so
  # later suspensions, deleted accounts or ballots still cast while the voting
  # is open don't move the announced numbers. Calling it again re-takes it.
  #
  # @param results [Hash, nil] an existing Votings::Results.call(self), to avoid tallying twice
  def publish_results!(now: Time.current, results: nil)
    update!(results_published_at: now, results_snapshot: Votings::PublicResults.call(self, results: results))
  end

  def unpublish_results!
    update!(results_published_at: nil, results_snapshot: nil)
  end

  # What the public page shows once results are published: the snapshot, or
  # for results published before snapshots existed, the live count.
  def public_results
    return unless results_published?

    results_snapshot || Votings::PublicResults.call(self)
  end

  def status(now = Time.current)
    return :draft unless published?
    return :upcoming if upcoming?(now)
    return :closed if closed?(now)

    :open
  end

  def submitted_ballots
    ballots.where.not(submitted_at: nil)
  end

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase.presence || title.to_s.parameterize.presence
  end

  def render_description
    return unless description_markdown_changed?

    self.description_html = MarkdownProcessor::Parser.new(description_markdown).evaluate_limited_markdown
  end

  # A top-level voting lives at /<slug>, next to users, organizations, pages and
  # podcasts, so its slug must not collide with any of them (see CrossModelSlug).
  def top_level_slug_available
    return if slug.blank?

    taken = ReservedWords.all.include?(slug) ||
      slug.include?("sitemap-") ||
      User.exists?(username: slug) ||
      Organization.exists?(slug: slug) ||
      Podcast.exists?(slug: slug) ||
      Page.exists?(slug: slug) ||
      Voting.where(top_level_path: true, slug: slug).where.not(id: id).exists?
    errors.add(:slug, I18n.t("models.voting.slug_taken")) if taken
  end

  def closes_after_opens
    return if opens_at.blank? || closes_at.blank? || closes_at > opens_at

    errors.add(:closes_at, I18n.t("models.voting.closes_before_opens"))
  end

  def account_age_rule_changing?
    require_account_before_start? &&
      (will_save_change_to_require_account_before_start? || will_save_change_to_opens_at?)
  end

  # "Only accounts created before the start" is measured against opens_at, so
  # without it the rule would silently do nothing.
  def opens_at_for_account_age_rule
    return if opens_at.present?

    errors.add(:opens_at, I18n.t("models.voting.opens_at_required"))
  end
end

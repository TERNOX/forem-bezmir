class TopUsersController < ApplicationController
  helper TopUsersHelper
  helper_method :formatted_period

  LeaderboardEntry = Struct.new(:user, :score, keyword_init: true)

  def index
    skip_authorization

    current = current_period
    ensure_snapshot_for_period(current)

    @selected_period = parse_period(params[:period])
    ensure_snapshot_for_period(@selected_period) if @selected_period.present? && @selected_period != current

    @available_periods = available_periods

    if @selected_period
      @leaderboard_entries = entries_for_period(@selected_period)
      @page_title = I18n.t("views.top_users.month_title", month: formatted_period(@selected_period))
      @score_label = I18n.t("views.top_users.reputation_label_month", month: formatted_period(@selected_period))
      @description = I18n.t("views.top_users.month_description", month: formatted_period(@selected_period))
    else
      @leaderboard_entries = entries_for_all_time
      @page_title = I18n.t("views.top_users.title")
      @score_label = I18n.t("views.top_users.reputation_label")
      @description = I18n.t("views.top_users.description")
    end
  end

  private

  def available_periods
    periods = MonthlyUserReputation.distinct.pluck(:period)
    periods << current_period
    periods.compact.uniq.sort.reverse
  end

  def current_period
    Time.zone.today.beginning_of_month.to_date
  end

  def parse_period(value)
    return if value.blank?
    return unless value.match?(/\A\d{4}-\d{2}\z/)

    date = Date.strptime(value, "%Y-%m")
    return unless available_periods.include?(date)

    date
  rescue ArgumentError
    nil
  end

  def ensure_snapshot_for_period(period)
    return if period.blank?

    if period == current_period
      Users::CalculateMonthlyReputation.call(period: period)
      return
    end

    return if MonthlyUserReputation.for_period(period).exists?

    Users::CalculateMonthlyReputation.call(period: period)
  end

  def entries_for_all_time
    users = User.registered.member.order(reputation_score: :desc).limit(50)
    decorate_leaderboard(users.map { |user| LeaderboardEntry.new(user: user, score: user.reputation_score) })
  end

  def entries_for_period(period)
    records = MonthlyUserReputation
      .for_period(period)
      .includes(:user)
      .order(rank: :asc, score: :desc)
      .limit(50)

    decorate_leaderboard(
      records.map { |record| LeaderboardEntry.new(user: record.user, score: record.score) },
    )
  end

  def decorate_leaderboard(entries)
    decorated = UserDecorator.decorate_collection(entries.map(&:user))
    decorated_by_id = decorated.index_by(&:id)

    entries.each do |entry|
      entry.user = decorated_by_id[entry.user.id]
    end

    entries
  end

  def formatted_period(period)
    return if period.blank?

    MonthlyUserReputationFormatter.period_label(period)
  end
end

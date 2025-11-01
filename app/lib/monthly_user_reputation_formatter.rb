# frozen_string_literal: true

module MonthlyUserReputationFormatter
  module_function

  PeriodComponents = Struct.new(:period, :month, :year, keyword_init: true)

  def period_label(period)
    components_for(period).period
  end

  def month_name(period)
    components_for(period).month
  end

  def year(period)
    components_for(period).year
  end

  def components_for(period)
    date = period.to_date.beginning_of_month

    month_names = I18n.t("date.month_names_standalone", default: [])
    month_name = month_names.is_a?(Array) ? month_names[date.month] : nil

    period_label =
      if month_name.present?
        I18n.t(
          "date.formats.month_year_standalone",
          default: "%{month} %{year}",
          month: month_name,
          year: date.year,
        )
      else
        I18n.l(date, format: :long_month)
      end

    standalone_month =
      if month_name.present?
        month_name
      else
        I18n.l(date, format: "%B")
      end

    PeriodComponents.new(period: period_label, month: standalone_month, year: date.year)
  end
end

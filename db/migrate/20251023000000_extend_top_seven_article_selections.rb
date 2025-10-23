class ExtendTopSevenArticleSelections < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    add_frequency_column
    add_column_unless_exists :top_seven_article_selections, :digest_article_id, :integer
    add_column_unless_exists :top_seven_article_selections, :badge_slug, :string

    ensure_weekly_frequency_populated
    remove_duplicate_periods
    add_period_index
  end

  def down
    remove_frequency_not_null_constraint

    remove_index :top_seven_article_selections, name: "index_top_seven_article_selections_on_period" if index_exists?(:top_seven_article_selections, name: "index_top_seven_article_selections_on_period")

    unless index_exists?(:top_seven_article_selections, :week_of, name: "index_top_seven_article_selections_on_week_of")
      add_index :top_seven_article_selections,
                :week_of,
                unique: true,
                name: "index_top_seven_article_selections_on_week_of",
                algorithm: :concurrently
    end

    remove_column :top_seven_article_selections, :badge_slug if column_exists?(:top_seven_article_selections, :badge_slug)
    remove_column :top_seven_article_selections, :digest_article_id if column_exists?(:top_seven_article_selections, :digest_article_id)
    remove_column :top_seven_article_selections, :frequency if column_exists?(:top_seven_article_selections, :frequency)
  end

  private

  def add_frequency_column
    add_column_unless_exists :top_seven_article_selections,
                             :frequency,
                             :string,
                             null: false,
                             default: "weekly"
  end

  def add_column_unless_exists(table, column, type, **options)
    return if column_exists?(table, column)

    add_column(table, column, type, **options)
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::DuplicateColumn)
  end

  def ensure_weekly_frequency_populated
    return unless column_exists?(:top_seven_article_selections, :frequency)

    safety_assured do
      execute <<~SQL.squish
        UPDATE top_seven_article_selections
           SET frequency = 'weekly'
         WHERE frequency IS NULL
      SQL
    end

    change_column_default :top_seven_article_selections, :frequency, "weekly"
    add_frequency_not_null_constraint

    return unless frequency_column_allows_null?

    validate_frequency_not_null_constraint

    safety_assured do
      change_column_null :top_seven_article_selections, :frequency, false
    end
  end

  def remove_duplicate_periods
    return unless column_exists?(:top_seven_article_selections, :frequency)

    safety_assured do
      execute <<~SQL.squish
        DELETE FROM top_seven_article_selections a
              USING top_seven_article_selections b
         WHERE a.id > b.id
           AND a.week_of = b.week_of
           AND COALESCE(a.frequency, 'weekly') = COALESCE(b.frequency, 'weekly')
      SQL
    end
  end

  def add_period_index
    return if index_exists?(:top_seven_article_selections, %i[week_of frequency], name: "index_top_seven_article_selections_on_period")

    remove_index :top_seven_article_selections, column: :week_of if index_exists?(:top_seven_article_selections, :week_of)

    add_index :top_seven_article_selections,
              %i[week_of frequency],
              unique: true,
              name: "index_top_seven_article_selections_on_period",
              algorithm: :concurrently
  end

  def remove_frequency_not_null_constraint
    return unless connection.supports_check_constraints?
    return unless check_constraint_exists?(:top_seven_article_selections, name: frequency_not_null_constraint_name)

    remove_check_constraint :top_seven_article_selections, name: frequency_not_null_constraint_name
  end

  def add_frequency_not_null_constraint
    return unless connection.supports_check_constraints?
    return if check_constraint_exists?(:top_seven_article_selections, name: frequency_not_null_constraint_name)

    add_check_constraint :top_seven_article_selections,
                         "frequency IS NOT NULL",
                         name: frequency_not_null_constraint_name,
                         validate: false
  end

  def validate_frequency_not_null_constraint
    return unless connection.supports_check_constraints?
    return if frequency_not_null_constraint_validated?
    return unless check_constraint_exists?(:top_seven_article_selections, name: frequency_not_null_constraint_name)

    safety_assured do
      validate_check_constraint :top_seven_article_selections, name: frequency_not_null_constraint_name
    end
  end

  def frequency_not_null_constraint_validated?
    return false unless connection.supports_check_constraints?

    value = connection.select_value(<<~SQL.squish)
      SELECT convalidated
        FROM pg_constraint
       WHERE conname = #{connection.quote(frequency_not_null_constraint_name)}
         AND conrelid = #{connection.quote("top_seven_article_selections")}::regclass
    SQL
    ActiveRecord::Type::Boolean.new.cast(value)
  rescue ActiveRecord::StatementInvalid
    false
  end

  def frequency_not_null_constraint_name
    "top_seven_article_selections_frequency_null"
  end

  def frequency_column_allows_null?
    column = connection.columns(:top_seven_article_selections).find { |c| c.name == "frequency" }
    column&.null
  end
end

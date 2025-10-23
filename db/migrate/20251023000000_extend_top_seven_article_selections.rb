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
    change_column_null :top_seven_article_selections, :frequency, false
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
end

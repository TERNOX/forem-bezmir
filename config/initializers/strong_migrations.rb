# https://github.com/ankane/strong_migrations#existing-migrations
StrongMigrations.start_after = 20_200_106_074_859

# https://github.com/ankane/strong_migrations#removing-an-index-non-concurrently
StrongMigrations.enable_check(:remove_index)

# https://github.com/ankane/strong_migrations#target-version
StrongMigrations.target_postgresql_version = 15

# https://github.com/ankane/strong_migrations#down-migrations--rollbacks
StrongMigrations.check_down = true

# Fork: production still runs PostgreSQL 11, and Strong Migrations 2.x refuses
# to run any migration on a server older than 12 ("version not supported").
# Its checks are a development safety net (every migration is already checked
# in development and CI, which run a newer PostgreSQL), so production skips
# them instead of failing to boot. Remove once production is on PostgreSQL 12+.
StrongMigrations.skip_database(:primary) if Rails.env.production?

module StrongMigrations
  def self.temporarily_disable_check(check)
    disable_check check

    yield
  ensure
    enable_check check
  end
end

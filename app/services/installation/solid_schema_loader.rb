module Installation
  # Creates the Solid Queue and Solid Cache tables when they share the primary database.
  #
  # The supported deployment gives primary, queue, and cache the same DATABASE_URL.
  # `db:prepare` loads db/schema.rb for the primary database, then treats queue and
  # cache as already-created and falls through to `db:migrate` against their configured
  # migrations_paths (db/queue_migrate, db/cache_migrate), which do not exist. Their
  # tables are therefore never created: the worker cannot start and every cached page
  # raises PG::UndefinedTable, while /up still reports the container healthy.
  #
  # Both schema files declare `force: :cascade`, so loading them is destructive. Each is
  # loaded only when its sentinel table is absent, which keeps re-running `db:prepare`
  # safe for queued jobs and cache entries.
  class SolidSchemaLoader
    SCHEMAS = {
      "solid_cache_entries" => "db/cache_schema.rb",
      "solid_queue_jobs" => "db/queue_schema.rb"
    }.freeze

    def self.call(...) = new(...).call

    def initialize(connection: ActiveRecord::Base.connection)
      @connection = connection
    end

    def call
      SCHEMAS.filter_map do |sentinel_table, relative_path|
        next if @connection.table_exists?(sentinel_table)

        schema = Rails.root.join(relative_path)
        next unless schema.exist?

        load schema.to_s
        relative_path
      end
    end
  end
end

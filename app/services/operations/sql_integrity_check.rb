module Operations
  class SqlIntegrityCheck
    Finding = Data.define(:code, :severity, :count, :identifiers)
    LIMIT = 20

    private

    def findings(checks)
      checks.filter_map do |code, severity, sql|
        rows = ApplicationRecord.connection.select_rows(sql).first(LIMIT + 1)
        next if rows.empty?
        Finding.new(code:, severity:, count: rows.length, identifiers: rows.first(LIMIT).flatten.map(&:to_s))
      end
    end
  end
end

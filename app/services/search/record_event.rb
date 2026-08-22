module Search
  # Records one aggregate search observation. Deliberately best-effort: analytics must
  # never break or slow down a search, and never block a POS or clinical workflow.
  class RecordEvent
    def self.call(result:, actor: nil, selected_product: nil)
      new(result:, actor:, selected_product:).call
    end

    def initialize(result:, actor:, selected_product:)
      @result = result
      @actor = actor
      @selected_product = selected_product
    end

    def call
      return nil if @result.query.blank?

      SearchEvent.create!(context: @result.context.to_s, query_fingerprint: @result.query.fingerprint,
        normalized_query: recorded_query, token_count: @result.query.tokens.size,
        result_count: @result.count, zero_result: @result.empty?,
        selected_product: @selected_product, branch: Current.branch || Branch.default_branch,
        created_at: Time.current)
    rescue ActiveRecord::ActiveRecordError => error
      Errors::Reporter.capture(error)
      nil
    end

    private

    def recorded_query
      SearchEvent.records_query_text?(@result.context) ? @result.query.normalized.presence : nil
    end
  end
end

module Staff
  # Pharmacist-only product lookup used while choosing a therapeutic substitute.
  #
  # This endpoint finds PRODUCTS. It does not rank, imply or assert therapeutic
  # equivalence: the pharmacist chooses, and the Phase 20 safety engine re-evaluates
  # the new clinical context after the substitution is recorded.
  class SubstitutionCandidatesController < BaseController
    LIMIT = 12

    before_action :authorize_clinical!

    def index
      result = Search::Products.call(query: params[:q], context: :substitution, limit: LIMIT)
      Search::RecordEvent.call(result:, actor: current_user)
      render partial: "staff/substitution_candidates/results", locals: {
        products: candidates(result), result:, field_id: field_id, excluded_id: params[:exclude_id].to_i
      }
    end

    private

    def authorize_clinical!
      head :not_found unless current_user.can_make_prescription_decisions?
    end

    def candidates(result)
      records = result.records.reject { |product| product.id == params[:exclude_id].to_i }
      ActiveRecord::Associations::Preloader.new(records:, associations: %i[brand active_ingredients]).call
      records
    end

    def field_id = params[:field_id].to_s.gsub(/[^a-zA-Z0-9_-]/, "").presence || "substitute_product_id"
  end
end

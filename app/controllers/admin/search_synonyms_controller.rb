module Admin
  # Controlled, data-driven query expansion. Synonyms only widen what a query can find;
  # the form states plainly that they carry no clinical meaning.
  class SearchSynonymsController < BaseController
    before_action :set_synonym, only: %i[show edit update deactivate]

    def index
      scope = SearchSynonym.order(:normalized_term, :normalized_expansion)
      if params[:q].present?
        pattern = "%#{SearchSynonym.sanitize_sql_like(Search::ArabicNormalizer.normalize(params[:q]))}%"
        scope = scope.where("normalized_term LIKE :q OR normalized_expansion LIKE :q", q: pattern)
      end
      scope = scope.where(active: params[:active] == "true") if %w[true false].include?(params[:active])
      @pagy, @synonyms = pagy(scope, limit: 25)
    end

    def show; end
    def new = @synonym = SearchSynonym.new(active: true)
    def edit; end

    def create
      @synonym = SearchSynonym.new(synonym_params)
      if @synonym.save
        audit("search_synonym_created")
        redirect_to admin_search_synonym_path(@synonym), notice: "تمت إضافة المرادف"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @synonym.update(synonym_params)
        audit("search_synonym_updated")
        redirect_to admin_search_synonym_path(@synonym), notice: "تم تحديث المرادف"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def deactivate
      @synonym.update!(active: false)
      audit("search_synonym_deactivated")
      redirect_to admin_search_synonym_path(@synonym), notice: "تم إيقاف المرادف"
    end

    private

    def set_synonym = @synonym = SearchSynonym.find(params[:id])
    def synonym_params = params.require(:search_synonym).permit(:term, :expansion, :active, :notes)

    def audit(action)
      AdminAuditEvent.create!(actor: current_user, auditable: @synonym, action:,
        metadata: { term: @synonym.normalized_term, expansion: @synonym.normalized_expansion, active: @synonym.active })
    end
  end
end

class HealthController < ActionController::Base
  def ready
    ActiveRecord::Base.connection.select_value("SELECT 1")
    pending = ActiveRecord::Migration.check_all_pending!
    render json: { status: "ready" }, status: :ok
  rescue ActiveRecord::PendingMigrationError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
    render json: { status: "unavailable" }, status: :service_unavailable
  end
end

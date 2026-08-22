require "test_helper"

class ApiV1Test < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:default)
    @client = ApiClient.create!(organization: @organization, name: "Test integration")
    @token, @plaintext = ApiToken.issue!(api_client: @client,
      scopes: %w[catalog:read inventory:read orders:read orders:write purchasing:read webhooks:manage])
    @headers = { "Authorization" => "Bearer #{@plaintext}" }
  end

  test "token plaintext is returned once and never persisted" do
    refute_includes @token.attributes.values.map(&:to_s), @plaintext
    assert_equal @token, ApiToken.authenticate(@plaintext)
    @token.revoke!
    assert_nil ApiToken.authenticate(@plaintext)
  end

  test "products require authentication and scope" do
    get api_v1_products_path
    assert_response :unauthorized
    get api_v1_products_path, headers: @headers
    assert_response :success
    assert_kind_of Array, response.parsed_body.fetch("data")

    limited, plaintext = ApiToken.issue!(api_client: @client, scopes: %w[orders:read])
    get api_v1_products_path, headers: { "Authorization" => "Bearer #{plaintext}" }
    assert_response :forbidden
    limited.revoke!
  end

  test "tenant token cannot read another tenant product by guessed id" do
    other = other_tenant
    product = other.fetch(:product)

    get api_v1_product_path(product.id), headers: @headers
    assert_response :not_found
  end

  test "purchase returns and webhook endpoints reject guessed ids from another tenant" do
    other = other_tenant
    get api_v1_purchase_order_path(other.fetch(:purchase_order)), headers: @headers
    assert_response :not_found
    get api_v1_return_path(other.fetch(:return_request)), headers: @headers
    assert_response :not_found
    get api_v1_webhook_endpoint_path(other.fetch(:webhook_endpoint)), headers: @headers
    assert_response :not_found
  end

  test "webhook secret is displayed only on creation and rotation and actions are audited" do
    assert_difference -> { IntegrationAuditEvent.count }, 1 do
      post api_v1_webhook_endpoints_path, params: { webhook_endpoint: { url: "https://203.0.113.10/hook",
        subscribed_events: [ "order.created" ] } }, headers: @headers.merge("Idempotency-Key" => "webhook-create"), as: :json
    end
    assert_response :created
    secret = response.parsed_body.dig("data", "secret")
    endpoint = WebhookEndpoint.find(response.parsed_body.dig("data", "id"))
    assert secret.present?
    stored = ActiveRecord::Base.connection.select_value("SELECT encrypted_secret FROM webhook_endpoints WHERE id=#{endpoint.id.to_i}")
    refute_equal secret, stored
    refute_includes ApiIdempotencyRecord.find_by!(action: "webhooks.create").response_body.to_json, secret

    get api_v1_webhook_endpoint_path(endpoint), headers: @headers
    assert_response :success
    assert_nil response.parsed_body.dig("data", "secret")

    post rotate_secret_api_v1_webhook_endpoint_path(endpoint), headers: @headers.merge("Idempotency-Key" => "webhook-rotate")
    assert_response :success
    refute_equal secret, response.parsed_body.dig("data", "secret")
    assert_equal %w[webhook_endpoint_created webhook_secret_rotated], IntegrationAuditEvent.order(:id).last(2).map(&:action)
  end

  test "rate limit is credential scoped and blocks before writes" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @client.update!(rate_limit_per_minute: 1)
    get api_v1_products_path, headers: @headers
    assert_response :success
    assert_no_difference -> { WebhookEndpoint.count } do
      post api_v1_webhook_endpoints_path, params: { webhook_endpoint: { url: "https://203.0.113.12/hook",
        subscribed_events: [ "order.created" ] } }, headers: @headers, as: :json
      assert_response :too_many_requests
    end

    second_client = ApiClient.create!(organization: @organization, name: "Independent")
    _, plaintext = ApiToken.issue!(api_client: second_client, scopes: %w[catalog:read])
    get api_v1_products_path, headers: { "Authorization" => "Bearer #{plaintext}" }
    assert_response :success
  ensure
    Rails.cache = original_cache if original_cache
  end

  test "idempotency is isolated by client and rejects payload mismatch" do
    order = cancellable_order
    key = "same-key"
    post cancel_api_v1_order_path(order.id), params: { reason: "integration cancellation" },
      headers: @headers.merge("Idempotency-Key" => key), as: :json
    assert_response :success
    first_body = response.parsed_body
    post cancel_api_v1_order_path(order.id), params: { reason: "integration cancellation" },
      headers: @headers.merge("Idempotency-Key" => key), as: :json
    assert_equal first_body, response.parsed_body
    post cancel_api_v1_order_path(order.id), params: { reason: "different" },
      headers: @headers.merge("Idempotency-Key" => key), as: :json
    assert_response :conflict

    second_client = ApiClient.create!(organization: @organization, name: "Idempotency independent")
    _, second_plaintext = ApiToken.issue!(api_client: second_client, scopes: %w[orders:write])
    post cancel_api_v1_order_path(order.id), params: { reason: "integration cancellation" },
      headers: { "Authorization" => "Bearer #{second_plaintext}", "Idempotency-Key" => key }, as: :json
    assert_response :success
    assert_equal 2, ApiIdempotencyRecord.where(action: "orders.cancel", key:).count
  end

  private

  def other_tenant
    return @other_tenant if @other_tenant
    organization = Organization.create!(code: "OTHER", name: "Other", active: true, timezone: "Africa/Cairo", currency: "EGP", locale: "ar")
    @other_tenant = Current.set(organization:) do
      branch = Branch.create!(organization:, code: "OTHER-MAIN", name: "Other Main", timezone: "Africa/Cairo", default: true)
      admin = User.create!(organization:, default_branch: branch, email: "other-admin@example.test", password: "password123",
        first_name: "Other", last_name: "Admin", mobile_number: "01000000091", role: :admin, active: true)
      customer = User.create!(organization:, email: "other-customer@example.test", password: "password123",
        first_name: "Other", last_name: "Customer", mobile_number: "01000000092", role: :customer, active: true)
      category = Category.create!(organization_id: organization.id, name: "Other Category", slug: "other-category", active: true)
      brand = Brand.create!(organization_id: organization.id, name: "Other Brand", slug: "other-brand", active: true)
      source = Product.unscoped.where(organization_id: @organization.id).first
      product = source.dup
      product.assign_attributes(organization_id: organization.id, category:, brand:, slug: "other-product", sku: "OTHER-SKU", barcode: "998877665544", stock_quantity: 0)
      product.save!
      supplier = Supplier.create!(organization_id: organization.id, code: "OTHER-SUP", name: "Other Supplier", active: true)
      purchase_order = PurchaseOrder.create!(organization_id: organization.id, branch:, supplier:, created_by: admin, number: "OTHER-PO",
        status: :draft, currency: "EGP", subtotal_cents: 0, discount_total_cents: 0, tax_total_cents: 0, total_cents: 0)
      session = CashierSession.create!(organization_id: organization.id, branch:, user: admin, identifier: "OTHER-SESSION",
        opening_cash_cents: 0, opened_at: Time.current)
      sale = PosSale.create!(organization_id: organization.id, branch:, cashier_session: session, cashier: admin, customer:,
        number: "OTHER-POS", subtotal_cents: 0, automatic_discount_cents: 0, manual_discount_cents: 0,
        loyalty_discount_cents: 0, wallet_paid_cents: 0, tax_cents: 0, total_cents: 0)
      return_request = ReturnRequest.create!(organization_id: organization.id, branch:, source: sale, requested_by: admin,
        number: "OTHER-RETURN", status: :submitted, submitted_at: Time.current)
      endpoint, = WebhookEndpoint.build_with_secret(url: "https://203.0.113.11/hook", subscribed_events: [ "order.created" ])
      endpoint.organization = organization
      endpoint.save!
      { organization:, branch:, admin:, customer:, product:, purchase_order:, return_request:, webhook_endpoint: endpoint }
    end
  end


  def cancellable_order
    product = products(:featured)
    customer = users(:customer)
    cart = Cart.create!(user: customer, status: :completed, currency: "EGP")
    cents = (product.price * 100).round
    order = Order.create!(user: customer, branch: branches(:main), cart:, number: "API-CANCEL-#{SecureRandom.hex(4)}",
      status: :submitted, payment_method: :cash_on_delivery, payment_status: :unpaid, delivery_method: :standard,
      currency: "EGP", subtotal_cents: cents, discount_cents: 0, loyalty_discount_cents: 0,
      delivery_fee_cents: 0, delivery_discount_cents: 0, prescription_adjustment_cents: 0,
      total_cents: cents, wallet_paid_cents: 0, customer_email: customer.email,
      customer_mobile_number: customer.mobile_number, customer_first_name: customer.first_name,
      customer_last_name: customer.last_name, submitted_at: Time.current)
    order.items.create!(product:, product_name: product.name, product_slug: product.slug, brand_name: product.brand.name,
      category_name: product.category.name, quantity: 1, unit_price_cents: cents, original_unit_price_cents: cents,
      final_unit_price_cents: cents, discount_cents: 0, line_total_cents: cents, requires_prescription: false)
    order
  end
end

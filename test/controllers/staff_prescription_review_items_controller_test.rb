require "test_helper"

class StaffPrescriptionReviewItemsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pharmacist = users(:pharmacist)
    @admin = users(:admin)
    @customer = users(:customer)
    @product = products(:featured)
    @product.update!(requires_prescription: true)
    @order = build_order
    @item = Prescriptions::EnsureReview.call(@order.prescription).items.first
  end

  test "customer and order manager get not found while pharmacist and admin can view" do
    %i[customer order_manager inventory_manager].each do |role|
      sign_in users(role)
      get staff_prescription_path(@order.prescription)
      assert_response :not_found
      sign_out users(role)
    end
    sign_in @pharmacist
    get staff_prescription_path(@order.prescription)
    assert_response :success
    sign_out @pharmacist
  end

  test "only pharmacist can decide a line over direct HTTP requests" do
    sign_in users(:order_manager)
    patch decide_staff_prescription_review_item_path(@order.prescription, @item),
      params: { decision: "approved", reason: "محاولة غير مصرح بها" }
    assert @item.reload.pending?
    sign_out users(:order_manager)

    sign_in @admin
    patch decide_staff_prescription_review_item_path(@order.prescription, @item),
      params: { decision: "approved", reason: "محاولة إدارية" }
    assert @item.reload.pending?
    sign_out @admin

    sign_in @pharmacist
    patch decide_staff_prescription_review_item_path(@order.prescription, @item),
      params: { decision: "approved", reason: "اعتماد موثق" }
    assert_redirected_to staff_prescription_path(@order.prescription)
    assert @item.reload.approved?
  end

  test "decide is line specific and cannot touch another item via forged params" do
    other_order = build_order(number_suffix: "OTHER")
    other_item = Prescriptions::EnsureReview.call(other_order.prescription).items.first

    sign_in @pharmacist
    patch decide_staff_prescription_review_item_path(@order.prescription, @item),
      params: { decision: "approved", reason: "اعتماد" }
    assert @item.reload.approved?
    assert other_item.reload.pending?
  end

  private

  def build_order(number_suffix: nil)
    cart = @customer.carts.active.first || @customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    cart.items.create!(product: @product, quantity: 1)
    cart.ensure_checkout_submission_token!
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf")
    result = Orders::CreateFromCart.new(user: @customer, cart:, address_id: addresses(:home).id,
      delivery_method: "standard", payment_method: "cash_on_delivery",
      submission_token: cart.checkout_submission_token, prescription_files: [ file ]).call
    assert result.success?, result.errors.inspect
    result.order
  end
end

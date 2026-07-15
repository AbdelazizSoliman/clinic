import { Controller } from "@hotwired/stimulus"
import { isWished, toggleWishlist } from "lib/shopping_store"

export default class extends Controller {
  static values = { productId: Number }
  static targets = ["button", "icon"]

  connect() {
    this.refresh = this.refresh.bind(this)
    window.addEventListener("pharmacy:wishlist-changed", this.refresh)
    this.refresh()
  }
  disconnect() { window.removeEventListener("pharmacy:wishlist-changed", this.refresh) }
  toggle() { toggleWishlist(this.productIdValue) }
  refresh() {
    const wished = isWished(this.productIdValue)
    this.buttonTarget.setAttribute("aria-pressed", wished)
    this.buttonTarget.setAttribute("aria-label", wished ? "إزالة المنتج من المفضلة" : "إضافة المنتج إلى المفضلة")
    this.iconTarget.textContent = wished ? "♥" : "♡"
    this.iconTarget.classList.toggle("text-rose-500", wished)
  }
}

import { Controller } from "@hotwired/stimulus"
import { wishlist, clearWishlist } from "lib/shopping_store"

export default class extends Controller {
  static targets = ["item", "empty", "content", "count"]
  connect() { this.refresh = this.refresh.bind(this); window.addEventListener("pharmacy:wishlist-changed", this.refresh); this.refresh() }
  disconnect() { window.removeEventListener("pharmacy:wishlist-changed", this.refresh) }
  clear() { if (window.confirm("هل تريد مسح كل المنتجات من المفضلة؟")) clearWishlist() }
  refresh() {
    const ids = wishlist().productIds
    this.itemTargets.forEach(item => item.classList.toggle("hidden", !ids.includes(Number(item.dataset.productId))))
    this.countTarget.textContent = ids.length; this.emptyTarget.classList.toggle("hidden", ids.length > 0); this.contentTarget.classList.toggle("hidden", ids.length === 0)
  }
}

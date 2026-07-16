import { Controller } from "@hotwired/stimulus"
import { wishlist } from "lib/shopping_store"

export default class extends Controller {
  static values = { type: String }
  static targets = ["badge"]
  connect() {
    this.refresh = this.refresh.bind(this)
    this.eventName = "pharmacy:wishlist-changed"
    window.addEventListener(this.eventName, this.refresh)
    this.refresh()
  }
  disconnect() { window.removeEventListener(this.eventName, this.refresh) }
  refresh() {
    const count = wishlist().productIds.length
    this.badgeTarget.textContent = count
    this.badgeTarget.classList.toggle("opacity-0", count === 0)
    this.element.setAttribute("aria-label", `المفضلة، ${count} منتجات`)
  }
}

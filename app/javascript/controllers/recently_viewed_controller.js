import { Controller } from "@hotwired/stimulus"
import { recordViewed, recentlyViewed } from "lib/shopping_store"

export default class extends Controller {
  static values = { currentId: Number }
  static targets = ["section", "item"]
  connect() {
    const previous = recentlyViewed().filter(id => id !== this.currentIdValue).slice(0, 8)
    this.itemTargets.forEach(item => item.classList.toggle("hidden", !previous.includes(Number(item.dataset.productId))))
    this.sectionTarget.classList.toggle("hidden", previous.length === 0)
    recordViewed(this.currentIdValue)
  }
}

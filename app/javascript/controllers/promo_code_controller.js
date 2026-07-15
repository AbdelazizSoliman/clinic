import { Controller } from "@hotwired/stimulus"
import { toast } from "lib/shopping_store"

export default class extends Controller {
  static targets = ["input", "button", "success", "error"]
  apply(event) {
    event.preventDefault(); this.buttonTarget.disabled = true; this.buttonTarget.textContent = "جارٍ التطبيق..."
    setTimeout(() => {
      const valid = this.inputTarget.value.trim().toUpperCase() === "WELCOME10"
      this.successTarget.classList.toggle("hidden", !valid); this.errorTarget.classList.toggle("hidden", valid)
      window.dispatchEvent(new CustomEvent("pharmacy:promo-changed", { detail: { percent: valid ? 10 : 0 } }))
      toast(valid ? "تم تطبيق خصم تجريبي 10٪" : "كود الخصم غير صحيح", valid ? "success" : "error")
      this.buttonTarget.disabled = false; this.buttonTarget.textContent = "تطبيق"
    }, 450)
  }
  remove() { this.inputTarget.value = ""; this.successTarget.classList.add("hidden"); window.dispatchEvent(new CustomEvent("pharmacy:promo-changed", { detail: { percent: 0 } })) }
}

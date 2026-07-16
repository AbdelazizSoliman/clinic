import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["form", "submit"]
  submit(event) {
    if (!this.formTarget.checkValidity()) { event.preventDefault(); this.formTarget.reportValidity(); return }
    this.submitTarget.disabled = true
    this.submitTarget.value = "جارٍ إرسال الطلب بأمان..."
  }
}

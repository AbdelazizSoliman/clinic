import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["form", "completion"]
  submit(event) {
    event.preventDefault()
    if (!this.formTarget.checkValidity()) { this.formTarget.reportValidity(); return }
    this.completionTarget.classList.remove("hidden"); document.body.classList.add("overflow-hidden"); this.completionTarget.querySelector("button").focus()
  }
  close() { this.completionTarget.classList.add("hidden"); document.body.classList.remove("overflow-hidden") }
}

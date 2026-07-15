import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading"]

  connect() {
    this.beforeFetch = () => this.loadingTarget.classList.remove("hidden")
    this.afterFetch = () => this.loadingTarget.classList.add("hidden")
    this.element.addEventListener("turbo:before-fetch-request", this.beforeFetch)
    this.element.addEventListener("turbo:frame-load", this.afterFetch)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-fetch-request", this.beforeFetch)
    this.element.removeEventListener("turbo:frame-load", this.afterFetch)
  }
}

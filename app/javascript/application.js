// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

window.addEventListener("storage", event => {
  if (event.key === "pharmacy_store_cart_v1") window.dispatchEvent(new CustomEvent("pharmacy:cart-changed"))
  if (event.key === "pharmacy_store_wishlist_v1") window.dispatchEvent(new CustomEvent("pharmacy:wishlist-changed"))
})

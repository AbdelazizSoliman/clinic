const WISHLIST_KEY = "pharmacy_store_wishlist_v1"
const RECENT_KEY = "pharmacy_store_recent_v1"
const VERSION = 1

function read(key, fallback) {
  try {
    const value = JSON.parse(localStorage.getItem(key))
    return value?.version === VERSION ? value : fallback
  } catch (_error) {
    localStorage.removeItem(key)
    return fallback
  }
}

function write(key, value, eventName) {
  localStorage.setItem(key, JSON.stringify(value))
  window.dispatchEvent(new CustomEvent(eventName, { detail: value }))
}

export function wishlist() {
  const value = read(WISHLIST_KEY, { version: VERSION, productIds: [] })
  value.productIds = Array.isArray(value.productIds) ? [...new Set(value.productIds.filter(Number.isInteger))] : []
  return value
}

export function isWished(productId) {
  return wishlist().productIds.includes(Number(productId))
}

export function toggleWishlist(productId) {
  const id = Number(productId)
  const state = wishlist()
  const adding = !state.productIds.includes(id)
  state.productIds = adding ? [...state.productIds, id] : state.productIds.filter(item => item !== id)
  write(WISHLIST_KEY, state, "pharmacy:wishlist-changed")
  toast(adding ? "تمت إضافة المنتج إلى المفضلة" : "تمت إزالة المنتج من المفضلة", "success")
  return adding
}

export function clearWishlist() {
  write(WISHLIST_KEY, { version: VERSION, productIds: [] }, "pharmacy:wishlist-changed")
  toast("تم مسح المفضلة", "information")
}

export function recentlyViewed() {
  return read(RECENT_KEY, { version: VERSION, productIds: [] }).productIds || []
}

export function recordViewed(productId) {
  const id = Number(productId)
  const productIds = [id, ...recentlyViewed().filter(item => item !== id)].slice(0, 8)
  write(RECENT_KEY, { version: VERSION, productIds }, "pharmacy:recent-changed")
}

export function toast(message, type = "information") {
  window.dispatchEvent(new CustomEvent("pharmacy:toast", { detail: { message, type } }))
}

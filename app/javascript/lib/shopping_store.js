const CART_KEY = "pharmacy_store_cart_v1"
const WISHLIST_KEY = "pharmacy_store_wishlist_v1"
const RECENT_KEY = "pharmacy_store_recent_v1"
const VERSION = 1
const MAX_QUANTITY = 10

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

export function catalog() {
  try {
    return JSON.parse(document.getElementById("product-catalog")?.textContent || "{}")
  } catch (_error) {
    return {}
  }
}

export function cart() {
  const value = read(CART_KEY, { version: VERSION, items: [] })
  value.items = Array.isArray(value.items) ? value.items.filter(item => Number.isInteger(item.productId) && Number.isInteger(item.quantity) && item.quantity > 0) : []
  return value
}

export function cartQuantity() {
  return cart().items.reduce((sum, item) => sum + item.quantity, 0)
}

export function quantityFor(productId) {
  return cart().items.find(item => item.productId === Number(productId))?.quantity || 0
}

export function setQuantity(productId, quantity, { announce = true } = {}) {
  const id = Number(productId)
  const product = catalog()[id]
  if (!product || !product.available) {
    toast("هذا المنتج غير متوفر حاليًا", "error")
    return 0
  }

  const requested = Math.max(0, Math.floor(Number(quantity) || 0))
  const finalQuantity = Math.min(requested, MAX_QUANTITY, product.stockQuantity)
  const state = cart()
  state.items = state.items.filter(item => item.productId !== id)
  if (finalQuantity > 0) state.items.push({ productId: id, quantity: finalQuantity })
  write(CART_KEY, state, "pharmacy:cart-changed")
  if (requested > finalQuantity) toast(`الحد الأقصى المتاح ${finalQuantity} قطع`, "warning")
  else if (announce) toast(finalQuantity ? "تم تحديث الكمية" : "تمت إزالة المنتج من السلة", "success")
  return finalQuantity
}

export function addToCart(productId, quantity = 1) {
  const id = Number(productId)
  const product = catalog()[id]
  if (!product?.available) return setQuantity(id, quantity)
  const result = setQuantity(id, quantityFor(id) + Number(quantity), { announce: false })
  if (result) {
    toast("تمت إضافة المنتج إلى السلة", "success")
    if (product.prescription) toast("سيُطلب مراجعة الروشتة قبل تأكيد الطلب", "information")
  }
  return result
}

export function clearCart() {
  write(CART_KEY, { version: VERSION, items: [] }, "pharmacy:cart-changed")
  toast("تم إفراغ سلة التسوق", "information")
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

export function validCartItems() {
  const products = catalog()
  return cart().items.map(item => ({ ...item, product: products[item.productId] })).filter(item => item.product)
}

export function cartNeedsAttention() {
  const items = validCartItems()
  return items.length !== cart().items.length || items.some(item => !item.product.available)
}

export function subtotalCents() {
  return validCartItems().filter(item => item.product.available).reduce((sum, item) => sum + item.product.priceCents * item.quantity, 0)
}

export function formatMoney(cents) {
  return `${new Intl.NumberFormat("ar-EG", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(cents / 100)} ج.م`
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"]/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" })[character])
}

export function cartItemMarkup(item, compact = false) {
  const { product, quantity } = item
  const unavailable = !product.available
  return `<article class="${compact ? "p-3" : "p-4"} rounded-2xl border border-slate-200 bg-white" data-product-id="${product.id}">
    <div class="flex gap-3">
      <a href="${product.url}" class="grid size-20 shrink-0 place-items-center rounded-xl bg-pharmacy-50 text-3xl" aria-label="عرض ${escapeHtml(product.name)}">💊</a>
      <div class="min-w-0 flex-1"><p class="text-xs font-bold text-pharmacy-600">${escapeHtml(product.brand)}</p><a href="${product.url}" class="mt-1 block font-black leading-6">${escapeHtml(product.name)}</a>
        ${unavailable ? '<p class="mt-1 text-xs font-bold text-rose-600">غير متوفر — مستبعد من الإجمالي</p>' : ""}
        <p class="mt-1 text-sm font-black text-pharmacy-700">${formatMoney(product.priceCents)}</p></div>
      <button type="button" data-cart-action="remove" class="self-start text-sm text-rose-600" aria-label="إزالة ${escapeHtml(product.name)}">حذف</button>
    </div>
    <div class="mt-3 flex items-center justify-between gap-3">
      <div class="inline-flex items-center rounded-xl border border-slate-300" aria-label="كمية ${escapeHtml(product.name)}">
        <button type="button" data-cart-action="increase" class="grid size-10 place-items-center font-black" aria-label="زيادة الكمية">+</button>
        <input data-cart-action="quantity" type="number" min="1" max="10" value="${quantity}" class="w-12 border-x border-slate-200 py-2 text-center text-sm font-black" aria-label="الكمية">
        <button type="button" data-cart-action="decrease" class="grid size-10 place-items-center font-black" aria-label="تقليل الكمية">−</button>
      </div>
      <p class="font-black">${unavailable ? "—" : formatMoney(product.priceCents * quantity)}</p>
    </div></article>`
}

export function checkoutItemMarkup(item) {
  const { product, quantity } = item
  return `<article class="flex gap-3 rounded-xl border border-slate-200 p-3"><span class="grid size-14 shrink-0 place-items-center rounded-lg bg-pharmacy-50 text-2xl">💊</span><div class="min-w-0 flex-1"><a href="${product.url}" class="block truncate text-sm font-black">${escapeHtml(product.name)}</a><p class="mt-1 text-xs text-slate-500">${quantity} × ${formatMoney(product.priceCents)}</p></div><strong class="text-sm">${product.available ? formatMoney(product.priceCents * quantity) : "غير متوفر"}</strong></article>`
}

export function toast(message, type = "information") {
  window.dispatchEvent(new CustomEvent("pharmacy:toast", { detail: { message, type } }))
}

export { MAX_QUANTITY }

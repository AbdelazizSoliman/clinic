# Visual gallery

These images were captured from the real Rails application with the deterministic
fictional demo dataset. Desktop captures use 1440 × 1000 CSS pixels and mobile
captures use 390 × 844. Passwords, TOTP values, recovery codes, storage URLs,
and real personal or medical data are not shown.

## Customer experience

![Arabic RTL pharmacy storefront with search, categories, cart, and promotional hero](images/portfolio/desktop/01-arabic-storefront.png)

**Arabic storefront** — customer role; storefront home. The reviewer should
notice the RTL information hierarchy, Arabic product discovery, and responsive
commerce navigation.

![Arabic product search results showing the deterministic demo catalog](images/portfolio/desktop/02-product-search.png)

**Catalog search** — customer role; deterministic product search. It demonstrates
search, filtering, availability, and promotion-aware catalog presentation.

![Arabic cart showing seeded products, active coupon, and calculated totals](images/portfolio/desktop/04-cart-coupon.png)

**Cart and coupon** — customer role; active cart with coupon `DEMO10`. Product,
discount, and total calculations remain visible before checkout.

![Arabic checkout form with fictional address and delivery-zone selection](images/portfolio/desktop/05-checkout-delivery.png)

**Checkout and delivery** — customer role; seeded fictional address and delivery
zone. Coverage, fee, and cash-on-delivery policy are validated together.

![Delivered Arabic order detail with immutable commercial snapshot and timeline](images/portfolio/desktop/06-delivered-order.png)

**Delivered order** — customer role; stable order `DEMO-DELIVERED-OLD`. The view
shows historical totals and workflow progress without relying on current catalog
values.

## Prescription workflow

![Prescription-required product detail with controlled upload guidance](images/portfolio/desktop/03-prescription-product.png)

**Prescription entry point** — customer role; SKU `RX-A100`. The product declares
its prescription rule before checkout.

![Customer prescription order status without exposing prescription document contents](images/portfolio/desktop/07-prescription-order.png)

**Customer prescription state** — customer role; seeded prescription order. The
customer sees workflow state while private document content remains outside the
portfolio image.

![Pharmacist queue filtered to the seeded prescription under review](images/portfolio/desktop/08-pharmacist-queue.png)

**Pharmacist queue** — pharmacist role; order
`DEMO-PRESCRIPTION-REVIEW`. It shows a focused medical-work queue without
granting general administration access.

![Pharmacist prescription detail showing scan and review state](images/portfolio/desktop/09-prescription-review.png)

**Review detail** — pharmacist role; the same stable order. Explicit scan and
review states gate the decision; no prescription content is reproduced here.

## Fulfilment

![Arabic staff fulfilment board with preparing, ready, dispatched, and delivered demo orders](images/portfolio/desktop/10-fulfilment-workflow.png)

**Fulfilment board** — order-manager role; stable orders including
`DEMO-PREPARING`, `DEMO-READY`, and `DEMO-OUT-FOR-DELIVERY`. The board connects
operational hand-offs to order state.

## Inventory

![Arabic inventory dashboard separating physical, reserved, and available stock](images/portfolio/desktop/11-inventory-dashboard.png)

**Inventory dashboard** — inventory-manager role; deterministic healthy, low,
zero, and reserved stock. The separate quantities make availability auditable.

![Append-only Arabic inventory movement history for demo stock changes](images/portfolio/desktop/12-inventory-movements.png)

**Movement history** — inventory-manager role; opening balances and order
consumption. Reviewers can trace physical changes to stable business references.

## Administration and reporting

![Arabic promotion detail showing active demo coupon scope and constraints](images/portfolio/desktop/13-promotions-coupon.png)

**Promotion and coupon** — administrator role; promotion `demo:active-cart` and
coupon `DEMO10`. Scope, timing, and limits are explicit.

![Arabic reports dashboard with sales and operational summary cards](images/portfolio/desktop/14-reports-dashboard.png)

**Reports dashboard** — administrator role; last 30 days. The page connects
commerce totals, available stock, prescription workload, and fulfilment status.

![Arabic user administration filtered to fictional demo accounts](images/portfolio/desktop/15-admin-users.png)

**User administration** — administrator role; fictional `example.test`
accounts. Roles and account states are visible without exposing credentials.

## Guided demo

![Arabic guided demo center with role-aware journeys and fictional-data notice](images/portfolio/desktop/16-guided-demo.png)

**Guided demo center** — customer role; `/demo`. Stable scenario links are
resolved under normal authorization, with no impersonation or authentication
bypass.

## Mobile experience

| Storefront | Product catalog |
| --- | --- |
| ![Narrow Arabic storefront with readable demo banner and mobile navigation](images/portfolio/mobile/17-mobile-storefront.png) | ![Narrow Arabic product listing with responsive cards](images/portfolio/mobile/18-mobile-products.png) |

| Cart | Guided demo |
| --- | --- |
| ![Narrow Arabic cart with unclipped totals and controls](images/portfolio/mobile/19-mobile-cart.png) | ![Narrow Arabic guided demo center with stacked journey cards](images/portfolio/mobile/20-mobile-demo.png) |

![Narrow pharmacist review queue with stacked filters and seeded review record](images/portfolio/mobile/21-mobile-pharmacist.png)

**Mobile staff queue** — pharmacist role; 390-pixel viewport. Filters and the
seeded review row remain usable without horizontal document overflow.

## Practical visual review

The capture pass confirmed RTL document direction, 390-pixel layout without
document-level horizontal overflow, visible headings and labelled controls, and
normal password-plus-TOTP navigation for privileged roles. It was a practical
browser review, not a formal WCAG conformance audit. Dense operational tables
remain best suited to desktop even though their surrounding pages are usable on
a narrow viewport.

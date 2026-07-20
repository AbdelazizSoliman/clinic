# Screenshot plan

Phase 15E captured this plan from one isolated deterministic demo database using
fictional data only. The reviewed images live under `docs/images/portfolio/` and
are presented in the [visual gallery](visual_gallery.md).

Recommended viewports:

- Desktop: 1440 × 1000 CSS pixels.
- Mobile: 390 × 844 CSS pixels.
- Use a tablet viewport only when it explains a responsive transition not shown
  by desktop/mobile.

| # | Screen | Role / stable scenario | Viewport | Prepared state | Hide / inspect | Caption and business value |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Storefront home/catalog | Customer; `/` or `/products` | Desktop | Fresh demo seed, featured products visible | Browser account UI, local host/path | “Arabic RTL catalog with availability and promotion states” — product discovery. |
| 2 | Search/filter results | Customer; `/products`, search a demo term and category | Desktop | Several matching products | Query values that contain personal data | “Search and filtering keep the Arabic catalog navigable” — discovery efficiency. |
| 3 | Product detail | Customer; slug `demo-rx-tablets-a` or a featured ordinary slug | Desktop | Show stock/prescription badge | No storage URL in address bar | “Product rules are visible before purchase” — informed ordering. |
| 4 | Cart with coupon | Customer; seeded active cart, coupon `DEMO10` | Desktop | Coupon already applied and totals calculated | Any session token | “Cart pricing combines product, coupon, and stock validation” — transparent totals. |
| 5 | Checkout and delivery | Customer; `/checkout` | Desktop | Seeded address/zone, standard delivery selected | Full fictional phone/address if unnecessary; never use real data | “Delivery coverage, fee, and payment policy are validated at checkout.” |
| 6 | Customer order history/detail | Customer; `DEMO-DELIVERED-OLD` | Desktop | Timeline and snapshots visible | Email/mobile can be cropped even though fictional | “Historical order snapshots remain stable after catalog changes.” |
| 7 | Prescription submission | Customer; prescription product checkout | Desktop | Use synthetic fixture only; stop before unwanted mutation if needed | Filename, raw blob identifiers | “Prescription-required products enter a controlled private review flow.” |
| 8 | Pharmacist review queue | Pharmacist; search `DEMO-PRESCRIPTION-REVIEW` | Desktop | Pending/under-review rows visible | Customer contact data and document previews | “Pharmacists see a focused review queue, not unrestricted administration.” |
| 9 | Prescription decision detail | Pharmacist; order `DEMO-PRESCRIPTION-REVIEW` | Desktop | Clean scan state visible | Document contents; crop to state/actions | “Scan gating and explicit review states protect the order decision.” |
| 10 | Fulfilment board | Order manager; `DEMO-PREPARING`, `DEMO-READY`, `DEMO-OUT-FOR-DELIVERY` | Desktop | Multiple workflow states visible | Customer address/contact | “Order staff move work through preparation and dispatch states.” |
| 11 | Inventory dashboard | Inventory manager; `/admin` | Desktop | Healthy, low, zero, and reserved quantities | Cost fields if not needed for caption | “Physical, reserved, and available stock are shown separately.” |
| 12 | Inventory movements | Inventory manager; `/admin/inventory_adjustments` | Desktop | Opening and reservation-consumption movements visible | Actor contact data | “Append-only movements explain every physical stock change.” |
| 13 | Promotions and coupons | Admin; promotion `demo:active-cart`, coupon `DEMO10` | Desktop | Active, future, and expired examples available | Internal user IDs | “Promotion scope, timing, and limits are explicit and auditable.” |
| 14 | Reports dashboard | Admin; `preset=last_30_days` | Desktop | Recent and older demo orders included | Export URLs, detailed customer filters | “Role-scoped reports connect commerce and operations.” |
| 15 | Users or pharmacy settings | Admin; `/admin/users` or settings edit | Desktop | Demo users filtered by `@example.test` | Emails may stay fictional; hide security recovery material | “Administration separates users, roles, and operational settings.” |
| 16 | Guided demo control center | Any seeded role; `/demo` | Desktop | Current role highlighted | Passwords/TOTP must never be present | “Role-aware journeys make a complex workflow reviewable without bypassing authorization.” |
| 17 | Mobile storefront | Customer; home/catalog/cart | 390 × 844 | Product grid and navigation at mobile breakpoint | Browser notifications/autofill | “The Arabic shopping flow adapts to a narrow RTL viewport.” |
| 18 | Mobile staff workflow | Pharmacist or order manager; queue/detail | 390 × 844 | One high-value seeded record | Customer contact/document contents | “Operational tasks remain readable and keyboard/touch accessible on mobile.” |

## Capture procedure

1. Record the commit and run `DEMO_MODE=true bin/rails demo:seed` against an
   isolated local/demo database.
2. Verify each account and TOTP through normal authentication.
3. Use the same seed, date context, browser theme, zoom, and viewport sizes.
4. Prefer existing historical examples over mutating them. If a live order is
   created, reseed only after confirming the dataset remains coherent.
5. Clear flash errors and close developer tools before capture.
6. Inspect the DOM and address bar for tokens, signed storage URLs, local file
   paths, or secrets. Crop browser chrome consistently where appropriate.
7. Confirm Arabic fonts, RTL order, focus/hover state, contrast, and absence of
   horizontal overflow.
8. Optimize final assets and add descriptive alt text only after reviewed image
   files exist.

Never capture real personal/medical data, passwords, TOTP/recovery codes,
developer consoles, SMTP/storage configuration, stack traces, or a public
prescription object URL.

## Capture manifest

All retained files are PNGs captured at 100% browser zoom. Stable identifiers
describe reproducibility; database primary keys are intentionally omitted.

| File | Role | Stable scenario | Result |
| --- | --- | --- | --- |
| `desktop/01-arabic-storefront.png` | Customer | Storefront home | Captured |
| `desktop/02-product-search.png` | Customer | Demo catalog search | Captured |
| `desktop/03-prescription-product.png` | Customer | SKU `RX-A100` | Captured |
| `desktop/04-cart-coupon.png` | Customer | Active cart / `DEMO10` | Captured |
| `desktop/05-checkout-delivery.png` | Customer | Seeded address and delivery zone | Captured |
| `desktop/06-delivered-order.png` | Customer | `DEMO-DELIVERED-OLD` | Captured |
| `desktop/07-prescription-order.png` | Customer | Seeded prescription order | Captured |
| `desktop/08-pharmacist-queue.png` | Pharmacist | `DEMO-PRESCRIPTION-REVIEW` | Captured |
| `desktop/09-prescription-review.png` | Pharmacist | `DEMO-PRESCRIPTION-REVIEW` | Captured |
| `desktop/10-fulfilment-workflow.png` | Order manager | Preparing/ready/dispatched demo orders | Captured |
| `desktop/11-inventory-dashboard.png` | Inventory manager | Deterministic stock summary | Captured |
| `desktop/12-inventory-movements.png` | Inventory manager | Opening and consumption movements | Captured |
| `desktop/13-promotions-coupon.png` | Administrator | `demo:active-cart` / `DEMO10` | Captured |
| `desktop/14-reports-dashboard.png` | Administrator | Last 30 days | Captured |
| `desktop/15-admin-users.png` | Administrator | Fictional `example.test` users | Captured |
| `desktop/16-guided-demo.png` | Customer | `/demo` customer journey | Captured |
| `mobile/17-mobile-storefront.png` | Customer | Storefront home | Captured |
| `mobile/18-mobile-products.png` | Customer | Demo catalog | Captured |
| `mobile/19-mobile-cart.png` | Customer | Active cart / `DEMO10` | Captured |
| `mobile/20-mobile-demo.png` | Customer | `/demo` customer journey | Captured |
| `mobile/21-mobile-pharmacist.png` | Pharmacist | `DEMO-PRESCRIPTION-REVIEW` | Captured |

## Capture verification

- Isolated database: `clinic_phase15e_demo`; `demo:seed` returned the same typed
  manifest on two consecutive runs.
- Delivery/storage boundaries: local Active Storage, file mail delivery,
  logging-only error reporting, and deterministic clean scanner adapter. No
  production or shared service was contacted.
- Authentication: customer password flow and privileged password-plus-current
  TOTP flow were used; no bypass was added.
- Browser: installed Windows Chrome was controlled from WSL through the Chrome
  DevTools protocol because no supported Linux browser executable was available
  and Selenium Manager's bounded download did not complete.
- Browser observations: retained journeys reported zero JavaScript console
  errors, zero failed network loads, `dir="rtl"`, and no document-level overflow
  at 1440 or 390 CSS pixels after narrow fixes.
- Sanitization: reviewed captures contain no password, OTP, recovery code,
  token, signed storage URL, Rails exception page, developer UI, real personal
  data, or prescription content. Fictional demo names/emails appear only in
  intended workflow and administration views.
- Optimization: the 21 RGB PNG files total approximately 1.7 MB. No PNG
  optimizer or metadata utility was available, so no lossy or unverified rewrite
  was performed.

Tablet and Safari/iPhone-specific captures remain deferred because those browser
environments were unavailable. The 390-pixel Chrome captures provide the mobile
evidence for this phase.

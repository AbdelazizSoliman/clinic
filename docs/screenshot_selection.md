# Screenshot selection for external presentation

All recommendations use the reviewed Phase 15E captures in the
[visual gallery](visual_gallery.md). Ranking favors a coherent story, visual
clarity, role coverage, and evidence of engineering depth. It does not imply
that a screenshot alone proves the underlying control; code and test links are
in the [reviewer guide](reviewer_guide.md).

## Top 5

1. **[Arabic storefront](images/portfolio/desktop/01-arabic-storefront.png)** —
   establishes the Arabic RTL product, customer context, and overall visual
   quality immediately.
2. **[Cart and coupon](images/portfolio/desktop/04-cart-coupon.png)** — shows a
   concrete commerce decision with products, discount, stock, and totals before
   checkout.
3. **[Pharmacist review](images/portfolio/desktop/09-prescription-review.png)** —
   differentiates the application from generic commerce through scan gating,
   private workflow, and explicit decisions without exposing document content.
4. **[Inventory dashboard](images/portfolio/desktop/11-inventory-dashboard.png)** —
   makes physical, reserved, and available stock visible and supports the
   strongest integrity story.
5. **[Fulfilment workflow](images/portfolio/desktop/10-fulfilment-workflow.png)** —
   connects customer orders to staff hand-offs across preparation, readiness,
   dispatch, and delivery.

This set is the smallest complete narrative: customer experience, commercial
calculation, pharmacy-specific review, inventory integrity, and operations.

## Top 8

Use the top five plus:

6. **[Reports dashboard](images/portfolio/desktop/14-reports-dashboard.png)** —
   closes the operational loop with role-scoped sales and workload visibility.
7. **[Guided demo center](images/portfolio/desktop/16-guided-demo.png)** — shows
   that complex role journeys are deliberately reviewable through stable
   fictional scenarios and normal authorization.
8. **[Mobile storefront](images/portfolio/mobile/17-mobile-storefront.png)** —
   supplies compact evidence of responsive RTL behavior at 390 pixels.

This set adds reporting, demonstration maturity, and responsive coverage while
remaining short enough for a README or marketplace gallery.

## Top 12

Use the top eight plus:

9. **[Checkout and delivery](images/portfolio/desktop/05-checkout-delivery.png)** —
   demonstrates address/zone matching, delivery policy, fee visibility, and the
   implemented cash-on-delivery boundary.
10. **[Delivered order](images/portfolio/desktop/06-delivered-order.png)** — shows
    customer history, timeline, and the visible result of immutable commercial
    snapshots.
11. **[Inventory movements](images/portfolio/desktop/12-inventory-movements.png)** —
    complements the inventory dashboard with an append-only explanation of
    physical changes.
12. **[Promotion and coupon](images/portfolio/desktop/13-promotions-coupon.png)** —
    shows scope, timing, limits, and administrative auditability behind the
    customer-facing discount.

This larger set supports a technical presentation because it pairs interfaces
with the checkout, history, ledger, and promotion concepts behind them.

## Platform recommendations

| Platform | Recommended captures | Reason |
| --- | --- | --- |
| README | Top 8 in four paired rows | Broad orientation without turning the project page into the full gallery. |
| LinkedIn Featured | Storefront, pharmacist review, inventory dashboard, fulfilment workflow, mobile storefront | Five images tell the product and differentiation story quickly; link to the repository for depth. |
| Upwork | Storefront, cart, pharmacist review, fulfilment workflow, inventory dashboard, reports dashboard | Client-facing value is visible across customer, pharmacy, stock, delivery, and management work. |
| Presentation slides | Top 12, normally one image per workflow slide | The deck has room to connect each visual to architecture, consistency, and role boundaries. |

## Use and caption guidance

- Keep the original aspect ratio; crop only consistent browser chrome or
  fictional contact details that do not support the point.
- Pair each image with one business observation and one technical observation.
- State that all data is deterministic and fictional at first use.
- Never show passwords, TOTP/recovery codes, signed storage URLs, prescription
  contents, local paths, developer tools, stack traces, or service settings.
- Do not use the admin-users screen in short public sets; it is useful in a live
  role tour but carries less product meaning and displays fictional emails.
- Use mobile cart or pharmacist captures only when the audience asks about a
  specific narrow workflow. Dense operational work remains easier to explain
  from desktop captures.

## Captures intentionally below the top 12

Product search, the prescription-product entry point, customer prescription
status, pharmacist queue, admin users, and the remaining mobile views are valid
supporting evidence. They are omitted from the ranked sets because adjacent
captures communicate the same themes with more workflow or engineering context.


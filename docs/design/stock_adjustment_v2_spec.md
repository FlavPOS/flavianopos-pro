# Stock Adjustment Screen v2 — Premium Redesign

## Theme
- Background: #F4F6F8
- Card: #FFFFFF
- Primary Blue: #1565C0
- Success Green: #22C55E
- Danger Red: #EF4444
- Primary Text: #111827
- Secondary Text: #6B7280
- Font: Inter
- Rounded corners: 16px
- Grid: 8px

## Structure
1. Blue AppBar (← 📦 Stock Adjustment ⋮)
2. 4 stat cards (Items / Adds / Deducts / Cost Impact)
3. Rounded search bar (SKU/Product + filter icon)
4. Collapsible product cards (100px collapsed)
   - Left accent: Green (add) / Red (deduct)
   - Product thumbnail + name + SKU + category badge
   - "OH: 15 → 20" | Large ±N badge | Cost impact
5. Expanded card:
   - Current Stock → New Stock → Adjustment blocks
   - Large qty stepper [-] N [+]
   - Reason dropdown (Receiving Error, Damaged, Expired, ...)
   - Multi-line remarks
   - Cost impact (large, colored)
6. FAB (blue, "+") bottom-right
7. Bottom sticky bar: Items | Total Cost | Save Adjustment (N)
8. Empty state: illustration + arrow to FAB

## Typography
- Title: 22px Bold
- Card Title: 18px SemiBold
- Product Name: 17px Bold
- Body: 14px Regular
- Labels: 13px Medium
- Caption: 12px Regular
- Numbers: 22px Bold

## Animations
- Card expand: 200ms Ease-In-Out
- Button ripple
- FAB scale

## Inspiration
SAP Fiori, Oracle Fusion, Microsoft Dynamics 365, Zoho Inventory

## Reference Screens
See attached mockups (3-screen flow: empty, list, expanded)

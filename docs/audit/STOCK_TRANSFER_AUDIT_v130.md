# STOCK TRANSFER MODULE — FULL AUDIT
Version: v1.0.58+130
Date: 2026-07-14
Status: IN PROGRESS

## Test Environment
- HO001 (Head Office) — sender
- BR006 (Cebu Branch) — receiver
- URL: https://flaviano-pos.web.app
- Browser: Chrome + Incognito for multi-device

## Legend
- OK = Working correctly
- FAIL = Bug found (add screenshot/notes)
- PARTIAL = Works but needs improvement
- SKIP = Not applicable

===============================================
PHASE A: PREPARE FLOW (Draft/Submit)
===============================================

A1. Create IST with 1 batch
    Steps:
    - HO001 UI - Prepare Stock Transfer
    - Select item with batches
    - Pick 1 batch, qty 5
    - Save as Draft
    Expected: Draft appears in Outbound Hub - Draft tab
    Status: [   ]

A2. Create IST with multiple batches
    Steps: Same but pick 2-3 batches
    Expected: All batches saved to draft
    Status: [   ]

A3. Edit existing draft
    Steps: Open draft - modify batch qty - save
    Expected: Changes persist
    Status: [   ]

A4. Delete draft
    Steps: Open draft - delete button
    Expected: Draft removed - no data corruption
    Status: [   ]

A5. Submit draft
    Steps: Prepare - Submit button
    Expected: Status becomes SUBMITTED - moves to Submitted tab
    Status: [   ]

A6. Verify Firebase upload (Submitted)
    Check: F12 Console for TRANSFER-FB Uploaded log
    Firebase Console: companies/101/interStoreTransfers/IST-... should exist with batches array
    Status: [   ]

===============================================
PHASE B: APPROVE / DISPATCH
===============================================

B1. Approve submitted transfer
    Steps: HO001 - Submitted tab - open IST - Approve button - PIN
    Expected:
    - Status changes to FLOATING
    - Moves to Approved/Floating tab
    Status: [   ]

B2. HO001 SOH decreases correctly
    Before dispatch: Note HO001 Sinandomeng qty (e.g., 100)
    Dispatch 5 pcs
    After dispatch: Should be 95
    Status: [   ]

B3. Batches PRESERVED in Firebase after approve
    Check: Firebase Console - companies/101/interStoreTransfers/IST-... batches array still there
    (This was the v1.0.57+108 fix)
    Status: [   ]

B4. BR006 sees new IST in Pending Receipt
    Steps: BR006 tab - Inbound Hub - Pending Receipt
    Expected: New IST appears with FLOATING status
    Status: [   ]

===============================================
PHASE C: RECEIVE - NO VARIANCE (Perfect Match)
===============================================

C1. Open Pending Receipt IST
    Steps: BR006 - Pending Receipt - click IST
    Expected: Receipt screen opens with batches loaded
    Status: [   ]

C2. Batches display correctly
    Expected:
    - Product row shows batches expandable (chevron)
    - Long-press opens dialog with same batches
    - Received qty pre-fills with issued qty
    Status: [   ]

C3. Confirm Full - no variance
    Steps: Leave qtys unchanged - Confirm Full - PIN
    Expected:
    - Status becomes RECEIVED
    - Moves to Received tab
    Status: [   ]

C4. BR006 SOH increases correctly
    Before receive: Note BR006 qty (e.g., 50)
    Receive 5 pcs
    After receive: Should be 55
    Status: [   ]

C5. Batches added to BR006 Batch Management
    Steps: BR006 - Batch Management - filter by product
    Expected: NEW batch entries appear with source=TRANSFER_IN
    Status: [   ]

C6. DUPLICATE batch merges qty
    Setup: BR006 already has "Sample 3" batch with qty 20
    Receive: Same "Sample 3" batch with qty 5
    Expected: Batch Management shows Sample 3 with qty 25 (NOT duplicate row)
    Status: [   ]

C7. Auto-print PDF at Confirm
    Expected 10-column layout:
    | SKU | Product | Unit Retail | Issued | Received | Short +/- | Retail Value | Var Value | Reason | Notes |
    All values consistent (ITEM SUBTOTAL = Grand Total)
    Status: [   ]

C8. UI auto-updates on both sides
    - HO001 sees status changed to RECEIVED
    - BR006 sees updated Batch Management immediately (no manual refresh)
    Status: [   ]

===============================================
PHASE D: RECEIVE WITH SHORT (Variance)
===============================================

D1. Reduce qty on 1 batch
    Steps: Change one batch received qty from 5 to 3
    Expected: Yellow short badge appears
    Status: [   ]

D2. Reason picker REQUIRED
    Try to confirm without picking reason
    Expected: Button DISABLED - Select Reason(s) message
    Status: [   ]

D3. Pick DAMAGED reason
    Steps: Tap DAMAGED chip
    Expected: Chip highlighted - Confirm button ENABLED
    Status: [   ]

D4. Add notes (optional)
    Steps: Type notes text
    Expected: Notes saved to varianceNotes field
    Status: [   ]

D5. Confirm Partial
    Steps: Confirm Partial button - PIN
    Expected:
    - Status becomes RECEIVED (NOT stuck at PARTIALLY_RECEIVED - v1.0.57+108)
    Status: [   ]

D6. POSTBACK fires
    Console logs to look for:
    - [POSTBACK] Created new POSTBACK-... at HO001
    - [POSTBACK-SOH] HO001/PRODUCT: XX + Y = ZZ Firebase-safe .set()
    - [POSTBACK] Summary: 1 batches returned to HO001
    Status: [   ]

D7. Postback batch created at HO001
    Check HO001 - Batch Management - filter POSTBACK
    Expected: New batch with source=POSTBACK
    Status: [   ]

D8. HO001 SOH restored partially
    Before dispatch: HO001 = 100
    After dispatch: HO001 = 95
    After BR006 short 2: HO001 should be 97 (95 + 2 postback)
    Status: [   ]

D9. Auto-print PDF shows variance
    Expected:
    - Received col shows 3 (not 5)
    - Short +/- shows -2
    - Retail Value = 3 x cost (received-based)
    - Variance Value = -2 x cost
    - Reason column = DAMAGED
    - Notes column = your notes
    Status: [   ]

===============================================
PHASE E: RECEIVE WITH OVERAGE
===============================================

E1. Increase qty on 1 batch
    Steps: Change received qty from 5 to 7
    Expected: Blue overage badge appears
    Status: [   ]

E2. Overage reason picker
    Expected reasons: EXTRA_PACKED, BONUS, UNKNOWN
    Status: [   ]

E3. Pick EXTRA_PACKED
    Confirm button enabled
    Status: [   ]

E4. Confirm - NO postback for overage
    Expected: NO [POSTBACK] logs (overage stays at receiver)
    Status: [   ]

E5. Variance value POSITIVE in PDF
    Expected:
    - Short +/- shows +2
    - Var Value shows positive amount
    - Reason = EXTRA_PACKED
    Status: [   ]

===============================================
PHASE F: REPORTS CONSISTENCY
===============================================

F1. Auto-print PDF (10 cols)
    Test after Confirm - all values match
    Status: [   ]

F2. Reprint PDF from detail screen (10 cols)
    Steps: Open received IST - Print button
    Same 10 columns - same values as auto-print
    Status: [   ]

F3. Reprint PDF from list card (10 cols)
    Steps: Received tab - click transfer - Print button
    Same 10 columns
    Status: [   ]

F4. Print All summary PDF (15 cols)
    Steps: Received tab - Print All button
    Expected 15 cols:
    IST No, From, To, Items, Iss, Rcv, +/-, Retail, Var, Reasons, Prep By, Prep Date, Rcv By, Rcv Date, Status
    Status: [   ]

F5. Export Excel SUMMARY sheet (16 cols)
    Steps: Received tab - Export Excel
    Open .xlsx - SUMMARY tab
    Expected 16 cols with Date first
    Status: [   ]

F6. Export Excel BATCHES sheet (18 cols)
    Same Excel file - BATCHES tab
    Expected 18 cols with full batch detail
    Status: [   ]

F7. All variance values MATCH across reports
    Compare Received qty in:
    - Auto-print PDF
    - Reprint PDF (detail)
    - Reprint PDF (list)
    - Summary PDF
    - Excel SUMMARY row
    - Excel BATCHES rows
    All should show same values
    Status: [   ]

F8. Grand Total = ITEM SUBTOTAL
    In all 10-col PDFs
    ITEM SUBTOTAL row should equal Grand Total row for same transfer
    Status: [   ]

===============================================
PHASE G: CROSS-BRANCH SYNC
===============================================

G1. HO001 changes reflect on BR006
    HO001 approves IST - BR006 sees it in Pending Receipt within seconds
    Status: [   ]

G2. BR006 changes reflect on HO001
    BR006 confirms receipt - HO001 sees status change to RECEIVED
    HO001 Batch Management gets postback batch (if variance)
    Status: [   ]

G3. Incognito test - new device
    Open new incognito - login as BR006
    Should see all latest data (Firebase sync on load)
    Status: [   ]

G4. Postback SOH updates issuer UI
    After BR006 postback - HO001 SOH auto-updates (no refresh needed)
    Status: [   ]

===============================================
PHASE H: EDGE CASES
===============================================

H1. Reject transfer
    Steps: BR006 Pending - Reject button - reason
    Expected: Status REJECTED - moves to Rejected tab
    Status: [   ]

H2. Rejected PDF shows rejection reason
    Print rejected IST - should show rejection reason
    Status: [   ]

H3. Cannot re-open received transfer
    Try to confirm again on RECEIVED status
    Expected: Not allowed (already final)
    Status: [   ]

H4. Empty transfer validation
    Try to submit IST with 0 items
    Expected: Error message
    Status: [   ]

H5. All zero received qty
    Set all batches to receivedQty=0
    Expected: Use REJECT flow instead of confirm
    Status: [   ]

===============================================
BUGS FOUND (Fill in as you find them)
===============================================

Bug 1:
Phase:
Description:
Steps to reproduce:
Screenshot:
Priority:

Bug 2:
Phase:
Description:
Steps to reproduce:
Screenshot:
Priority:

===============================================
AUDIT COMPLETE?
===============================================

Total tests: 50
Passed: 0
Failed: 0
Partial: 0
Skipped: 0

Overall Status: [   ]
- Ready for production
- Needs fixes (list bugs above)
- Requires re-audit

Auditor: Flaviano Dagondon
Date completed:

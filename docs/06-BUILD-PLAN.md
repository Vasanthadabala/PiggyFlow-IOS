# 06 — Build Plan

Phase-wise execution plan for PiggyFlow v2.0, mapped to [PRD.md](PRD.md).

**Rules that hold for every phase:**

* The app builds and runs at the end of every phase. No phase depends on a later one to compile.
* Every phase has testable exit criteria. "Done" is not a feeling.
* Sizing is relative (S / M / L), not calendar time — velocity is yours to judge.
* UI designs are assumed complete before any phase that ships a screen (Phases 4, 6, 7, 8, 9).

---

## Dependency graph

```
Phase 0  Prep & cleanup
    │
    ▼
Phase 1  Data model ──────────────────────────┐
    │                                         │
    ├──► Phase 2  Image storage ──┐           │
    │                             ├──► Phase 4  Capture flow ──► M1
    └──► Phase 3  Extraction ─────┘           │
                                              │
         Phase 5  Categorization ◄────────────┤
         Phase 6  Search & filters ◄──────────┤   (these four need
         Phase 7  Reports ◄───────────────────┤    Phase 1 only, and
         Phase 8  Export ◄────────────────────┘    can run in parallel)

         Phase 9  Notifications  ── independent, any time after Phase 1

Phase 10 Supabase backend ──► Phase 11 Cloud AI ──► Phase 12 AI extras
                                                        │
                                                        ▼
                                                  Phase 13 Hardening ──► Ship
```

**Critical path:** 0 → 1 → 2/3 → 4 → 10 → 11 → 13.
Phases 5–9 are parallelisable once Phase 1 lands and do not block the release path.

---

## Phase 0 — Prep & cleanup

**Size:** S · **Depends on:** nothing

Clear the decks before touching product code.

**Build**
* Add `.gitignore` (`build/`, `DerivedData/`, `.DS_Store`, `*.xcuserstate`, secrets).
* Delete `Features/Onboarding/LoginView.swift` — dead code, unreferenced.
* Replace the delete-and-retry fallback in `Core/Data/DataManager.swift` with a
  non-destructive failure path.
* Add `Config.xcconfig` (git-ignored) for Supabase URL / anon key; add a checked-in
  `Config.example.xcconfig`.
* Fix the ignored return value on `CloudSyncManager.pullAllRemoteData` — sync failures
  currently pass unnoticed.

**Exit criteria**
* `git status` is clean of build artefacts.
* App builds and launches.
* A corrupted store surfaces an error instead of silently wiping data.

> The `DataManager` fix matters more than it looks. It currently **deletes the user's
> database** when the container fails to open. Harmless today with no users; unrecoverable
> once there are.

---

## Phase 1 — Data model

**Size:** M · **Depends on:** 0 · **PRD:** Expense Storage, Categorization

The foundation. Everything else is gated on this.

**Build**
* Models: `Expense`, `LineItem`, `Category`, `Income`, `TrackerRecord`, `BillImageRef`,
  `CategorizationRule`.
* Enums: `AccountType`, `PaymentMethod`, `ExtractionSource`, `TrackerKind`, `CategoryKind`,
  `UploadState`.
* Category seeding on first launch — PRD expense set + income set, `isSystem = true`.
* `SyncBackend` protocol; keep the existing Firestore implementation behind it for now.
* Update manual entry and all existing screens to the new model.

**Exit criteria**
* App builds; existing screens (Home, Stats, Tracker, Settings) work against the new model.
* Categories seed once and only once.
* A manual expense saves with `accountType`, `categoryID`, and empty line items.
* Deleting an expense cascades to its line items.

---

## Phase 2 — Image storage

**Size:** M · **Depends on:** 1 · **PRD:** Expense Capture, Expense Storage

**Build**
* `ImageStore` protocol; `LocalImageStore` writing to Documents.
* **Relative** path storage — never absolute (container UUID changes across reinstalls).
* `ImageEnhancer` (Core Image): grayscale, contrast, denoise, deskew, downscale to ≤2000px.
* Thumbnail generation for list/strip display.
* Delete images when their expense is deleted.

**Exit criteria**
* An image saves, survives app relaunch, and reloads.
* Multi-image expenses preserve page order.
* Deleting an expense removes its image files from disk.
* Enhanced output is visibly cleaner than the input on a low-light receipt photo.

---

## Phase 3 — Extraction engine (on-device)

**Size:** L · **Depends on:** 1 · **PRD:** Expense Capture, AI Features

The hardest engineering in the project.

**Build**
* `ExtractedInvoice` + `Field<T>` (value + confidence).
* `ExpenseExtractor` protocol.
* `OnDeviceExtractor` — Vision OCR using **bounding boxes**, not flat text.
* Field heuristics: merchant, date (multi-format, reject future), invoice no., total (prefer
  *last* total line), tax, currency, payment method.
* Line-item parser using **x-coordinate clustering** to find the price column.
* `ExtractionCoordinator` with provider selection and fallback.
* **Fixture set of ~20 real bills** committed as test resources.

**Exit criteria**
* Across the fixture set: merchant, date and total detected on ≥80%.
* Line items detected on ≥60% of clearly columnar bills.
* Extraction completes in under 2s for a single page.
* Confidence values are populated and meaningfully vary.

> Build the fixture set **first**. Without it there is no way to tell whether a heuristic
> change helped or hurt, and heuristics will be tuned many times.

---

## Phase 4 — Capture flow ★

**Size:** L · **Depends on:** 2, 3 · **Needs designs** · **PRD:** Expense Capture, User Flow

The phase where the merged product becomes real.

**Build**
* Source picker sheet (Camera / Library).
* VisionKit document scanner integration; library multi-select.
* Processing screen — staged progress, provider indicator, cancel.
* **Review & Correct screen** — every field editable, low-confidence flagged, "not detected"
  states, line-item editor, line-item/total mismatch note.
* Save path → `Expense` + `LineItem`s + images.
* Wire the FAB in `MainTabView`: *Scan Bill* / *Add Manually*.

**Exit criteria**
* Photograph a real bill → saved expense in **under 30 seconds**.
* Capture-to-review in **under 5 seconds**.
* Every extracted field can be corrected before saving.
* Cancelling at any stage leaves no partial data.
* An unreadable bill still saves as a manual entry with the image attached.

**🏁 Milestone M1 — the product exists.**

---

## Phase 5 — Categorization & learning

**Size:** M · **Depends on:** 1 (better after 4) · **PRD:** Categorization, AI Features

**Build**
* Seed merchant rules (`indian oil → Fuel`, `swiggy → Food & Dining`, …) and keyword rules.
* `CategoryRuleEngine` — learned → merchant → keyword, first match wins.
* `CategoryLearningStore` — record corrections keyed on `merchantNormalized`, raise weight on repeats.
* Account-type inference (weak, always confirmable).
* Custom category creation; move expenses between categories.
* Set `wasCorrectedByUser` when an AI suggestion is changed.

**Exit criteria**
* A seeded merchant auto-categorizes correctly.
* Correcting a category once causes the same merchant to categorize correctly next time.
* Categorization accuracy is computable: `1 − (corrected / total)`.

---

## Phase 6 — Search & filters

**Size:** M · **Depends on:** 1 · **Needs designs** · **PRD:** Search & Filters

**Build**
* `TransactionQuery` — extracted from `HomeView`'s computed properties, unit-testable.
* Search across merchant, item name, category, tags, note, amount.
* Date presets: Today, Yesterday, This/Last Week, This/Last Month, Custom Range.
* Filters: account type, category, payment method, amount range, has-receipt.
* Removable filter chips; distinct empty-filtered vs empty-new states.

**Exit criteria**
* Searching a product name returns the bill it was printed on.
* All date presets return correct boundaries (verify week start and month edges).
* Results render with no perceptible delay on ~1,000 expenses.

---

## Phase 7 — Reports & dashboard

**Size:** M · **Depends on:** 1 · **Needs designs** · **PRD:** Reports & Dashboard

**Build**
* Summary cards: Total, Personal, Family, Business, Net Balance, Savings Rate.
* Charts: daily/weekly/monthly trend, category-wise, **merchant-wise**, **payment-method**.
* Reports: date / week / month / year / custom range.
* Range selector; empty state offering a range that has data.

**Exit criteria**
* Merchant and payment-method charts render (new capability from Phase 1).
* Any range returns instantly with no network call.
* Totals reconcile exactly with the underlying expense list.

---

## Phase 8 — Export

**Size:** M · **Depends on:** 7 · **Needs designs** · **PRD:** Export

**Build**
* Generalize the existing PDF exporter (`PDFTableRenderer` already exists) beyond one category.
* CSV writer (correct escaping for commas/quotes/newlines in merchant and item names).
* Excel writer (SpreadsheetML `.xlsx`).
* Contents selection: summary, itemized, category totals, merchant totals.
* Share sheet; generation off the main thread with cancel.

**Exit criteria**
* All three formats generate and open correctly in their target apps.
* A 12-month export does not block the UI.
* CSV with a merchant name containing a comma round-trips correctly.

---

## Phase 9 — Notifications

**Size:** S · **Depends on:** 1 · **Needs designs** · **PRD:** Notifications

**Build**
* `NotificationScheduler`; **contextual** permission request on first enable.
* Five reminders: upload today's bills, monthly summary, high-spend alert, missing-bills,
  tracker due.
* Settings toggles, all off by default.

**Exit criteria**
* Enabling a reminder requests permission and schedules it.
* A high-spend alert fires when a category exceeds its budget.
* Disabling cancels pending notifications.

> Today `UNUserNotificationCenter` is only used to *clear* notifications — nothing is ever
> scheduled. This phase makes reminders actually fire for the first time.

---

## Phase 10 — Supabase backend & sync

**Size:** L · **Depends on:** 1 · **⚠️ Needs credentials** · **PRD:** Accounts & Sync

**Build**
* SQL schema, indexes, `updated_at` triggers, soft-delete columns.
* **RLS enabled on every table**, `using` + `with check`.
* `bill-images` private bucket + storage policies.
* `supabase-swift` integration; `SupabaseAuthService` (Google + Apple).
* `SupabaseSyncBackend` implementing the existing protocol.
* `RemoteImageStore`; `CompositeImageStore` (local-first, background upload).
* Remove Firebase SDKs and `GoogleService-Info.plist`.

**Blocked on:** Supabase project URL + anon key.

**Exit criteria**
* Sign in with Google and Apple both work.
* An expense created on device A appears on device B.
* **Verified with a second test account that neither can read the other's rows.**
* Airplane mode: create, edit, delete all work; changes flush on reconnect.
* Skip-Setup local data is adopted on later sign-in.

> RLS verification is not optional. The anon key ships inside the app binary. Without correct
> policies, extracting it grants read access to every user's bills.

---

## Phase 11 — Cloud AI extraction

**Size:** M · **Depends on:** 3, 10 · **PRD:** AI Features

**Build**
* `extract-invoice` Edge Function: auth check, per-user rate limit, vision call, JSON schema
  validation.
* Provider API key as a function secret.
* `CloudExtractor` conforming to `ExpenseExtractor`.
* Settings toggle: On-device / Cloud AI, with a plain-language privacy note.
* 8s timeout with automatic on-device fallback.

**Exit criteria**
* Cloud extraction measurably beats on-device on the fixture set.
* Function rejects unauthenticated calls.
* Airplane mode falls back to on-device with a visible note, not an error.
* No API key appears anywhere in the app binary (verify with `strings`).

---

## Phase 12 — AI extras

**Size:** M · **Depends on:** 4, 5 · **PRD:** AI Features

**Build**
* Duplicate detection: exact (`contentHash`) + fuzzy (merchant, ±1% amount, ±1 day).
* Duplicate comparison sheet — Keep both / Replace / Discard.
* Merchant normalization and alias grouping.
* Recurring detection → suggest creating a subscription tracker.
* Surface categorization accuracy in Settings (debug or user-facing).

**Exit criteria**
* Re-scanning the same bill triggers the duplicate sheet.
* Two genuine same-day same-amount purchases can both be kept.
* Three monthly bills from one merchant produce a tracker suggestion.

---

## Phase 13 — Hardening & release prep

**Size:** M · **Depends on:** all · **PRD:** Success Criteria

**Build**
* Measure every PRD success criterion against the fixture set and real usage.
* Accessibility: Dynamic Type, VoiceOver labels, contrast in both themes.
* Dark mode audit across all screens.
* Error and empty states audited on every screen.
* Privacy policy; App Store privacy nutrition labels (declare the AI image upload).
* Crash reporting; performance profiling on an older device.
* App Store assets and submission.

**Exit criteria**
* All PRD success criteria met or consciously accepted with a documented reason.
* No crash in a full pass through every flow.
* Sign in with Apple present (required if any other third-party sign-in is offered).

---

## Milestones

| Milestone | Phases | What you have |
|---|---|---|
| **M0 — Foundation** | 0–1 | Clean project, full data model, existing features intact |
| **M1 — Scanning works** | 2–4 | Photograph a bill and save it. **The product exists** |
| **M2 — Smart & searchable** | 5–6 | Auto-categorization that learns; item-level search |
| **M3 — Insight** | 7–8 | Full reports and export |
| **M4 — Connected** | 9–11 | Sync, cloud AI, reminders |
| **M5 — Ship** | 12–13 | Dupes, recurring, hardening. Release candidate |

M1 is the meaningful checkpoint — it is a coherent, usable product on its own, and everything
after it is improvement rather than completion.

---

## Suggested parallelisation

If more than one person is building:

* **Track A (critical path):** 0 → 1 → 2 → 3 → 4 → 11
* **Track B (from Phase 1):** 6 → 7 → 8
* **Track C (from Phase 1):** 5 → 9 → 12
* **Track D:** Phase 10 can start as soon as credentials exist — the SQL and Edge Function
  are independent of client work.

Solo, follow the critical path to M1 first. A working scanner is worth more than polished
reports over data you cannot yet capture.

---

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| On-device accuracy misses PRD targets | **High** | Expected. Cloud path exists for this; make switching obvious. PRD already qualifies the 95% target to cloud |
| Line-item parsing unreliable across formats | **High** | Fixture set from Phase 3; treat heuristics as continuously tuned, not finished |
| RLS misconfigured | Medium | **Verify with a second account before shipping.** Highest-severity risk in the project |
| Cloud AI cost | Medium | Rate-limit per user in the Edge Function; on-device stays default |
| 5-second budget missed | Medium | Off-main-thread processing; 8s cloud timeout with fallback |
| Scope creep | Medium | Milestones are independently shippable; M1 alone is a product |
| App Store rejection (privacy) | Low | Declare the AI image upload in nutrition labels; make it opt-in |

---

## Definition of Done (every phase)

* Builds clean with no new warnings.
* Works offline where the feature allows.
* Empty, loading and error states handled.
* Light and dark mode verified.
* No regression in previously completed phases.
* Documentation updated if behaviour diverged from these docs.

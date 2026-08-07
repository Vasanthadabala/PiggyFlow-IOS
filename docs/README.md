# PiggyFlow v2 — Project Documentation

Reference documentation for PiggyFlow v2, which merges the existing personal-finance
tracker with the AI bill-scanning product described in the PRD.

**Status:** design phase. Nothing here is built yet. UI design comes next, then implementation.

---

## Read in this order

| # | Document | What it covers | Read it when |
|---|---|---|---|
| — | [**PRD (v2.0)**](PRD.md) | Product requirements for the merged app — features, flows, success criteria | **Start here.** Agreeing *what* gets built |
| 01 | [Architecture](01-ARCHITECTURE.md) | Layers, folder structure, protocol seams, tech stack | Understanding how pieces fit |
| 02 | [Data Model](02-DATA-MODEL.md) | Every entity, field, relationship and enum | Designing screens that show/edit data |
| 03 | [User Flows & Screens](03-USER-FLOWS.md) | Every screen, every state, navigation map | **Designing the UI** |
| 04 | [Extraction Pipeline](04-EXTRACTION-PIPELINE.md) | Capture → enhance → OCR → extract → categorize | Working on scanning |
| 05 | [Backend (Supabase)](05-BACKEND-SUPABASE.md) | SQL schema, RLS, storage buckets, Edge Function | Setting up the backend |
| 06 | [Build Plan](06-BUILD-PLAN.md) | 14 phases, exit criteria, milestones, risks | Planning and executing implementation |

If you are about to design screens, **03 is the one you want**, with 02 open alongside it
for the fields each screen has to accommodate.

---

## What PiggyFlow v2 is

A mobile-first expense app where the primary way to record spending is **photographing a
bill** and letting the app read it, with manual entry as a fast fallback. It keeps the
existing app's income tracking, subscription/EMI trackers and budget goals, so it covers
"where did my money go" as well as "what do I owe next".

### The two products being merged

**Existing PiggyFlow** — manual entry, income + expenses, subscription/EMI tracker with due
dates, per-category budget goals, net balance and savings rate, charts, cloud sync, Google/
Apple auth, and a recently redesigned UI.

**PRD product** — photograph a bill, AI extracts merchant/date/total/tax/line items,
auto-categorizes into Personal/Family/Business + expense category, stores the original
image, and reports across merchants, categories and payment methods.

### What the merge actually changes

- Expenses gain real invoice structure: merchant, invoice number, tax, currency, payment
  method, and **individual line items**.
- Every expense can carry its **original bill image** and the raw OCR text.
- A new **Personal / Family / Business** dimension runs through capture, filters and reports.
- Scanning becomes a **first-class entry path**, not a dead screen. (In the current codebase
  `ScanView.swift` is unreachable — nothing references it.)
- Income, trackers and budgets carry over unchanged in spirit.

---

## Key decisions already made

| Decision | Choice | Why |
|---|---|---|
| Client | Native SwiftUI (iOS) | The PRD lists Flutter/RN as *suggestions*; rewriting would discard a working, freshly redesigned app |
| Backend | **Supabase** (replaces Firebase) | Postgres + Storage + Auth + Edge Functions in one; Edge Functions are what let us call vision APIs without shipping a key |
| Local store | SwiftData | Already in use; offline-first |
| Extraction | **Both** on-device and cloud | On-device is free/offline/private; cloud is accurate. Chosen at runtime behind one protocol |
| Images | **Both** local and Supabase Storage | Local for instant access offline, remote for cross-device sync and reinstall survival |
| Data migration | **None — fresh start** | App is pre-release with no real users; the model is designed clean rather than bolted onto the old 7-field one |

---

## Success criteria (from the PRD)

| Target | Measured how |
|---|---|
| Bill processed in **under 5s** | Capture → review screen appears |
| OCR accuracy **>95%** on clear images | Field-level accuracy on a fixed test set of bills |
| Categorization accuracy **>90%** | % of saved expenses where the user did not change the suggested category |
| Expense searchable **immediately** after save | Local write is synchronous; sync is background |
| Reports generated **instantly** for any range | Local queries; no network in the read path |
| Record an expense in **under 30s** | Time from FAB tap to save, happy path |

The categorization metric is worth instrumenting from day one — it is the only one that
needs data collected over time, and it is also the signal that drives the learning loop
described in [04](04-EXTRACTION-PIPELINE.md).

---

## Glossary

| Term | Meaning |
|---|---|
| **Account type** | Personal / Family / Business — the PRD's "primary category" |
| **Category** | Spending category (Food & Dining, Fuel, …) — orthogonal to account type |
| **Line item** | A single product row on a bill (name, qty, unit price, total) |
| **Extraction** | Turning a bill image into structured data |
| **Provider** | An extraction implementation — on-device or cloud |
| **Tracker** | A recurring commitment: subscription, EMI, or budget goal |
| **Dirty queue** | Local changes awaiting upload, so edits survive being offline |

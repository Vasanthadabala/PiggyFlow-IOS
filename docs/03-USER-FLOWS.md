# 03 — User Flows & Screens

**This is the document to design against.** Keep [02 — Data Model](02-DATA-MODEL.md) open
alongside it for the fields each screen must accommodate.

Every screen below lists its **states**. Designing only the happy path is the most common
way this kind of app ships broken — empty, loading, error and partial-data states are
called out explicitly because in a bill-scanning app they are the *normal* case, not edge cases.

---

## Navigation map

```
Launch
 └─ not signed in ──► Onboarding ──► Login Options ──► (skip or auth) ─┐
 └─ signed in ────────────────────────────────────────────────────────┴──► Main Tabs

Main Tabs (floating capsule bar)
├── Home        list + search + filters        ──► Expense Detail ──► Edit
├── Tracker     subscriptions / EMI / budgets  ──► Add / Edit Tracker
├── Stats       charts + summaries             ──► Category Detail ──► Reports ──► Export
└── Settings    account, sync, AI, alerts      ──► Profile · About · Notifications

FAB (floating, above tab bar, on Home & Tracker)
└── ▲ Scan Bill    ──► Source Picker ──► Capture ──► Processing ──► Review ──► saved
    ▲ Add Manually ──► Manual Entry Sheet ──────────────────────────────────► saved
```

**Tab bar visibility:** shown on the four tabs only. Hidden on every pushed screen (Detail,
Profile, About, Notifications, Review). Already implemented via `TabBarVisibility`.

---

## Flow A — Capture a bill (the primary flow)

The PRD's headline journey. Target: **under 30 seconds**, **under 5 seconds** of processing.

```
FAB ─► [Scan Bill]
        │
        ▼
   Source Picker ──► Camera (VisionKit doc scanner)
        │        └─► Photo Library (multi-select)
        ▼
   Processing ──► enhance ──► OCR ──► extract ──► categorize
        │                                  │
        │                                  ├─ duplicate found? ──► Duplicate Warning
        │                                  └─ extraction failed? ──► Manual fallback
        ▼
   Review & Correct  ◄── the most important screen in the app
        │
        ▼
      Save ──► Home updates ──► optional toast "Added ₹499 · Netflix"
```

### A1 · Source Picker
Small sheet. Two large targets: **Take Photo** / **Choose from Library**. Include a
one-line hint that multiple pages are supported.

*States:* camera permission denied → explain and deep-link to Settings.

### A2 · Capture
Camera path uses **VisionKit's document scanner** — edge detection, perspective correction
and multi-page are free, and it's the interaction users already know from Notes/Files.
Library path allows multi-select.

*States:* nothing captured → return to Home silently, no error.

### A3 · Processing
Shown while enhance → OCR → extract runs. Must feel fast and honest.

- Thumbnail(s) of what's being read
- Staged progress: *Enhancing → Reading text → Understanding bill*
- Provider indicator when cloud is used (an AI call has different privacy implications and
  the user should be able to see it happened)
- **Cancel** always available

*States:* on-device fallback after cloud failure → a quiet inline note, not a blocking error.
Total failure → offer *Enter manually* with the image still attached, never a dead end.

### A4 · Review & Correct ★
Where accuracy is won or lost. The user confirms or fixes what the AI read.

**Layout, top to bottom**
1. **Bill image strip** — thumbnails, tap to view full screen, page count for multi-page
2. **Amount** — largest element on the screen, prominently editable
3. **Merchant** · **Date** · **Invoice #**
4. **Tax** / **Subtotal** (collapsed when absent)
5. **Payment method** — chips
6. **Account type** — Personal / Family / Business segmented control
7. **Category** — AI suggestion pre-selected, one tap to change
8. **Line items** — editable rows (name, qty, unit price, total); add/remove
9. **Tags** · **Note**
10. **Save** (primary) · **Discard**

**Design requirements**
- Every field is **editable in place**. Do not make the user navigate away to fix a date.
- **Low-confidence fields are visually flagged** (subtle amber accent + "check this"), so
  attention goes where it's needed rather than to every field equally.
- Fields that weren't detected show an explicit **"Not detected"** affordance, not a blank.
- **Line-item mismatch:** when items don't sum to `amount`, show a non-blocking note —
  *"Items total ₹480, bill total ₹499"*. Never auto-correct; discounts and rounding are real.
- Editing an AI-suggested value sets `wasCorrectedByUser` — this is the accuracy metric and
  the learning signal.

*States:* every field empty (unreadable bill) → screen still works as a manual entry form
with the image attached.

### A5 · Duplicate Warning
When `contentHash` or merchant+date+amount proximity matches an existing expense.

Sheet showing **both** bills side by side with the differences highlighted, and three
choices: *Keep both* · *Replace existing* · *Discard new*. Never silently drop a bill —
genuine same-day repeat purchases at the same merchant do happen.

---

## Flow B — Manual entry

The existing fast path, kept. FAB → **Add Manually** → the current bottom sheet
(Expense/Income toggle, category grid, amount, date, note). Gains an **Account type**
control to match scanned expenses.

Deliberately unchanged otherwise: it's already fast, and speed is the point.

---

## Flow C — Browse, search, filter

### C1 · Home
The default screen.

- **Header** — avatar (→ Profile), greeting, notification bell (→ Notifications)
- **Balance hero** — the one `gradientHero` on the screen: net balance, income, spent, health pill
- **Quick stats** — Savings Rate · Due Soon (two `groupedCard`s)
- **Search + filter row** — `liftedControl` styling
- **Account type selector** — All / Personal / Family / Business
- **Recent Activity** — one grouped card, flat rows + dividers

*States:*
- **Empty (new user)** — tinted icon, "No transactions yet", clear pointer to the FAB
- **Empty (filtered)** — different copy: "No expenses match", offer *Clear filters*. Do not
  reuse the new-user empty state here; it reads as data loss
- **Loading** — skeleton rows

> Distinguishing those two empty states is a small thing that makes an app feel considered.

### C2 · Search & Filters
Searches **merchant, item name, category, tags, note, amount**. Item-name search means
querying `LineItem`, so "paracetamol" finds the pharmacy bill it was on — a genuinely
useful capability the flat model couldn't offer.

**Date presets:** Today · Yesterday · This Week · Last Week · This Month · Last Month ·
Custom Range
**Account type:** All · Personal · Family · Business
Plus category, amount range, payment method, has-receipt.

Active filters shown as removable chips.

---

## Flow D — Expense detail

Tap any row.

- **Bill image** — full-width, tap to zoom, swipe for multi-page
- **Amount** — hero treatment, colour by expense/income
- **Merchant · Date · Invoice # · Payment method**
- **Tax / Subtotal breakdown**
- **Line items** — itemized table
- **Category · Account type · Tags**
- **Note**
- **OCR text** — collapsed accordion, "Show extracted text"
- **Extraction badge** — "Scanned with AI" / "Scanned on device" / "Manual entry"
- **Edit** (primary green) · **Delete** (red, confirms)

*States:* manual entry → image and OCR sections **collapse entirely** rather than showing
empty frames. No line items → hide the section.

---

## Flow E — Reports & dashboard

### E1 · Stats
- **Range selector** — Day · Week · Month · Year · Custom
- **Summary cards** — Total · Personal · Family · Business
- **Charts** — spending trend · by category · **by merchant** · **by payment method**
- **Top categories** — ranked rows with progress bars → Category Detail

The merchant and payment-method charts are new capability unlocked by the model in doc 02.

*States:* no data for range → empty state offering to jump to a range that has data.

### E2 · Category Detail
Existing screen: category total, transaction list, PDF export. Gains line-item visibility.

### E3 · Reports
Date-wise · Week-wise · Month-wise · Year-wise · Custom range. Each shows summary,
category totals, merchant totals, and an itemized list.

---

## Flow F — Export

Reports → **Export** → choose **format** (PDF / CSV / Excel) and **contents** (summary,
itemized expenses, category totals, merchant totals) → generate → iOS share sheet.

*States:* generating → progress with cancel. Large ranges must not block the UI.

---

## Flow G — Trackers

Existing screen, unchanged in shape: Subscriptions / EMI / Budget Goals segmented control,
monthly estimate hero, list of trackers with due-soon badges, FAB to add.

Budget Goals read `Category.budgetLimit` and compare against actual spend for the month.

---

## Flow H — Settings

- **Profile hero** — avatar, name (inline edit), connection status
- **Account** — email, connected provider, **Auto Sync** toggle (12-hourly), Delete Account
- **Scanning** *(new)* — extraction provider: *On-device (private, free)* / *AI (more
  accurate)*; toggle for storing bill images in the cloud
- **Notifications** *(new)* — per-reminder toggles (see below)
- **Data & Privacy** — Clear Local Data
- **App & Support** — Privacy & Security, About
- **Session** — Logout

The Scanning section matters: cloud extraction sends bill images off-device, and that should
be a visible, user-controlled choice rather than a silent default.

---

## Flow I — Notifications

In-app **Notifications** screen lists upcoming tracker due dates with a *Clear All* action.

Scheduled local notifications (all opt-in, off by default):
| Reminder | When |
|---|---|
| Upload today's bills | Daily, user-set time |
| Monthly summary | 1st of month |
| High spending alert | When a category exceeds its budget |
| Missing bills reminder | Weekly, if no expense logged in N days |
| Tracker due | 3 days before a subscription/EMI due date |

Permission is requested **contextually** — when the user first enables a reminder, not at
launch. Launch-time permission prompts get denied far more often.

---

## Flow J — Onboarding & auth

Onboarding carousel (3 slides) → Login Options: **Continue with Google** · **Sign in with
Apple** · **Skip Setup**.

Skip is important: the app is fully functional offline with local-only storage. Sign-in
unlocks sync and cloud extraction, and can happen later from Settings.

---

## Screen inventory

| # | Screen | Type | Priority |
|---|---|---|---|
| 1 | Onboarding carousel | Full | Exists |
| 2 | Login options | Full | Exists |
| 3 | Home | Tab | Exists — needs account-type filter |
| 4 | Search & filters | Sheet | **New** |
| 5 | Source picker | Sheet | **New** |
| 6 | Capture (VisionKit) | System | **New** |
| 7 | Processing | Full | **New** |
| 8 | **Review & correct** | Full | **New — highest value** |
| 9 | Duplicate warning | Sheet | **New** |
| 10 | Manual entry | Sheet | Exists — add account type |
| 11 | Expense detail | Push | Exists — needs image, line items, OCR |
| 12 | Image viewer | Full | **New** |
| 13 | Stats | Tab | Exists — needs merchant/payment charts |
| 14 | Category detail | Full | Exists |
| 15 | Reports | Push | **New** |
| 16 | Export options | Sheet | **New** |
| 17 | Tracker | Tab | Exists |
| 18 | Add/edit tracker | Sheet | Exists |
| 19 | Settings | Tab | Exists — add Scanning + Notifications |
| 20 | Profile | Push | Exists |
| 21 | Notifications | Push | Exists |
| 22 | About | Push | Exists |

**Design these first:** #8 Review, #7 Processing, #11 Expense Detail. They carry the new
product and everything else is comparatively conventional.

---

## Cross-cutting design rules

- **One `gradientHero` per screen.** Two competing saturated surfaces was a real problem in
  an earlier iteration.
- **Semantic colour only** — green brand/positive, red expense/destructive, indigo budget,
  amber due-soon/low-confidence. Never decorative.
- **Every list needs four states:** loading, empty-new, empty-filtered, populated.
- **Never block on network.** Save writes locally and returns immediately; sync is invisible.
- **AI output is a suggestion, never a fact.** Always visibly editable, always attributed.
- **Tap targets span the full row**, not just the text.

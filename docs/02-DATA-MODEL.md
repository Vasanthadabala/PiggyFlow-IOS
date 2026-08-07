# 02 — Data Model

Clean-slate design. The app is pre-release with no real users, so there is **no migration
burden** — entities are shaped for the merged product rather than bolted onto the old
7-field `Expense`.

---

## Entity map

```
                    ┌───────────┐
                    │ Category  │
                    └─────▲─────┘
                          │ categoryID (soft ref)
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────┴─────┐     ┌─────┴─────┐    ┌──────┴───────┐
   │ Expense  │     │  Income   │    │TrackerRecord │
   └────┬─────┘     └───────────┘    └──────────────┘
        │ 1─many (cascade)
   ┌────▼─────┐
   │ LineItem │
   └──────────┘

   ┌──────────────┐   ┌──────────────────┐
   │ BillImageRef │   │ CategorizationRule│
   └──────────────┘   └──────────────────┘
```

`Expense` is the centre of gravity. Everything else either describes it, classifies it, or
exists to serve PiggyFlow's non-bill features (income, trackers).

---

## Expense

The core entity. One expense = one bill (or one manually entered spend).

### Identity & money
| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID. Stable across devices — also the Supabase PK |
| `amount` | `Double` | **Total** paid. The number shown in lists and summed in reports |
| `subtotal` | `Double?` | Pre-tax, when the bill states it |
| `taxAmount` | `Double?` | Tax/GST when present |
| `currencyCode` | `String` | ISO 4217, default `"INR"` |

> `amount` is authoritative for all reporting. Line items may not sum to it (discounts,
> rounding, unreadable rows) and **must never be silently reconciled** — surface the
> mismatch in review instead. See [04](04-EXTRACTION-PIPELINE.md).

### Merchant & invoice
| Field | Type | Notes |
|---|---|---|
| `merchantName` | `String` | As printed on the bill |
| `merchantNormalized` | `String` | Lowercased, punctuation/suffix-stripped. **Group merchant reports by this** |
| `invoiceNumber` | `String` | Empty when absent |
| `paymentMethod` | `String` | `PaymentMethod` raw value |

### Dates
| Field | Type | Notes |
|---|---|---|
| `date` | `Date` | **Invoice date** — the date the money was spent. Drives all reporting |
| `createdAt` | `Date` | When the record was made |
| `updatedAt` | `Date` | Last edit. Drives last-write-wins sync |

> Keep `date` and `createdAt` distinct. Photographing last week's receipt today must report
> under last week. (The old scan code stamped everything with "today" — a real bug.)

### Classification
| Field | Type | Notes |
|---|---|---|
| `accountType` | `String` | `AccountType` raw value. Default `personal` |
| `categoryID` | `String` | Soft reference to `Category.id` |
| `categoryName` | `String` | Denormalised for display + offline resilience if a category is deleted |
| `emoji` | `String` | Denormalised from category |
| `tags` | `[String]` | Free-form user tags |
| `note` | `String` | User note |

### Capture provenance
| Field | Type | Notes |
|---|---|---|
| `imageRefs` | `[BillImageRef]` | Bill photos. Empty for manual entries |
| `ocrText` | `String` | Raw recognised text. Kept for search + re-parsing later |
| `extractionSource` | `String` | `ExtractionSource` raw value |
| `extractionConfidence` | `Double?` | 0–1 overall. Drives "please check this" hints |
| `wasCorrectedByUser` | `Bool` | Set when the user edits an AI-suggested field. **This is the categorization-accuracy metric** |

### Location (optional)
| Field | Type | Notes |
|---|---|---|
| `latitude` / `longitude` | `Double?` | Only if the user grants permission |
| `locationName` | `String?` | Reverse-geocoded label |

### Duplicate detection
| Field | Type | Notes |
|---|---|---|
| `contentHash` | `String` | Fingerprint of merchant + date + amount + invoice no. First-pass dupe check |

### Relationship
| Field | Type | Notes |
|---|---|---|
| `lineItems` | `[LineItem]` | Cascade delete — line items have no meaning without their bill |

---

## LineItem

One product row on a bill.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `name` | `String` | Product name as printed |
| `quantity` | `Double` | Default `1`. `Double` because bills carry `1.5 kg` |
| `unitPrice` | `Double` | Per-unit |
| `totalPrice` | `Double` | Row total. Stored, not computed — bills round oddly and the printed value wins |
| `sortOrder` | `Int` | Preserves printed order |
| `expense` | `Expense?` | Inverse |

---

## Category

User-visible spending/earning categories. Seeded with the PRD set plus the user's own.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `name` | `String` | Display name |
| `emoji` | `String` | Shown in the icon tile |
| `kind` | `String` | `expense` \| `income` |
| `isSystem` | `Bool` | Seeded categories can't be deleted, only hidden |
| `isHidden` | `Bool` | Lets a user suppress a system category without deleting it |
| `budgetLimit` | `Double` | `0` = no budget. Powers the Budget Goals tracker |
| `sortOrder` | `Int` | Manual ordering |

### Seeded expense categories (PRD)
Food & Dining · Grocery · Fuel · Travel · Medical · Shopping · Utilities · Entertainment ·
Education · Office Supplies · Client Meeting · Software & Subscriptions · Miscellaneous

### Seeded income categories
Salary · Freelance · Investments · Rental · Interest · Bonus · Gifts · Refund · Other

> The PRD lists *Salary* among expense categories; that reads like an oversight — it is
> modelled as income here. Flagging in case it was meant as business payroll expense, which
> would be a genuinely different thing.

---

## Income

Carried over from existing PiggyFlow. The PRD is expense-only; income is what makes net
balance and savings rate meaningful, so it stays.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `amount` | `Double` | |
| `date` | `Date` | |
| `source` | `String` | Employer / client / payer |
| `categoryID` / `categoryName` / `emoji` | `String` | Income-kind category |
| `accountType` | `String` | Personal/Family/Business — mirrors Expense |
| `note` | `String` | |
| `createdAt` / `updatedAt` | `Date` | |

---

## TrackerRecord

Subscriptions, EMIs and budget goals. Carried over.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `kind` | `String` | `subscription` \| `emi` \| `budget` |
| `name` | `String` | |
| `amount` | `Double` | |
| `cadence` | `String` | `monthly` \| `yearly` |
| `dueDate` | `Date` | |
| `isPaid` | `Bool` | |
| `logoURL` | `String` | Brand logo lookup |
| `linkedCategoryID` | `String?` | For budget-goal trackers |
| `accountType` | `String` | |
| `createdAt` / `updatedAt` | `Date` | |

---

## BillImageRef

Where a bill photo lives. Local path is the display source of truth; remote is for sync.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `localPath` | `String?` | **Relative** to Documents. Never absolute — the container path changes between launches |
| `remoteURL` | `String?` | Supabase Storage object path |
| `uploadState` | `String` | `pending` \| `uploaded` \| `failed` |
| `width` / `height` | `Int` | For layout before decode |
| `byteSize` | `Int` | |
| `sortOrder` | `Int` | Page order for multi-page bills |

> Storing an **absolute** path is a classic iOS bug: the app container UUID changes across
> reinstalls and OS updates, so saved paths silently break. Always resolve
> `Documents + localPath` at read time.

---

## CategorizationRule

Powers auto-categorization and the learning loop.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID |
| `pattern` | `String` | Merchant fragment or keyword, lowercased |
| `matchField` | `String` | `merchant` \| `lineItem` \| `ocrText` |
| `categoryID` | `String` | What to assign |
| `accountTypeHint` | `String?` | e.g. "Client Meeting" ⇒ business |
| `origin` | `String` | `seed` \| `learned` |
| `weight` | `Double` | Learned rules gain weight on repeat corrections |
| `hitCount` | `Int` | |
| `updatedAt` | `Date` | |

---

## Enums

Stored as raw `String` on models, not as enum types. Reason: the sync layer maps fields by
hand, and a plain string tolerates an unknown value arriving from a newer client instead of
failing to decode the whole row. Each enum gets a `from(_:)` that falls back to a safe default.

```swift
enum AccountType: String  { case personal, family, business }        // default .personal

enum PaymentMethod: String {
    case cash, card, upi, netBanking, wallet, other, unknown         // default .unknown
}

enum ExtractionSource: String { case manual, onDevice, cloud }       // default .manual

enum TrackerKind: String { case subscription, emi, budget }
enum CategoryKind: String { case expense, income }
enum UploadState: String { case pending, uploaded, failed }
```

---

## Indexing

Queried constantly — index these:

| Entity | Index | Serves |
|---|---|---|
| Expense | `date` | Every range filter and report |
| Expense | `accountType` | Personal/Family/Business filter |
| Expense | `categoryID` | Category reports |
| Expense | `merchantNormalized` | Merchant reports |
| Expense | `contentHash` | Duplicate detection |
| LineItem | `expense` | Detail view |

---

## Notes for UI design

Things worth knowing before drawing screens:

- **Every field can be empty.** A crumpled receipt may yield only a total. Screens need a
  graceful "not detected" state per field, not just a populated happy path.
- **`amount` vs summed line items can disagree.** The review screen needs somewhere to show
  that honestly.
- **`accountType` and `categoryID` are independent.** A "Food & Dining" expense can be
  Personal *or* Business. They are two separate controls, not a hierarchy.
- **Manual expenses have no image and no OCR text.** Detail view must collapse those
  sections rather than showing empty frames.
- **`extractionConfidence` should drive emphasis** — low-confidence fields want visual
  attention in review, not silent acceptance.

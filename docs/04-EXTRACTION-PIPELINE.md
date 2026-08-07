# 04 — Extraction Pipeline

How a photograph becomes a structured expense. This is the heart of the PRD.

---

## Pipeline

```
[UIImage…]
    │
    ▼
1. ImageEnhancer          grayscale · contrast · deskew · denoise
    │
    ▼
2. Extractor              ┌─ OnDeviceExtractor  (Vision OCR + heuristics)
    │  (one of)           └─ CloudExtractor     (vision LLM via Edge Function)
    ▼
3. ExtractedInvoice       structured + per-field confidence
    │
    ▼
4. CategorySuggester      rules + learned corrections
    │
    ▼
5. DuplicateDetector      contentHash + fuzzy match
    │
    ▼
6. Review screen          user confirms/corrects  ──► learning signal
    │
    ▼
7. Expense + LineItems    saved locally, queued for sync
```

Budget: **under 5 seconds** end to end. On-device typically ~1–2s; cloud is network-bound,
usually 2–4s.

---

## 1 · Image enhancement

`Core/Capture/ImageEnhancer.swift`, Core Image.

| Step | Filter | Why |
|---|---|---|
| Grayscale | `CIPhotoEffectMono` | Colour adds nothing for OCR |
| Contrast | `CIColorControls` | Faded thermal receipts |
| Denoise | `CINoiseReduction` | Low-light phone shots |
| Deskew | Vision rectangle detection + perspective correct | Photos taken at an angle |
| Downscale | Max ~2000px long edge | Above this, accuracy is flat but time and upload size aren't |

Skipped when the image came from **VisionKit's document scanner** — it already applies edge
detection and perspective correction, and re-processing degrades the result.

---

## 2a · On-device extractor

Apple Vision OCR plus heuristics. Free, offline, private, no key. The default.

```swift
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["en-IN", "en-US"]
```

Critically, it uses **`observation.boundingBox`** — layout is signal. The old implementation
threw geometry away and regex'd a flat string, which is why it could only ever find
`text + number` pairs.

### Field heuristics

| Field | Approach |
|---|---|
| **Merchant** | Largest text in the top ~20% of the bill; strip GSTIN/phone/address lines |
| **Date** | Multi-format scan (`dd/MM/yyyy`, `MM-dd-yy`, `12 Jan 2026`, …). Prefer one near a "date"/"invoice" keyword. **Reject future dates** |
| **Invoice #** | Regex near keywords: `invoice`, `bill no`, `receipt` |
| **Total** | Rightmost numeric on a line containing `total`/`amount due`/`grand total`; **prefer the last such line** — subtotal appears above total |
| **Tax** | Line containing `tax`, `gst`, `cgst`, `sgst`, `vat` |
| **Currency** | Symbol (₹/$/€/£) or code in text; default to locale |
| **Payment** | Keywords: `cash`, `upi`, `card`, `visa`, `mastercard`, `paytm`, `gpay` |
| **Line items** | Rows between the header block and the totals block, matching `name … qty? … price`, aligned by x-position of the price column |

Line items are the hardest part — the price column is identified by **x-coordinate
clustering** across rows rather than by regex per line. That's what makes columnar bills
parse correctly.

**Confidence** per field: Vision's own confidence, keyword proximity, and format validity
(e.g. does the date parse and fall in a sane range).

### Honest limitations
Handwritten bills, heavy skew, non-Latin scripts and multi-column layouts will underperform.
On-device will **not** hit the PRD's 95%/90% targets on messy real-world bills — that is what
the cloud path is for. Users should be able to reach for it when a scan comes out poorly.

---

## 2b · Cloud extractor

Vision LLM (OpenAI or Anthropic) called through a **Supabase Edge Function**, never directly.

```
App ──(JWT + image)──► Edge Function ──(server-held API key)──► Vision LLM
                              │
App ◄──── ExtractedInvoice ◄──┘
```

**The API key never ships in the client.** Anything embedded in an app binary is extractable
in minutes, and a leaked key is billed to you. The function also enforces auth, rate limits
per user, and can swap providers without an app release.

The prompt asks for **strict JSON** matching `ExtractedInvoice`, with explicit instructions
to return `null` for anything not visible — a fabricated invoice number is worse than a
missing one. Response is validated against the schema before use; a malformed reply falls
back on-device rather than surfacing an error.

Details, including the function source, in [05 — Backend](05-BACKEND-SUPABASE.md).

---

## 3 · Provider selection

```swift
protocol ExpenseExtractor {
    var kind: ExtractionSource { get }
    var isAvailable: Bool { get }
    func extract(from images: [UIImage]) async throws -> ExtractedInvoice
}
```

`ExtractionCoordinator` decides:

| User setting | Online + signed in | Result |
|---|---|---|
| On-device | — | On-device |
| AI (accurate) | yes | Cloud, **fall back on-device** on error/timeout |
| AI (accurate) | no | On-device, with a quiet note |

Timeout on cloud is ~8s, after which it falls back — waiting longer breaks the 5s target
worse than a slightly weaker result does.

The UI only ever talks to the coordinator and never knows which provider ran, except to
display it.

### ExtractedInvoice

```swift
struct ExtractedInvoice {
    var merchantName:   Field<String>?
    var date:           Field<Date>?
    var invoiceNumber:  Field<String>?
    var totalAmount:    Field<Double>?
    var subtotal:       Field<Double>?
    var taxAmount:      Field<Double>?
    var currencyCode:   Field<String>?
    var paymentMethod:  Field<PaymentMethod>?
    var lineItems:      [ExtractedLineItem]
    var rawText:        String
    var source:         ExtractionSource
    var overallConfidence: Double
}

struct Field<T> {         // value + how sure we are
    let value: T
    let confidence: Double   // 0…1
}
```

Wrapping each field in `Field<T>` is what lets the review screen flag *specific* uncertain
values instead of treating the whole extraction as equally trustworthy.

---

## 4 · Category suggestion

`Core/Categorization/`, three passes, first match wins:

1. **Learned rules** — corrections this user has made before, highest weight
2. **Merchant rules** — seeded mappings (`starbucks → Food & Dining`, `indian oil → Fuel`)
3. **Keyword rules** — line items and OCR text (`paracetamol → Medical`)

Falls back to `Miscellaneous` with low confidence.

**Account type** is inferred separately and weakly: `Client Meeting`/`Office Supplies` hint
business; otherwise the user's default (Personal). It is always shown for confirmation —
guessing wrong here is more annoying than not guessing.

### Learning loop
When the review screen is saved with a changed category, record a `CategorizationRule`
(`origin: .learned`) keyed on `merchantNormalized`. Repeat corrections raise `weight`. This
is the PRD's "learn from user corrections" and it needs no server.

`wasCorrectedByUser` on `Expense` is the accuracy metric: **1 − (corrected / total)** is
categorization accuracy, trackable against the PRD's 90% target from day one.

---

## 5 · Duplicate detection

Two passes:

1. **Exact** — `contentHash` of `merchantNormalized + date + amount + invoiceNumber`
2. **Fuzzy** — same merchant, amount within ±1%, date within ±1 day

A hit opens the duplicate sheet (Flow A5). **Never auto-discard**: buying coffee twice at
the same shop on the same day for the same price is ordinary, and silently swallowing the
second one is a data-loss bug the user can't see.

---

## 6 · Recurring detection

Background pass over saved expenses: ≥3 from the same merchant at a consistent interval
(monthly ±3 days) with similar amounts (±5%) ⇒ suggest creating a **subscription tracker**.

This is where the two products genuinely fuse — bill scanning feeding PiggyFlow's existing
subscription tracker, rather than the two features sitting side by side.

---

## Performance

| Stage | Budget |
|---|---|
| Enhancement | ~200ms |
| On-device OCR | ~800ms |
| On-device heuristics | ~100ms |
| Cloud round trip | 2–4s |
| Categorization | <50ms |
| Duplicate check | <50ms |

Rules: enhancement and OCR run **off the main thread**; the UI shows staged progress rather
than a spinner; **cancellation is honoured at every stage**; multi-page bills process
concurrently and merge.

---

## Privacy

- **On-device is fully private** — nothing leaves the phone. It is the default for that reason.
- **Cloud sends the bill image to a third-party LLM.** This must be an explicit, visible user
  choice in Settings, disclosed in the privacy policy, and never silently on.
- Images are stored locally by default; cloud image sync is separately opt-in.
- OCR text is retained locally to enable search and re-parsing without re-uploading.

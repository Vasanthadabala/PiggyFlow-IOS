# 05 — Backend (Supabase)

Supabase replaces Firebase entirely: Postgres for records, Storage for bill images, Auth for
identity, Edge Functions for the vision-LLM proxy.

**Why Supabase over staying on Firebase:** the PRD's data is relational (expenses → line
items, merchant/category aggregation), which Postgres serves far better than Firestore's
document model. Merchant- and category-wise reports are one `GROUP BY` instead of a
client-side fold over every document. Edge Functions also give a first-party place to hold
the AI key.

---

## Schema

Local SwiftData remains the source of truth for reads; this is the sync target.

```sql
-- ─── Categories ────────────────────────────────────────────────
create table categories (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  emoji         text default '',
  kind          text not null default 'expense',   -- expense | income
  is_system     boolean default false,
  is_hidden     boolean default false,
  budget_limit  numeric(12,2) default 0,
  sort_order    int default 0,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- ─── Expenses ──────────────────────────────────────────────────
create table expenses (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users(id) on delete cascade,

  amount                numeric(12,2) not null,
  subtotal              numeric(12,2),
  tax_amount            numeric(12,2),
  currency_code         text not null default 'INR',

  merchant_name         text default '',
  merchant_normalized   text default '',
  invoice_number        text default '',
  payment_method        text default 'unknown',

  date                  date not null,             -- invoice date
  created_at            timestamptz default now(),
  updated_at            timestamptz default now(),

  account_type          text not null default 'personal',
  category_id           uuid references categories(id) on delete set null,
  category_name         text default '',
  emoji                 text default '',
  tags                  text[] default '{}',
  note                  text default '',

  ocr_text              text default '',
  extraction_source     text default 'manual',
  extraction_confidence numeric(4,3),
  was_corrected_by_user boolean default false,

  latitude              double precision,
  longitude             double precision,
  location_name         text,

  content_hash          text default '',
  deleted_at            timestamptz                -- soft delete, see below
);

-- ─── Line items ────────────────────────────────────────────────
create table line_items (
  id           uuid primary key default gen_random_uuid(),
  expense_id   uuid not null references expenses(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  name         text not null,
  quantity     numeric(10,3) default 1,
  unit_price   numeric(12,2) default 0,
  total_price  numeric(12,2) default 0,
  sort_order   int default 0
);

-- ─── Bill images ───────────────────────────────────────────────
create table bill_images (
  id          uuid primary key default gen_random_uuid(),
  expense_id  uuid not null references expenses(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,                      -- object path in the bucket
  width       int, height int, byte_size int,
  sort_order  int default 0,
  created_at  timestamptz default now()
);

-- ─── Income ────────────────────────────────────────────────────
create table incomes (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  amount        numeric(12,2) not null,
  date          date not null,
  source        text default '',
  category_id   uuid references categories(id) on delete set null,
  category_name text default '',
  emoji         text default '',
  account_type  text not null default 'personal',
  note          text default '',
  created_at    timestamptz default now(),
  updated_at    timestamptz default now(),
  deleted_at    timestamptz
);

-- ─── Trackers ──────────────────────────────────────────────────
create table trackers (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  kind               text not null default 'subscription',  -- subscription | emi | budget
  name               text not null,
  amount             numeric(12,2) default 0,
  cadence            text default 'monthly',
  due_date           date,
  is_paid            boolean default false,
  logo_url           text default '',
  linked_category_id uuid references categories(id) on delete set null,
  account_type       text not null default 'personal',
  created_at         timestamptz default now(),
  updated_at         timestamptz default now(),
  deleted_at         timestamptz
);

-- ─── Categorization rules (learning) ───────────────────────────
create table categorization_rules (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users(id) on delete cascade,
  pattern           text not null,
  match_field       text not null default 'merchant',
  category_id       uuid references categories(id) on delete cascade,
  account_type_hint text,
  origin            text default 'learned',
  weight            numeric(6,3) default 1,
  hit_count         int default 0,
  updated_at        timestamptz default now()
);
```

### Indexes

```sql
create index on expenses (user_id, date desc);
create index on expenses (user_id, account_type);
create index on expenses (user_id, category_id);
create index on expenses (user_id, merchant_normalized);
create index on expenses (user_id, content_hash);
create index on expenses (user_id, updated_at);          -- incremental pull
create index on line_items (expense_id);
create index on line_items using gin (to_tsvector('simple', name));  -- item-name search
```

The GIN index is what makes "find the bill that had paracetamol on it" fast.

### Soft deletes
`deleted_at` rather than hard `DELETE`. A hard delete on one device is invisible to another
that's been offline — it would simply re-upload the row it still has. Tombstones make
deletion sync correctly. A scheduled job can purge rows older than ~90 days.

### Auto-update `updated_at`

```sql
create or replace function touch_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger t_expenses_touch before update on expenses
  for each row execute function touch_updated_at();
-- repeat for incomes, trackers, categories
```

---

## Row Level Security

**Enable on every table.** Without RLS, the anon key — which *does* ship in the client —
grants access to all users' rows. This is the single most important part of this document.

```sql
alter table expenses             enable row level security;
alter table line_items           enable row level security;
alter table bill_images          enable row level security;
alter table incomes              enable row level security;
alter table trackers             enable row level security;
alter table categories           enable row level security;
alter table categorization_rules enable row level security;

-- Same shape for every table:
create policy "own rows" on expenses
  for all
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

`using` governs read/update/delete visibility; `with check` prevents inserting rows owned by
someone else. Both are required — `using` alone still allows writing a row with a forged
`user_id`.

---

## Storage

Bucket `bill-images`, **private**.

Path convention — user id first so policies can match on it:
```
bill-images/{user_id}/{expense_id}/{image_id}.jpg
```

```sql
create policy "own images" on storage.objects
  for all
  using      (bucket_id = 'bill-images'
              and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'bill-images'
              and (storage.foldername(name))[1] = auth.uid()::text);
```

Access via **signed URLs** (~1h). Never make the bucket public — bills contain names,
addresses, card fragments and purchase history.

**Upload policy:** JPEG ~0.7 quality, long edge ≤2000px. Typically 200–500KB per bill.
Upload happens in the background after the expense is saved locally; capture never waits on it.

---

## Auth

Supabase Auth with Google and Apple providers, matching current functionality.

- **Sign in with Apple is mandatory** for App Store approval if you offer any other
  third-party sign-in.
- Enable both providers in the Supabase dashboard; add the iOS bundle ID and redirect URL.
- Sessions persist in Keychain via the Supabase Swift SDK.
- **Skip Setup stays supported** — the app works fully offline with local-only data, and a
  later sign-in should adopt existing local rows by stamping them with the new `user_id`.

---

## Edge Function — `extract-invoice`

The vision-LLM proxy. Holds the API key server-side.

```ts
// supabase/functions/extract-invoice/index.ts
import { createClient } from 'jsr:@supabase/supabase-js@2'

const SYSTEM_PROMPT = `
You extract structured data from receipts and invoices.
Return ONLY valid JSON matching the schema. Use null for anything not clearly
visible — never guess or invent a value. Amounts are numbers, not strings.
Dates are ISO-8601 (YYYY-MM-DD).
`

Deno.serve(async (req) => {
  // 1 ─ authenticate the caller
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })

  // 2 ─ rate limit per user (protects your spend)
  // 3 ─ call the vision model
  const { imageBase64 } = await req.json()

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY')!,   // server-only
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-5',
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      messages: [{
        role: 'user',
        content: [
          { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: imageBase64 } },
          { type: 'text',  text: 'Extract this receipt as JSON.' },
        ],
      }],
    }),
  })

  // 4 ─ validate against the schema before returning; malformed ⇒ 422 so the
  //     client falls back to on-device rather than showing an error
  return new Response(await res.text(), {
    headers: { 'content-type': 'application/json' },
  })
})
```

Expected response shape:

```json
{
  "merchantName": "Reliance Fresh",
  "date": "2026-07-24",
  "invoiceNumber": "INV-2291",
  "totalAmount": 1250.50,
  "subtotal": 1190.00,
  "taxAmount": 60.50,
  "currencyCode": "INR",
  "paymentMethod": "card",
  "lineItems": [
    { "name": "Milk 1L", "quantity": 2, "unitPrice": 60.00, "totalPrice": 120.00 }
  ],
  "confidence": 0.94
}
```

Deploy:
```bash
supabase functions deploy extract-invoice
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

---

## Sync protocol

Mirrors the existing dirty-queue design, which already works well.

**Push** — local write → mark dirty → enqueue → debounce → flush when online.
**Pull** — on launch/foreground, `select * where updated_at > last_sync_at`.
**Realtime** — subscribe to changes on the user's rows and reconcile into SwiftData.
**Conflict** — last-write-wins on `updated_at`.

Images sync separately and lazily: rows first (small, fast), images after (large). An
expense is fully usable with its image still uploading.

> Last-write-wins is right for one user on several devices. It is **not** sufficient for the
> PRD's future shared family/business accounts — two people editing the same expense needs
> per-field merge or explicit conflict surfacing. Worth revisiting before that ships.

---

## Environment

| Key | Where | Notes |
|---|---|---|
| `SUPABASE_URL` | Client + functions | Safe to ship |
| `SUPABASE_ANON_KEY` | Client | Safe to ship **only because RLS is enabled** |
| `SUPABASE_SERVICE_ROLE_KEY` | Server only | **Never** in the client — bypasses RLS |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | Function secrets | Never in the client |

Client config goes in an xcconfig kept out of git, not hardcoded in Swift.

---

## Migration from Firebase

No data migration needed (pre-release, fresh start). The code changes:

| Firebase | Supabase |
|---|---|
| `FirebaseAuth` + `GoogleSignIn` | `supabase-swift` auth |
| `Firestore` collections | Postgres tables via `SyncBackend` |
| — | Supabase Storage for images |
| — | Edge Function for AI |

Because sync sits behind the `SyncBackend` protocol ([01](01-ARCHITECTURE.md)), this
replaces implementations without touching any screen. Remove the Firebase SPM packages and
`GoogleService-Info.plist` once the swap is verified.

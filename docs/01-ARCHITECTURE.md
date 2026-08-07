# 01 — Architecture

## Stack

| Layer | Technology | Notes |
|---|---|---|
| UI | SwiftUI (iOS 17+) | SwiftData `@Query` needs 17; `@Observable` and `onChange(of:_:)` two-param form assume 17 |
| Local store | SwiftData | Offline-first. Every read in the app hits local, never the network |
| Charts | Swift Charts | Already used on Stats |
| OCR (on-device) | Vision (`VNRecognizeTextRequest`) | Free, offline, private |
| Doc scanning | VisionKit (`VNDocumentCameraViewController`) | Gives edge detection + perspective correction for free |
| Image processing | Core Image | Pre-OCR enhancement |
| Backend | Supabase | Postgres, Storage, Auth, Edge Functions |
| Cloud AI | OpenAI / Anthropic vision **via Supabase Edge Function** | Key never ships in the client |

---

## Layering

Three layers, enforced by folder. **Dependencies only ever point downward.**

```
┌─────────────────────────────────────────────┐
│  Features/     screens + feature logic      │
│                (Home, Scan, Stats, …)       │
└───────────────────────┬─────────────────────┘
                        │ depends on
┌───────────────────────▼─────────────────────┐
│  Core/         data, services, navigation   │
│                (models, sync, extraction)   │
└───────────────────────┬─────────────────────┘
                        │ depends on
┌───────────────────────▼─────────────────────┐
│  Shared/       design system, extensions    │
│                (no business logic)          │
└─────────────────────────────────────────────┘
```

Rules that keep this honest:

- **A feature never imports another feature.** If Home and Stats both need something, it
  belongs in `Core/` or `Shared/`.
- **`Core/` never imports `Features/`.** Services know nothing about screens.
- **`Shared/` holds no business logic** — only presentation primitives and generic extensions.
- **Views never talk to the network.** They read SwiftData; sync happens underneath.

> Swift has no folder-based namespacing — everything in the target sees everything else.
> These boundaries are a convention, not compiler-enforced. Worth watching in review.

---

## Folder structure

```
PiggyFlow/
├── PiggyFlowApp.swift              # entry point, DI composition root
│
├── Core/
│   ├── Data/
│   │   ├── DataManager.swift       # SwiftData container
│   │   ├── Models/                 # Expense, LineItem, Income, Category, Tracker…
│   │   ├── Local/                  # local-only stores
│   │   └── Remote/                 # SyncBackend protocol + Supabase impl
│   ├── Authentication/             # AuthService protocol + Supabase impl
│   ├── Capture/                    # extraction pipeline (see doc 04)
│   │   ├── ExtractedInvoice.swift
│   │   ├── ExpenseExtractor.swift  # protocol
│   │   ├── OnDeviceExtractor.swift
│   │   ├── CloudExtractor.swift
│   │   ├── ExtractionCoordinator.swift
│   │   └── ImageEnhancer.swift
│   ├── Storage/                    # ImageStore protocol + local/remote impls
│   ├── Categorization/             # rule engine + learning store
│   ├── Notifications/              # scheduling
│   └── Navigation/                 # MainTabView, TabBarVisibility
│
├── Features/
│   ├── Home/            (+ Components/)
│   ├── Capture/         # scan → review → save
│   ├── Transactions/    # expense detail + edit
│   ├── Stats/           (+ Components/)
│   ├── Reports/         # range reports
│   ├── Export/
│   ├── Tracker/
│   ├── Settings/
│   ├── Profile/
│   ├── About/
│   ├── Notifications/
│   └── Onboarding/
│
└── Shared/
    ├── DesignSystem/
    │   ├── AppColors.swift         # palette
    │   ├── CardStyles.swift        # gradientHero, groupedCard, flatRow, liftedControl
    │   ├── TextStyles.swift        # sectionEyebrow, tintedPill, …
    │   └── Components/             # TintedIconCircle, RowDivider
    ├── Extensions/
    └── Utilities/                  # Haptics, PDFTableRenderer
```

---

## Protocol seams

Four seams carry the whole design. Each has a protocol in `Core/`, one or more
implementations, and **no UI knowledge of which implementation is live**. This is what makes
"on-device *and* cloud" a runtime choice rather than two codebases.

### 1. `ExpenseExtractor` — bill → structured data

```swift
protocol ExpenseExtractor {
    var kind: ExtractionSource { get }        // .onDevice | .cloud
    var isAvailable: Bool { get }             // cloud needs network + session
    func extract(from images: [UIImage]) async throws -> ExtractedInvoice
}
```

`OnDeviceExtractor` and `CloudExtractor` implement it. `ExtractionCoordinator` picks one
based on the user's setting and availability, and **falls back to on-device** when cloud is
unreachable or errors. The capture UI only ever talks to the coordinator.

### 2. `ImageStore` — bill images

```swift
protocol ImageStore {
    func save(_ images: [UIImage], for expenseID: String) async throws -> [StoredImageRef]
    func load(_ ref: StoredImageRef) async throws -> UIImage
    func delete(_ refs: [StoredImageRef]) async throws
}
```

`LocalImageStore` writes to Documents and is the source of truth for display.
`RemoteImageStore` (Supabase Storage) uploads in the background for cross-device sync.
`CompositeImageStore` writes local-first then enqueues the upload, so capture never blocks
on network.

### 3. `SyncBackend` — record sync

```swift
protocol SyncBackend {
    func upsert(_ change: PendingChange) async throws
    func delete(_ id: String, kind: EntityKind) async throws
    func pullAll(since: Date?) async throws -> RemoteSnapshot
    func observeChanges() -> AsyncStream<RemoteChange>
}
```

Keeps the Supabase migration contained: swapping the implementation touches no screen.

### 4. `AuthService` — identity

```swift
protocol AuthService {
    var currentUser: AuthUser? { get }
    var statePublisher: AnyPublisher<AuthState, Never> { get }
    func signInWithGoogle() async throws
    func signInWithApple() async throws
    func signOut() async throws
    func deleteAccount() async throws
}
```

---

## Offline-first data flow

The app is usable with no network. Reads never touch it.

**Write path**
```
User action → write SwiftData (immediate, UI updates)
            → mark row dirty
            → enqueue change
            → [when online] flush queue → Supabase
```

**Read path**
```
View → @Query SwiftData → render
```

**Remote change path**
```
Supabase realtime → reconcile into SwiftData → @Query re-fires → UI updates
```

Conflict resolution is **last-write-wins on `updatedAt`**, matching the current app. Good
enough for single-user-multi-device; would need revisiting for the shared family/business
accounts in the PRD's future-enhancements list.

---

## Dependency injection

`PiggyFlowApp` is the composition root: it builds the concrete services and injects them
via `.environment(...)`. Nothing else constructs a service. This keeps previews and tests
able to substitute fakes, and is what makes the Firebase→Supabase swap a one-file change.

```swift
@main
struct PiggyFlowApp: App {
    @State private var services = AppServices.live()   // .preview() / .testing() also exist
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
                .modelContainer(services.modelContainer)
        }
    }
}
```

---

## Design system

Already built and in use — **reuse it, do not invent new visuals.** Full list in
`Shared/DesignSystem/`.

| Primitive | Use |
|---|---|
| `gradientHero([colors])` | The **one** bold saturated surface per screen. Never two |
| `groupedCard()` | Elevated container for a group of rows / a distinct module |
| `flatRow()` | A row *inside* a grouped card — no fill of its own |
| `RowDivider(leadingInset:)` | Hairline between flat rows |
| `liftedControl()` | Search fields / filter chips sitting outside a card |
| `TintedIconCircle(color:size:cornerRadius:)` | Icon tile. `nil` radius = circle (avatars), value = rounded square (rows) |
| `sectionEyebrow()` | Small tracked uppercase label above a section |
| `tintedPill(color:)` / `tintedPillOnHero()` | Status badges, on neutral vs gradient backgrounds |
| `Haptics.light()` / `.medium()` | Primary interactions |

**Colour discipline:** green is the brand/primary accent. Red, indigo and amber are
**semantic only** — expense, budget, due-soon. Never decorative. Background is the off-white
`appBackground`; cards are `appSurface`.

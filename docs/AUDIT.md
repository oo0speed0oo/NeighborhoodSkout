# NeighborhoodSkout v1 — Code Audit

**Date:** 2026-10-08  
**Auditor:** Claude (Step 0 of BUILD_PLAN.md)  
**Tools:** Xcode 26.6, iOS SDK 26.5  
**Branch:** main  

---

## 1. What each file does

### Models.swift
Defines every data type the app uses. Nothing else lives here — no logic, no saving.

| Type | What it is |
|---|---|
| `StreetTemplate` | Enum: bothSides / leftOnly / rightOnly / culDeSac. Has `makeConfig(rows:)` and a `description` and `icon`. |
| `GridConfig` | Struct produced by `makeConfig`. Tells the grid: how many rows/cols, which cells are houseable, road, or blank. |
| `Street` | A named street with a template and row count. Has a computed `config` property. |
| `Block` | One house on the grid. Has gridIndex/row/col position, colorName, icon, houseName, and an array of `Person`. |
| `Person` | One resident. Fields: firstName, lastName, gender, birthday, role, lineId. Has computed `fullName` and `age`. |
| `NeighborhoodData` | Codable wrapper used only for JSON template export/import. Holds `[Street]` and `[Block]` (residents stripped). |

**No UUIDs on `Street`.** Only `Block` and `Person` have stable `id: UUID`. Streets are identified by their array index, which shifts when you add or delete a street. This is the root cause of several potential data mixups.

**No `lastModified` anywhere.** Required by SPEC but not yet implemented.

---

### BlockMapViewModel.swift
The app's brain. Creates and manages all `streets` and `blocks`. Handles saving, loading, and template sharing.

**Published state:**
- `@Published var streets: [Street]` — each `didSet` calls `saveAll()`
- `@Published var blocks: [Block]` — each `didSet` calls `saveAll()`
- `@Published var csvLoadMessage: String?` — banner text
- `@Published var isImporting: Bool`, `importError: String?` — for ImportTemplateView

**Saving path:**
1. Any change to `streets` or `blocks` fires `didSet { saveAll() }`
2. `saveAll()` sets `isSaving = true`, writes Documents CSV via `CSVManager.save()`, then calls `saveBackToSource()`
3. `saveBackToSource()` — if a `sourceURL` is remembered in UserDefaults, opens a security-scoped iCloud resource and writes the CSV back to it
4. Sets `isSaving = false`

**Loading path (`autoLoadOnLaunch()`):**
1. Try remembered `sourceURL` from UserDefaults (the iCloud file the user last opened)
2. Auto-detect iCloud Drive (looks for `neighborhood_data.csv` in iCloud Container)
3. Fall back to Documents `neighborhood_data.csv`
4. Fall back to `loadBundledCSV()` → `loadBlankTemplate()` (pre-populates empty houses)

**Key operations:** `addBlock`, `deleteBlock`, `moveBlock`, `renameBlock`, `addResident`, `updateResident`, `removeResident`, `addStreet`, `removeStreet`, `renameStreet`, `templateJSON`, `importTemplate(from:)`

---

### ContentView.swift
The main screen. Shows the zoom bar and map scroll view. Owns all navigation state.

**What it manages:**
- `movingBlockId` — which house is being tap-moved
- `residentsBlockId` / `showLineSheet` — navigation destinations
- `showFilePicker` — file importer for CSV loading
- `showImportSheet` — ImportTemplateView sheet (URL-based template import)
- Confirmation dialogs for house actions (rename, delete, move, residents, LINE)
- `StreetLabelView` with inline rename and delete controls
- The toolbar `Menu` with: Add Home, Add Street, Load from iCloud/Local, Load Default, Share Template (ShareLink), Import from URL

`ImportTemplateView` is defined at the bottom of this file. It is a form with a URL text field and a confirmation dialog before replacing the map.

---

### GridViews.swift
Pure display. Draws the map grid from the VM's state.

- `SingleBlockView` — one house tile. Shows icon, name, resident count. Pulses blue when it is the moving block.
- `RoadCellView` — gray road tile. Center column shows yellow dashes; edge columns show white shoulder line.
- `BlockGridView` — loops rows × cols, calls `vm.isRoad`, `vm.isBlank`, `vm.block` per cell. Empty houseable cells turn green when move mode is active. Tap calls `onCellTap` closure.
- `StreetLabelView` — street name label with inline rename TextField and delete button. Uses `vm.streets[index].name` directly; has a guard against out-of-bounds index.

---

### ResidentsView.swift
Shows residents for one house. Navigation page (pushed from ContentView).

- Groups residents into Grandparents / Parents / Children / Others
- Each `PersonRowView` shows name, birthday, age, gender icon, and (if set) a LINE button
- Tapping a row or the context-menu "Edit" opens `PersonFormView`
- Context-menu "Remove" sets a `deletingId` and shows a confirmation alert

---

### PersonFormView.swift
Add or edit a resident. Used as a sheet from `ResidentsView`.

- Fields: first name (required), last name, gender picker, role picker, birthday date picker, LINE ID text field
- Save button disabled until first name is non-empty
- On appear: pre-populates from `existing` if editing
- On save: preserves the original `id` if editing (so the UUID is stable)
- Trims whitespace from firstName, lastName, and lineId on save — **but does not strip leading `~` or `@` from lineId** (relevant to LINE bug, see §3)

---

### Csvmanager.swift
Reads and writes the CSV file. No state — all static methods.

**Format (two sections in one file):**
```
#STREET,Name,Template,Rows,,,
#STREET,Maple Street,Houses Both Sides,5,,,
HouseName,GridIndex,Row,Col,ColorName,Icon,FirstName,LastName,Gender,Role,Birthday,LineID
The Smiths,0,0,0,purple,🏠,John,Smith,Male,Parent,1980-01-15,johnsmith
```

**Key methods:**
- `save(blocks:streets:)` — writes to `~/Documents/neighborhood_data.csv`
- `load()` — reads from Documents CSV
- `loadFrom(url:)` — reads from any URL (used for iCloud files)
- `buildContent(blocks:streets:)` — builds the CSV string (also used for iCloud write-back)
- `blankTemplateContent()` — generates a starter CSV with 3 default streets and pre-populated empty house slots
- `defaultStreets()` — fallback for CSVs that have no `#STREET` rows (old format)

**Parsing:** Handles quoted fields, embedded commas, and `""` escapes correctly. Falls back to `defaultStreets()` if no `#STREET` rows found (backwards-compatible with old format).

---

### AddStreetView.swift
A sheet for adding a new street. Takes name, template (with a visual picker + description), and row count (stepper 1–10). Shows a live mini-preview of the layout. Calls the `onAdd` closure and dismisses.

---

### LineContactSheet.swift
A navigation page (pushed from ContentView) that lists all residents with a LINE ID for one house. Each person shows as a `LinePersonCard` with a green "Chat" button. Tapping opens `line://ti/p/~{id}` with a fallback to `https://line.me/ti/p/~{id}`.

---

## 2. Where saving happens

| Trigger | Path |
|---|---|
| Any change to `streets` or `blocks` | `didSet` → `saveAll()` → Documents CSV + iCloud write-back |
| App launch | `autoLoadOnLaunch()` loads from iCloud or Documents |
| "Save" toolbar button (ContentView) | `vm.saveToCSV()` → same as `saveAll()` |
| File picker (iCloud/Local) | `vm.loadFromURL(_:)` → sets `sourceURL`, loads, saves to Documents |
| Import from URL | `vm.importTemplate(from:)` → replaces streets + blocks, calls `saveAll()` |
| App goes to background | **Nothing.** There is no `scenePhase` or `applicationWillResignActive` observer. |

---

## 3. Where the LINE button is built

Two places (both call the same URL scheme):

1. **`ResidentsView.swift` line 159** — `PersonRowView.openLine(id:)` — shown inside the residents list, one button per person who has a LINE ID.
2. **`LineContactSheet.swift` line 127** — `LinePersonCard.openLine(id:)` — shown on the dedicated LINE contact page, reached via "Message on LINE" in the house action sheet.

Both build the URL as: `line://ti/p/~\(id)` with fallback `https://line.me/ti/p/~\(id)`.

---

## 4. Bug analysis (SPEC §3)

### Bug 1: Saving is unreliable — data disappears, moves don't stick

**Confirmed root causes:**

**a) No background save.** When the user force-quits or iOS suspends the app, there is no save triggered. If a change happens and the user immediately switches apps before `didSet` fully completes, that change is lost. The fix in SPEC §4 (write atomically on every change AND on `scenePhase` → background) would cover this.

**b) `isSaving` flag can permanently block saves (confirmed).** In `saveAll()`:
```swift
guard !isSaving else { return }
isSaving = true
// ... writes happen ...
isSaving = false
```
If any line between the two `isSaving` assignments returns early (the security-scoped resource path has multiple `return` statements), `isSaving` stays `true` forever for the lifetime of the VM. After that, **every save is silently skipped.** The app appears to work but nothing is written.

**c) iCloud source URL can become stale.** The remembered `sourceURL` in UserDefaults points to an iCloud file. If that file is moved, deleted, or temporarily unavailable (e.g. offline), `autoLoadOnLaunch()` falls through to the Documents CSV — which may be from a different or older session. The user sees their old data and any changes since the last Documents write are gone.

**d) No Application Support JSON.** SPEC requires a local JSON in Application Support as source of truth. This does not exist yet. The Documents CSV is the only persistent store, and it is not atomic (the `write(to:atomically:true)` call is atomic per-write, but a crash while building the CSV string could leave an empty file).

**Guess (unconfirmed):** App restarts may be crashes. The `line://` URL construction force-unwraps (`URL(string:)!`) — if `lineId` contains characters that make an invalid URL (spaces, special chars), this crashes the app. This would explain the "app restarts on its own" symptom.

---

### Bug 2: LINE button does not connect

**Confirmed causes:**

**a) The stored lineId may already have a `~` prefix.** If a user types `~johnsmith`, the URL becomes `line://ti/p/~~johnsmith`, which is invalid. `PersonFormView` trims whitespace but does not strip `~` or `@`. No sanitization exists anywhere in the save path.

**b) LINE force-unwrap crash.** `URL(string: "line://ti/p/~\(id)")!` crashes if `id` contains a space or special character. This is both a crash risk (Bug 1 cause) and a LINE connectivity bug.

**Confirmed (checked Info.plist):** `line` IS in `LSApplicationQueriesSchemes`. This was a false alarm.

**Guess (unconfirmed, need real device test):** LINE's URL scheme format. The form `line://ti/p/~ID` is documented but older. The form `https://line.me/R/ti/p/~ID` (note the `/R/`) may be more reliable on newer LINE versions.

**Outside our control:** If the neighbor's LINE account has "Allow search by ID" turned off, the link opens LINE but shows no result. Cannot fix in code.

---

### Bug 3: Dragging houses did not work

**Confirmed:** Drag is not implemented. The current design uses tap-to-move: tap a house → action sheet → "Move" → tap a green empty cell. This works correctly in the current code (`movingBlockId` state in ContentView, green highlight in `BlockGridView`). No fix needed.

---

## 5. Things to discuss before Step 1

1. **Street IDs.** Streets have no `id: UUID`. Step 1 adds one. This changes `NeighborhoodData` (the template export format). Existing CSVs match streets by index — this is fine since the CSV keeps order.

2. **Migration plan.** Step 1 adds a JSON store in Application Support. On first launch after the update, the app should: (1) make a dated backup of the existing CSV, (2) read it, (3) write it to JSON, (4) use JSON as source of truth going forward. The CSV stays as an optional import.

3. **The `isSaving` flag.** The safest fix is `defer { isSaving = false }` at the top of `saveAll()` so the flag always resets even if the function returns early. A more robust fix for Step 1 is a serial `DispatchQueue` for file writes.

4. **Force-unwrap in LINE URL.** `URL(string: "line://ti/p/~\(id)")!` should become an optional unwrap with a guard. Fix is one line; can do this in Step 2 as planned.

5. **Info.plist.** Need to open in Xcode and check `LSApplicationQueriesSchemes` before Step 2.

---

## 6. Summary: confirmed vs. guessed

| Finding | Status |
|---|---|
| No background save (app suspend / force-quit loses data) | **Confirmed** |
| `isSaving` flag can permanently block saves on any early return | **Confirmed** |
| iCloud sourceURL can become stale and lose data | **Confirmed** |
| No Application Support JSON (SPEC requirement missing) | **Confirmed** |
| LINE force-unwrap crash if lineId has spaces/special chars | **Confirmed** |
| LINE ID not sanitized (leading `~` or `@` doubles the prefix) | **Confirmed** |
| `line` present in `LSApplicationQueriesSchemes` | **Confirmed (false alarm)** — it's already there |
| App "restarts" = crash triggered by LINE URL force-unwrap | **Guess** |
| LINE URL scheme format changed (`/R/` variant more reliable) | **Guess** — need real device test |

---

*No app code has changed. This document is for review only.*

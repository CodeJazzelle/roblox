# Dutch Bros Rush

A chaotic 2–4 player co-op Roblox game inspired by Overcooked, themed around working at a Dutch Bros coffee stand. Craft drinks, serve customers, customize your Broista, and earn Bro Bucks to spend on Dutch Bros merch.

- **Server-authoritative** drink validation — no client-side trust.
- **Cosmetics-only economy** — visual merch only, no pay-to-win.
- **Cross-platform** controls (PC, mobile, console).
- **3–5 minute rounds**, dynamic stage variants, chaos modifiers, environmental hazards.
- **Dutch Bros visual identity**: blue (`#005AAB`), windmill iconography, wholesome chaotic tone.

---

## Setup

This project syncs into Roblox Studio via [Rojo](https://rojo.space).

### 1. Install Rojo

Install the CLI via [Aftman](https://github.com/LPGhatguy/aftman) (recommended), [Foreman](https://github.com/Roblox/foreman), or directly:

```bash
# Aftman (recommended)
aftman add rojo-rbx/rojo

# Or download a release directly:
# https://github.com/rojo-rbx/rojo/releases
```

Verify:

```bash
rojo --version   # should print 7.x or newer
```

### 2. Install the Rojo Studio plugin

In Roblox Studio: **Plugins → Manage Plugins → Install** the official "Rojo" plugin, or build it locally with `rojo plugin install`.

### 3. Start a Rojo session

From the project root:

```bash
rojo serve
```

Rojo will print `Rojo server listening: http://localhost:34872`.

### 4. Connect from Studio

1. Open a new Studio place (Baseplate is fine).
2. Open the **Rojo** plugin panel.
3. Click **Connect**.
4. The full source tree will materialize under the right services.

While `rojo serve` is running, every save in your editor live-syncs into Studio. Press **F5** to playtest.

### 5. Build a `.rbxlx` (optional)

To produce a standalone place file without an active Rojo session:

```bash
rojo build -o DutchBrosRush.rbxlx
```

Open the resulting file in Studio.

---

## Project structure

```
src/
├── ReplicatedStorage/
│   └── Modules/
│       ├── DrinkRecipes.lua           # 16 canonical drinks + syrup/topping tables
│       ├── CupState.lua               # In-progress cup with MatchesRecipe validator
│       ├── SecretMenuGenerator.lua    # Random secret-menu drinks (2× tip)
│       └── MerchCatalog.lua           # 52 cosmetic items, 6 categories
│
├── ServerScriptService/
│   ├── RemotesSetup.server.lua        # Bootstrap: creates Remotes folder + wires lifecycle
│   ├── OrderManager.lua               # Spawns orders, validates submissions
│   ├── StationInteraction.server.lua  # ProximityPrompt wiring (CollectionService driven)
│   ├── RoundManager.lua               # Round loop, tip totals, star rating
│   ├── PlayerData.lua                 # DataStore wrapper (Bro Bucks, merch, stats)
│   ├── EconomyManager.lua             # Tips → BB, purchase validation
│   ├── StageManager.lua               # 6 stages, 7 chaos modifiers
│   └── HazardSpawner.lua              # 7 hazard event types
│
├── StarterPlayer/StarterPlayerScripts/
│   ├── CharacterCustomizer.client.lua # Lobby cosmetic menu (M)
│   ├── OrderUI.client.lua             # Order queue with timers
│   ├── QuickChatWheel.client.lua      # Hold C, radial chat
│   ├── PingSystem.client.lua          # Hold G + click to ping
│   └── MerchShopUI.client.lua         # Shop browser (B)
│
└── StarterGui/
    ├── RoundTimer/                    # ScreenGui + Display.client.lua
    ├── TipsCounter/                   # ScreenGui + Display.client.lua
    └── EndOfRoundScreen/              # ScreenGui + Display.client.lua

default.project.json                   # Rojo project mapping
.gitignore                             # Rojo build artifacts, Wally packages, OS junk
```

---

## Controls

| Key / input | Action |
|---|---|
| **WASD** / left stick / on-screen joystick | Move |
| **E** (or Roblox default) | Activate ProximityPrompts (cup tower, syrup pumps, etc.) |
| **M** | Toggle Character Customizer |
| **B** | Toggle Merch Shop |
| **Hold C** | Open Quick Chat wheel |
| **Hold G + click** | Ping a world location |

Mobile/console: ProximityPrompts and on-screen buttons are auto-handled by Roblox. The custom UIs (shop, customizer) currently key off keyboard — add corresponding mobile hotbar buttons before shipping.

---

## How the systems fit together

```
                  ┌─────────────────┐
                  │ RemotesSetup    │  ← bootstrap (creates Remotes + requires modules)
                  └────────┬────────┘
                           │ requires & wraps
                           ▼
   ┌────────────┐     ┌─────────────┐     ┌──────────────┐
   │ PlayerData │ ◄── │ Economy     │ ──► │ MerchCatalog │
   └────────────┘     │ Manager     │     └──────────────┘
                      └──────┬──────┘
                             │ awards BB on tip
                             ▼
   ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
   │ Stage        │ ◄── │ Round        │ ──► │ Order        │
   │ Manager      │     │ Manager      │     │ Manager      │
   └──────────────┘     └──────┬───────┘     └──────────────┘
                               │                    ▲
                               ▼                    │ submits
   ┌──────────────┐     ┌──────────────┐     ┌──────┴───────┐
   │ Hazard       │     │ Round        │     │ Station      │
   │ Spawner      │     │ lifecycle    │     │ Interaction  │
   └──────────────┘     └──────────────┘     └──────────────┘
```

Phase 1 modules (`OrderManager`, `RoundManager`, `StationInteraction`) are unmodified — Phase 2 systems hook in via wrappers in `RemotesSetup.server.lua` so they stay untouched.

---

## Workspace setup

The codebase is wired up but the **3D stand isn't built yet** — you build that in Studio. The interaction code uses `CollectionService` tags so you can place stations anywhere and tag them.

### CollectionService tags expected by `StationInteraction.server.lua`

| Tag | Where | Notes |
|---|---|---|
| `CupTower_Small` | A Part | Player picks up a Small cup |
| `CupTower_Medium` | A Part | Medium cup |
| `CupTower_Large` | A Part | Large cup |
| `EspressoMachine` | A Part | Sets cup base = Espresso |
| `RebelTap` | A Part | Sets base = Blue Rebel |
| `TeaBrewer` | A Part | Sets base = Tea |
| `LemonadeDispenser` | A Part | Sets base = Lemonade |
| `MilkSteamer` | A Part | Sets base = Milk |
| `SyrupPump` | A Part with `SyrupName` attribute (string) | Adds that syrup |
| `ToppingStation` | A Part with `ToppingName` attribute | Adds topping |
| `LidStation` | A Part | Applies lid (final step) |
| `TrashCan` | A Part | Discards current cup |

A `ProximityPrompt` is auto-attached at server start if one isn't present. You can also pre-place prompts in Studio with custom HoldDuration/ActionText.

### What's still TODO before this is playable

- [ ] **Build the stand in Workspace** and tag the parts above.
- [ ] **Submit station** — wire a tagged `CustomerWindow` (or similar) that calls `OrderManager:SubmitDrink(player, orderID, cupData)` server-side. Currently nothing fires this.
- [ ] **Real Roblox catalog asset IDs** — `MerchCatalog` items all have `accessoryAssetId = 0` and `iconAssetId = 0` placeholders.
- [ ] **Apply equipped cosmetics** — `PlayerData.equipped` is persisted but not visually applied to the character yet. Add a server-side `CharacterApply` script that listens to `ProfileLoaded` / `EquipResult` and equips Roblox accessories.
- [ ] **Mobile hotbar buttons** for the custom UIs (M / B / C / G are PC-only as written).
- [ ] **Voice packs / weird heads** — IDs are listed in `CharacterCustomizer.client.lua` but not yet bound to actual assets.

---

## Notes on persistence

`PlayerData.lua` uses a basic `DataStoreService` wrapper with retries and an autosave loop, plus `BindToClose` flushes. **Studio writes are skipped for safety** so nothing pollutes live data when you playtest.

For production I'd recommend swapping in [ProfileService](https://madstudioroblox.github.io/ProfileService/) or [Suphi DataStore](https://github.com/Suphi5/SuphiDataStoreModule) — both handle cross-server session locking and reconciliation. The API surface (`Get`, `AddBroBucks`, `GrantMerch`, `Equip`, etc.) is small enough that swapping the implementation underneath is a contained change.

---

## Tone & design constraints

- **Wholesome chaotic** — no violence, no scary themes. Hazards are silly (toaster head, syrup spill, espresso fire), not threatening.
- **All cosmetics are visual** — purchases never affect drink validation, walk speed, customer patience, or any gameplay metric.
- **Server-authoritative drink validation** — clients only display the cup; the real `CupState` lives on the server and `OrderManager:SubmitDrink` is what decides success.
- **Tips → Bro Bucks at 1:1** — each completed order's tip becomes Bro Bucks for the player who served it, plus end-of-round tips are split among all players in the server.

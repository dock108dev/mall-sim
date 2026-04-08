# UI/UX Specification

This document defines the layout, behavior, and interaction patterns for all UI panels in mallcore-sim. The game is desktop-first (mouse + keyboard) at 1920×1080 default resolution.

---

## Screen Regions

The screen is divided into functional regions:

```
+---------------------------------------------------+
|  TOP BAR (HUD) — always visible during gameplay   |
+--------+----------------------------------+-------+
|        |                                  |       |
|  LEFT  |         CENTER                   | RIGHT |
| PANEL  |    (3D game view, unobscured)    | PANEL |
| DOCK   |                                  | DOCK  |
|        |                                  |       |
+--------+----------------------------------+-------+
|  BOTTOM BAR — interaction prompts, tooltips       |
+---------------------------------------------------+
```

- **Top bar**: Fixed height (~48px at 1080p). Always visible. Contains HUD info.
- **Left panel dock**: Slides in from left. Max width 380px. Used for inventory, catalog.
- **Right panel dock**: Slides in from right. Max width 380px. Used for pricing, item details.
- **Center**: Sacred. Never obscured by panels. This is where the 3D store view lives.
- **Bottom bar**: Fixed height (~36px). Interaction prompts ("Press E to Stock Shelf"), tooltips.

### Panel Rules

1. Only one panel per dock at a time (opening inventory closes catalog in the left dock)
2. Both docks can be open simultaneously (inventory left + pricing right)
3. Panels slide in/out with a 200ms ease-out animation
4. Pressing the same shortcut again closes the panel (toggle behavior)
5. Esc closes all open panels
6. Player can still move and look while panels are open (panels are overlays, not modal)
7. Mouse cursor is freed when any panel is open (exits mouse-look mode)
8. Clicking back into the 3D view re-locks the cursor and closes panels

---

## HUD (Top Bar)

**Reference**: issue-013

Always visible during gameplay. No toggle needed.

```
+---------------------------------------------------+
| 💰 $1,234.56  |  ☀ Day 7  |  🕐 2:30 PM (▶ 1x) |  ⭐ Local Favorite (42)  |
+---------------------------------------------------+
```

| Element | Position | Data Source | Update Frequency |
|---|---|---|---|
| Cash balance | Left | EconomySystem.cash | On every transaction |
| Day number | Center-left | TimeSystem.current_day | On day change |
| Time of day | Center | TimeSystem.current_time | Every game minute |
| Time speed indicator | Center (after time) | TimeSystem.speed | On speed change |
| Reputation tier + score | Right | ReputationSystem | On reputation change |

### Time Speed Display

- Paused: `⏸ Paused`
- 1x: `▶ 1x`
- 2x: `▶▶ 2x`
- 4x: `▶▶▶▶ 4x`

### Cash Animation

When cash changes, briefly flash green (increase) or red (decrease) with a counting-up/down animation over 0.5s.

---

## Inventory Panel (Left Dock)

**Reference**: issue-007
**Shortcut**: `I`
**Position**: Left dock, full height
**Width**: 360px

### Layout

```
+------------------------------------+
| INVENTORY                    [X]   |
+------------------------------------+
| [Backroom ▼] [Shelves] [All]       |  <- Tab bar
+------------------------------------+
| 🔍 Search...              [Filter] |  <- Search + filter
+------------------------------------+
| +--------------------------------+ |
| | [icon] Griffey Rookie Card     | |
| |   Condition: Near Mint         | |
| |   Value: $180.00   Price: —    | |
| |   📍 Backroom                  | |
| +--------------------------------+ |
| | [icon] Jordan Autograph Ball   | |
| |   Condition: Good              | |
| |   Value: $95.00   Price: $125  | |
| |   📍 card_case_1:slot 3        | |
| +--------------------------------+ |
| | ...                            | |
| +--------------------------------+ |
+------------------------------------+
| Items: 23/100 (backroom capacity)  |
+------------------------------------+
```

### Tab Behavior

- **Backroom**: Shows only items with location "backroom"
- **Shelves**: Shows only items on fixtures (location starts with "shelf:")
- **All**: Shows everything

### Item Row

Each item row displays:
- Icon (32×32, from ItemDefinition.icon_path, or placeholder)
- Name (ItemDefinition.item_name)
- Condition badge (colored: mint=gold, near_mint=green, good=blue, fair=yellow, poor=red)
- Market value (base_price × condition_multiplier)
- Player-set price (if set, otherwise "—")
- Current location

### Interactions

- **Click item**: Select it, show details in right panel (if not already open)
- **Right-click item**: Context menu → Price, Move to Shelf, Move to Backroom, Inspect
- **Drag item** (from backroom tab): Begin shelf placement flow (issue-006)

### Filter Options

Dropdown with:
- Category (cards, memorabilia, sealed, etc. — from ItemDefinition.category)
- Rarity (common through legendary)
- Condition
- Sort by: name, value, condition, recently acquired

---

## Price Setting Panel (Right Dock)

**Reference**: issue-008
**Shortcut**: `P` (or opened via right-click → Price on an item)
**Position**: Right dock
**Width**: 340px

### Layout

```
+------------------------------------+
| SET PRICE                    [X]   |
+------------------------------------+
| [icon] Griffey Rookie Card         |
| Condition: Near Mint               |
+------------------------------------+
| Market Value:          $180.00     |
| Condition Modifier:    ×1.5        |
| Effective Base:        $270.00     |
+------------------------------------+
| Your Price:                        |
| [$___270.00___]                    |
|                                    |
| Markup: [========|====] 1.00x      |
|         0.5x              3.0x     |
|                                    |
| ⚡ Below market — sells fast       |
| 📊 Est. sale time: < 1 day        |
+------------------------------------+
| [Apply]  [Apply to All Similar]    |
+------------------------------------+
```

### Markup Slider

- Range: 0.5x to 3.0x of effective base (base_price × condition_multiplier)
- Default position: 1.0x (at market value)
- Color-coded regions:
  - Green (0.5–0.9x): Below market, fast sales, reputation positive
  - Blue (0.9–1.1x): At market, normal turnover
  - Yellow (1.1–1.5x): Above market, slower sales
  - Red (1.5–3.0x): Premium pricing, very slow sales, reputation risk

### Price Feedback

Below the slider, dynamic feedback text:
- `< 0.9x`: "Below market — sells fast, builds reputation"
- `0.9–1.1x`: "At market — normal turnover"
- `1.1–1.5x`: "Above market — slower sales"
- `> 1.5x`: "Premium pricing — only collectors will pay this"
- `> 2.5x`: "Extreme markup — may hurt reputation"

### Apply to All Similar

Applies the same markup ratio (not the same dollar amount) to all items with the same ItemDefinition ID. Useful for bulk pricing common cards.

---

## Day Summary Screen (Modal)

**Reference**: issue-014
**Trigger**: Automatically shown when day ends
**Behavior**: Pauses game, modal overlay, must be dismissed to continue

### Layout

```
+--------------------------------------------------+
|              DAY 7 SUMMARY                        |
+--------------------------------------------------+
|                                                   |
|  Revenue:        $347.50    (+12% vs yesterday)   |
|  Cost of Goods:  -$142.00                         |
|  Operating Cost: -$50.00    (rent)                |
|  ─────────────────────────                        |
|  Net Profit:     $155.50                          |
|                                                   |
|  Items Sold:     12                               |
|  Customers:      18 visited, 12 purchased (67%)   |
|  Best Sale:      Griffey Rookie (NM) — $180.00    |
|                                                   |
|  Reputation:     42 → 44 (Local Favorite)         |
|  Cash Balance:   $1,234.56                        |
|                                                   |
+--------------------------------------------------+
|  TOMORROW'S DELIVERIES                            |
|  • 3× common sports cards (ordered yesterday)     |
|  • 1× sealed wax box                              |
+--------------------------------------------------+
|                                                   |
|  [Order Stock]    [Continue to Day 8]             |
|                                                   |
+--------------------------------------------------+
```

### Data Sources

- Revenue, costs, profit: EconomySystem daily ledger
- Items sold, customers: tracked via EventBus signals during the day
- Best sale: highest single transaction
- Reputation change: ReputationSystem delta for the day
- Tomorrow's deliveries: pending orders from OrderSystem

### Actions

- **Order Stock**: Opens catalog/ordering panel (issue-025, wave-2)
- **Continue**: Advances to next morning, triggers overnight delivery, saves game

---

## Item Tooltip (Hover)

**Reference**: issue-055 (wave-3), but basic version needed for M1

Appears when hovering over any item in inventory panels or on shelves (via raycast).

```
+-------------------------------+
| Griffey Rookie Card           |
| ★★★ Rare                     |
| Condition: Near Mint          |
| Market Value: $180.00         |
| Your Price: $195.00 (1.08x)  |
| "1989 rookie card. HOF."     |
+-------------------------------+
```

Width: auto-sized to content, max 280px. Follows mouse with offset. 200ms delay before showing (prevents flicker during browsing).

---

## Store Catalog / Ordering Panel (Left Dock)

**Reference**: issue-025 (wave-2)
**Shortcut**: `C`
**Position**: Left dock

Pre-spec for wave-2. Shows available items for purchase from suppliers, filtered by current supplier tier.

```
+------------------------------------+
| CATALOG — Tier 1 Supplier    [X]   |
+------------------------------------+
| [Category ▼]  🔍 Search...        |
+------------------------------------+
| [icon] Base Set Booster Pack       |
|   Rarity: Common                   |
|   Wholesale: $2.40   Qty: [__5__] |
|   [Order]                          |
+------------------------------------+
| [icon] Griffey Common Card         |
|   Rarity: Common                   |
|   Wholesale: $1.20   Qty: [__3__] |
|   [Order]                          |
+------------------------------------+
| ...                                |
+------------------------------------+
| Order Total: $19.20   [Place All]  |
+------------------------------------+
```

---

## Keyboard Shortcut Map

All shortcuts in one place for conflict detection:

| Key | Action | Context | Conflicts? |
|---|---|---|---|
| `W/A/S/D` | Movement | Always (when cursor locked) | — |
| `Mouse` | Look | When cursor locked | — |
| `E` | Interact | Aiming at interactable | — |
| `I` | Toggle inventory panel | Always | — |
| `P` | Toggle pricing panel | Always | — |
| `C` | Toggle catalog panel | Always (wave-2) | — |
| `Space` | Pause/resume time | Always | — |
| `1` | Set time 1x | Always | — |
| `2` | Set time 2x | Always | — |
| `3` | Set time 4x | Always | — |
| `4` | Pause time | Always | — |
| `Tab` | Toggle management view | Always | — |
| `Esc` | Close panels / open pause menu | Always | — |
| `F1` | Debug overlay | Dev builds | — |
| `F11` | Fullscreen toggle | Always | — |

**Shortcut rules**:
- No single-key shortcut that could interfere with typing in a text field
- All shortcuts are re-bindable via settings (issue-027, wave-2)
- When a text input is focused, only Esc and Tab work as shortcuts

---

## Pause Menu (Modal Overlay)

**Reference**: issue-029 (wave-2)
**Trigger**: Esc (when no panels are open)

```
+---------------------------+
|         PAUSED            |
|                           |
|    [Resume]               |
|    [Settings]             |
|    [Save Game]            |
|    [Quit to Menu]         |
|    [Quit to Desktop]      |
+---------------------------+
```

Dimmed background. Game time paused. All keyboard shortcuts disabled except Esc (to resume).

---

## Visual Style Guide

### Colors

- **Background panels**: Dark navy (#1a1a2e) at 90% opacity
- **Panel borders**: Warm gold (#c9a45c) 1px
- **Text primary**: Off-white (#e8e0d0)
- **Text secondary**: Muted tan (#a09880)
- **Accent (positive)**: Soft green (#6bbd5b)
- **Accent (negative)**: Soft red (#d45b5b)
- **Rarity colors**: Common=#a0a0a0, Uncommon=#4a9e4a, Rare=#4a7ab5, Very Rare=#9b59b6, Legendary=#e8a42c

### Typography

- **Headings**: Bold, 18px equivalent at 1080p
- **Body text**: Regular, 14px equivalent at 1080p
- **Small text** (tooltips, secondary info): 12px equivalent, never smaller
- **Numbers** (prices, stats): Monospace variant for alignment

### Condition Badge Colors

- Mint: Gold (#e8a42c)
- Near Mint: Green (#4a9e4a)
- Good: Blue (#4a7ab5)
- Fair: Yellow (#c9a45c)
- Poor: Red (#d45b5b)

---

## UI Scaling

- Default: 1.0x at 1920×1080
- Minimum resolution: 1280×720 (UI scales down, panels may narrow to 300px)
- 4K: 2.0x scale (or system DPI scaling)
- All layout values in this doc are for 1080p — scale proportionally
- Font sizes never drop below 12px equivalent regardless of scaling
# Mallcore Sim — Design

## Design Principles

1. **Finish before feature.** Every mechanic is fully implemented or deleted. No `return false` placeholders, no stub UI.
2. **Signals as contract.** Systems communicate only through `EventBus` signals. Direct cross-system node refs create hidden coupling and break tier init order.
3. **Content as data.** All items, events, dialogue, trends, endings, objectives live in JSON under `game/content/`. GDScript holds no content strings or tuning numbers.
4. **Single PriceResolver.** Every price decision routes through `PriceResolver.resolve()`. Balance changes are a one-file edit; audit trace stays complete.
5. **One controller per store.** Parallel controllers split state and double-emit signals.
6. **Hub + drawer, not walk-and-click.** Store mechanics live in drawers over the mall hub. No walkable store interiors.
7. **Originality.** All names, brands, characters, franchises are invented. No trademarked IP, even as parody.

## Core Loop

```
stock → price → sell → close day → read summary
```

One loop is ~60 seconds in the vertical slice. A full day is ~5–8 minutes. A 30-day arc is 3–4 hours.

## Visual System

Four-layer palette. Luminance separates layers; saturation signals meaning.

**Layer 1 — World (low saturation, recedes):** concourse floor, walls, ceiling shadow. Desaturated warm earth tones.

**Layer 2 — Interactive Surface (high contrast):**
- **Dark panel** (`#1F1A16` fill, `#F4E9D4` text, 15:1 contrast) — running state: HUD, ticker, status rail.
- **Light panel** (`#F5ECD6` fill, `#2B1D12` text, 14:1 contrast) — decisions: purchase dialogs, day summary, menus.

**Layer 3 — Store Identity (one saturated hue per store):** used only on borders, headers, category badges. Never on body text unless darkened.

| Store | Accent |
|---|---|
| Retro Games | Cartridge Purple `#7B4BCF` |
| Pocket Creatures | Holo Teal `#2EB5A8` |
| Video Rental | VHS Red `#D13B2E` |
| Electronics | CRT Cyan `#3AA8D8` |
| Sports Cards | Foil Gold `#C99A2B` |

**Layer 4 — Semantic (shared across stores):** Success `#6DCF5A`, Warning `#F2B81C`, Error `#E53E2B`, Critical `#FF2D4F`, Money-gain `#8FE075`, Money-cost `#FFB4A8`. Every state pairs color with a shape/icon (✓ ! ✕ ◆) for colorblind fallback.

**Hierarchy rules:**
- Text never sits on the world — only on dark or light panels.
- Luminance contrast ≥3:1 between adjacent layers before saturation is considered.
- Store-accent + alert pixels ≤10 % of the screen at any moment.
- One alert at a time. Queue; never stack two saturated colors side by side.

**Typography:**
- Primary UI: rounded bold sans (Nunito ExtraBold / Varela Round), tracking +80 to +150.
- Counters / money: condensed gothic (Barlow Condensed ExtraBold).
- Store name labels: all-caps, +100 to +150 tracking, 16–18 pt.
- Body: minimum +40 tracking.

## Key Patterns

### Boot
```gdscript
# boot.gd — runs after all autoloads
func _ready() -> void:
    var errors := ContentRegistry.validate_all()
    if errors.size() > 0:
        for e in errors: push_error(e)
        get_tree().change_scene_to_file("res://game/scenes/ui/validation_error_screen.tscn")
        return
    GameManager.initialize()
    # transition to main menu
```

### Store controller shape
```gdscript
class_name RetroGamesController
extends StoreController

func sell_item(item_id: StringName, condition: float) -> void:
    var breakdown := PriceResolver.resolve(item_id, {"condition": condition, "store_id": store_id})
    CheckoutSystem.process_sale(store_id, item_id, breakdown)
    # CheckoutSystem emits item_sold. Never emit it here.
```

### Drawer UI
```gdscript
# Drawer open: tween custom_minimum_size.x, not AnimationPlayer
# MOUSE_FILTER_STOP on drawer, MOUSE_FILTER_IGNORE on HUD root
tween.tween_property(drawer, "custom_minimum_size:x", 420.0, 0.25)
EventBus.drawer_opened.emit(store_id)
```

### Objective rail
```gdscript
# ObjectiveDirector — listens to gameplay, publishes to the rail
EventBus.first_sale_completed.connect(_on_first_sale)

func _on_first_sale(_sid, _iid, _p, _b) -> void:
    EventBus.objective_changed.emit({
        "objective": "Close out day 1",
        "action": "Click the clock to end the day",
        "key": "SPACE",
    })
```

### PriceResolver consumption
```gdscript
var bd := PriceResolver.resolve(item_id, ctx)
var final_price: float = bd["final"]
# never multiply modifiers yourself; add a new multiplier fn to PriceResolver.
```

### Content access
```gdscript
# Always through ContentRegistry; never call DataLoader directly.
var item := ContentRegistry.get_item(item_id)   # validated dict or crash
var base: float = item["base_price"]
```

### IDs are StringName
All identifiers (`store_id`, `item_id`, `event_id`) are `StringName` at runtime, matching the `"id"` field in JSON. Use `&"retro_games"` literals at call sites to avoid string allocation.

## Per-Store Mechanics

Each store's mechanic is a **four-beat atomic unit**: Setup → Interaction → Outcome → Feedback (audio + visual + number + one sentence of character).

### Retro Games — Refurbishment
- **Setup:** pick one of three shelved items.
- **Interaction:** choose tier — Clean / Repair / Restore.
- **Outcome:** condition animates; item moves to "ready" shelf.
- **Feedback:** *"You polished that cartridge from Fair to Excellent. It could sell for $45–60 now."*

### Pocket Creatures — Pack Opening
- **Setup:** sealed pack on counter.
- **Interaction:** click to open; 6–10 face-down flips.
- **Outcome:** rarity-weighted reveal (Common 60 / Uncommon 30 / Rare 9 / Ultra 1 / Secret <1).
- **Feedback:** rare chime, gold border, *"Moppetflare! That's a $15 card at least."*
- **Depth:** `MetaShiftSystem` rotates hot creature; `TournamentSystem` drives weekly trend spikes.

### Video Rental — New-Release Cycle
- **Setup:** customer picks a tape.
- **Interaction:** set return-by date.
- **Outcome:** rental recorded with premium if in 0–7 day new-release window.
- **Feedback:** overdue tracker posts late fees at day close: *"3 customers overdue. +$12 late fees."*

### Electronics — Warranty Upsell
- **Setup:** customer buys an item.
- **Interaction:** prompt — None / Basic 1-yr / Premium 2-yr.
- **Outcome:** warranty stored on customer profile; margin recorded.
- **Feedback:** *"Warranty attach rate 14% today — good upsell."*

### Sports Cards — Grading
- **Setup:** submit card to grading.
- **Interaction:** pay grading fee; wait one day.
- **Outcome:** PSA-style 1–10 grade returns with population count; PriceResolver condition multiplier updates.
- **Feedback:** *"PSA 8. Population 340 at this grade. That's a $2,400 card now."*

## Narrative Layer

Optional depth. A player who never engages it still has a complete game.

### Ambient Moments
Seven customer archetypes, six recurring minor characters, ten store-event types rotate through the hub and ticker. All names and backstories invented.

Archetypes: Browser, Haggler, Nostalgic Parent, Collector Kid, Teenager Killing Time, Power Walker, Sample Grazer.

### Secret Threads
Four multi-phase character reveals. Each uses a three-layer model:

1. **Surface** — always visible behavior.
2. **Signal** — anomalies rewarding attention.
3. **Substrate** — the truth, unlocked by deliberate player action.

Fairness rules:
- Every revelation preceded by ≥2 observable signals ("of course" moment).
- No thread completes without a deliberate player action.
- Every thread has a non-resolution path.
- Passive players are not penalized; only active players unlock the achievement.

Thread IDs (content; fully original): `regular_at_food_court`, `skeptic_critic`, `ghost_tenant_7b`, `mall_legend`.

## Day Summary

Launched on `day_closed`. Light-panel modal. Always contains:

1. **Revenue delta** vs. yesterday.
2. **Best sale** — item + final price + the PriceResolver step that contributed most.
3. **One story beat** — an ambient-moments or secret-thread line. Required even on zero-revenue days.
4. **One forward hook** — tomorrow's event telegraph, a milestone inches closer, an unlock within reach.

## Anti-Patterns

| Anti-pattern | Why it's banned |
|--------------|-----------------|
| `return false` / `return null` stub methods | Silently breaks callers. Use a signal or crash loud. |
| Direct cross-system node refs | Breaks tier init order; bypasses EventBus contract. |
| Content type detection by heuristic | Use explicit `"type"` field in JSON. |
| Duplicate milestone UI components | Causes double-display bugs. One `MilestoneCard` only. |
| Price multipliers outside PriceResolver | Breaks audit trace; balance changes turn into hunts. |
| Content strings embedded in `.gd` | Breaks localization; requires a code change to edit content. |
| Parallel controllers for the same store | Splits state; double-emits signals. |
| Walkable store interiors | Contradicts the hub + drawer decision. |
| Real-world IP references | Names, brands, players, titles must be invented. |

## Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Files | `snake_case` | `retro_games_controller.gd` |
| Classes | `PascalCase` (matches filename) | `RetroGamesController` |
| Signals | past-tense verb | `item_sold`, `day_closed` |
| Constants | `ALL_CAPS_SNAKE` | `MAX_HAGGLE_ROUNDS` |
| Functions | `snake_case` | `resolve_price()` |
| JSON keys | `snake_case` | `base_price`, `store_id` |

## Error Handling

- **Content errors at boot:** `ContentRegistry.validate_all()` returns every error; boot shows them all on `validation_error_screen.tscn`. Never silently skip bad content.
- **Runtime errors:** emit a failure signal on `EventBus`, log via `push_warning`, degrade gracefully (skip the broken item, finish the day).
- **Save errors:** atomic temp-file swap. On read failure, preserve the existing save and surface an error; never overwrite with corrupt state.
- **Input validation:** only at system boundaries (player input, file I/O). Trust internal function contracts.

## Testing Strategy

- **Content integrity:** parameterized GUT tests over every JSON record. Assert required keys, types, cross-ref resolution.
- **Signal-chain integration:** instantiate a store controller, call a method, assert signal sequence via `watch_signals`.
- **Migration isolation:** per-version fixture + per-version unit test; one integration test runs the full chain.
- **Interaction audit:** `tests/audit_run.sh` boots headless, injects input, parses `[AUDIT]` lines. CI fails on any FAIL.
- **Content originality:** CI grep against a banned-terms list (Pokémon, Nintendo, Blockbuster, PSA, ESPN, etc.). Any hit fails the build.
- **Excluded:** Godot internals, shader output, anything requiring a display server.

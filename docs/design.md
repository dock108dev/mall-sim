# Design — Mallcore Sim

## 1. Design Philosophy

Mallcore Sim is built around one central question: **"What can I do right now?"** If a player cannot answer that question within three seconds of looking at any screen, that screen is broken.

The guiding tension is **legibility vs. depth**. Systems must be deep enough to reward experimentation but never so opaque that the player is guessing. Every mechanic earns its keep by being visible, understandable, and satisfying on first encounter.

### Non-negotiables

1. **Legibility before depth.** Playability is not optional. A system nobody understands does not exist.
2. **One complete loop before five partial ones.** The vertical slice is the truth — ship one store fully before broadening.
3. **Management hub, not walkable world.** The mall is a clickable strategic shell. Player-controller movement belongs only behind an explicit debug feature flag.
4. **Content is data.** All stores, items, milestones, and customers are JSON. A designer adds content without touching GDScript.
5. **No trademarks.** Every proper noun is fictional. The boot-time content validator enforces this.

---

## 2. Player Experience Loop

```
[Hub] → Select Store → [In-Store] → Stock → Price → Serve Customers → Close Day → [Summary] → [Hub]
```

The loop must feel **closed and satisfying** at minimum scope: one store, one day, one sale. Each layer adds texture without requiring a previous layer to be "complete."

### Emotional arc of a day

- **Entry:** Anticipation. What did overnight market trends shift?
- **Stocking:** Agency. The player decides what to surface and at what price.
- **Customer sim:** Tension. Will this customer bite?
- **Close day:** Relief + curiosity. Revenue reveals, plus a nudge toward tomorrow.

---

## 3. Presentation Model: Management Hub

The mall is a **stylized clickable hub**, not a walkable world. This is a deliberate scoping decision documented in `docs/decisions/0001-mall-presentation-model.md`.

### Why management hub?

- **Legibility:** Hub cards surface per-store status instantly with no navigation overhead.
- **Scope containment:** Each store is a focused scene transition, not a spatial traversal. In-store logic stays isolated.
- **Playability risk reduction:** Walkable malls require input routing, collision, camera, and spatial legibility to all work simultaneously. The management hub defers all of that complexity to a later optional feature.

### Hub design rules

- Each store card shows: name, accent color, one-line status ("3 items unsold", "New customer waiting"), urgency indicator.
- The hub shows: day number, cash, reputation tier, next milestone progress.
- A single click enters a store. No approach animation required for 1.0.
- The hub is never a dead end — the objective rail always names the next action.

---

## 4. Visual Grammar

The visual system uses a strict constraint: **one dominant background, one panel tone, one accent, one highlight** per screen. Violating this rule produces the "brown soup" anti-pattern.

### Palette structure

| Token | Role |
|---|---|
| `world_base` | Page/world background |
| `panel_surface` | Default panel |
| `panel_raised` | Elevated widget/card |
| `text_primary` | Primary copy |
| `text_muted` | Secondary/metadata copy |
| `accent_interact` | Hover + interactable state |
| `accent_success` | Positive feedback |
| `accent_warning` | Caution state |
| `accent_danger` | Error/loss state |

Each store has one assigned accent color (5 total, distinct hues, AA contrast against `panel_surface`). That accent governs: hub card highlight, in-store header, shelf frame tint, and store-specific UI. No store's accent appears in another store's UI.

### Typography scale

| Token | Size | Use |
|---|---|---|
| `h1` | 32pt | Screen titles |
| `h2` | 24pt | Section headers |
| `body` | 18pt | Primary text |
| `caption` | 14pt | Secondary/metadata |

Minimum readable body text is 18pt. Nothing load-bearing lives at 14pt or below.

### Interactable states

Every interactable element must implement all five states:

1. **Idle** — resting appearance.
2. **Hover** — glow/outline using `accent_interact`.
3. **Active/Pressed** — shifted tone, immediate visual feedback.
4. **Disabled** — desaturated, no hover response.
5. **Warning** — `accent_warning` border or badge.

Silent click targets (hover state absent) are a merge-blocking bug.

---

## 5. The Objective Rail

The **ObjectiveRail** is a permanent bottom strip (64px tall, full width) visible on hub, in-store, and summary screens. It answers: *what should I do next?*

### Rail slots

| Slot | Content |
|---|---|
| `current_objective` | The active directive ("Stock 3 items on the shelf") |
| `next_action` | The immediate verb ("Open Inventory") |
| `input_hint` | Keyboard/mouse binding ("[E] / Click") |
| `optional_hint` | Secondary context — shown only when relevant |

### Rail rules

- Never empty. If no objective is active, show the first tutorial step.
- Advances with a 1-second flash animation.
- Does not block gameplay input — implemented as CanvasLayer with `mouse_filter = PASS`.
- Supersedes all corner-status-text. If information is load-bearing, it goes on the rail.

---

## 6. Store Design Principles

### Shelf & inventory

- 8 display slots per shelf (minimum viable for interesting decisions).
- Inventory drawer slides in from the left; it does not obscure shelf slots.
- Drag-from-inventory to shelf is the primary stocking action.
- Stocked items show: name, condition grade, suggested price range, current price.

### Price setter

- Shows minimum (floor), suggested range, and maximum (ceiling) for the item.
- Pricing above the ceiling reduces sale probability — this relationship is visible, not hidden.
- Visible margin hint updates live as the player adjusts price.
- No hidden math. The player should be able to predict a sale outcome from visible information alone.

### Customer simulation

- One customer at a time (Phase 4 minimum viable).
- Customer cycle: arrival → browse → decision (purchase or walk).
- Walk reasons are surfaced: "Price too high", "Condition concern", "Not what they wanted".
- Customers have archetype-driven logic. Recognizable behavior patterns emerge over repeated play; outcomes are not pure RNG.

### Day close

- Player-initiated deliberate action, not automatic.
- Preview before confirming: items still on shelf, estimated close revenue.
- Result: DaySummary scene with revenue, reputation delta, best-seller callout, one contextual tip.
- The tip sets up tomorrow's action — it does not recap yesterday.

---

## 7. Economy & Progression

### Price resolver multiplier chain

```
final_price = base_value × condition_mult × rarity_mult × trend_mult × reputation_mult × event_mult
```

Each multiplier is bounded and surfaced to the player. No opaque adjustments.

### Reputation tiers

| Tier | Threshold | Effect |
|---|---|---|
| Unknown | 0–25 | Reduced foot traffic, no special customers |
| Known | 26–50 | Normal traffic, occasional collectors |
| Reputable | 51–75 | Increased traffic, regular high-value buyers |
| Landmark | 76+ | Premium buyers, unlock-gated fixtures |

### Progression philosophy

- Milestones are **fixture/capacity unlocks**, not stat upgrades. More shelf slots > better sell-chance multiplier.
- Arc unlocks are **store expansions**: new item categories, new customer archetypes.
- Progression must always answer: "what will I be able to do tomorrow that I can't do today?"
- No dead weeks. Every 3-day window must contain at least one meaningful decision point or unlock.

---

## 8. Content Design

### Original IP mandate

All proper nouns are fictional:

- Console families: e.g., "Canopy 64", "Neo Spark", "PC Booster"
- Sports leagues and athletes: invented names, no real teams or players
- Store brands: invented mall tenants, no real franchise names

The boot-time content validator (`validate.yml`) enforces a banned-term regex. Content changes must not introduce false positives — changes to the regex must be tested against both hit cases and known-safe cases.

### Item data structure (minimum required fields)

```json
{
  "id": "item_canopy64_cartridge_starfall",
  "name": "Starfall (Canopy 64)",
  "category": "retro_games",
  "console": "canopy_64",
  "condition_grades": ["Loose", "CIB", "Sealed"],
  "rarity": "uncommon",
  "base_value": 18
}
```

Missing required fields halt boot with a `push_error` + `assert`. No `if data.has("price"):` silent fallbacks.

### Content extensibility rule

A designer must be able to add a new item, milestone, or objective by editing JSON only — no GDScript changes. Any mechanic that requires code-editing to add content is a design smell.

---

## 9. Interaction Audit

Before any feature that touches player interaction merges, run the interaction audit. Every row must PASS.

| Step | Pass Criteria |
|---|---|
| Game start | Hub visible within 3 seconds, objective rail populated |
| Store entry | Single click, <500ms transition, store scene loads correctly |
| Inventory open | Drawer slides in, items visible, no input eaten by UI |
| Shelf stock | Drag-and-drop works, slot fills, item removed from inventory |
| Price set | Price field editable, margin hint updates live |
| Customer arrive | Customer visible, browsing animation plays |
| Sale complete | Revenue tally updates, sale feedback visible |
| Walk (no sale) | Walk reason displayed to player |
| Day close | Summary scene loads, all stats correct |
| Return to hub | Hub reflects updated store status |
| Input at modal | Player movement blocked only when modal is active; AuditOverlay shows no false-freeze |

Any FAIL row blocks merge. FAIL rows require: named root cause + linked fix issue.

---

## 10. Anti-Patterns

| Anti-pattern | Description |
|---|---|
| Brown soup | Dark-brown-on-dark-brown panels. One dominant background, always. |
| Hidden interactables | Click targets with no hover state. Every interactable must glow. |
| Magic strings | Content IDs as scattered literals. Use typed constants or `StringName`. |
| Autoload sprawl | Adding a new autoload for convenience. Justify against plain Node. |
| Scope creep past the slice | Phase 4 code that presumes five stores. Build for one. |
| Silent fallbacks | `if data.has("price"):` instead of `assert`. Boot errors crash; runtime errors degrade. |
| Debug UI leaking | AuditOverlay or debug overlays visible in production builds. Toggle only, default off. |
| Input blockers | UI panels with `mouse_filter = STOP` that eat gameplay input without surfacing it. |

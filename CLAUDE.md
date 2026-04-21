```markdown
# CLAUDE.md — Mallcore Sim

Guide for AI coding assistants working in this repository. Read `docs/design.md` for the full design rationale — this file is the operational summary.

## 1. Project Identity
- **Name:** Mallcore Sim (`mall-sim`)
- **Engine:** Godot **4.6.2** (declared features: `4.6`, `Forward Plus`). Use the same engine version locally — do not upgrade casually.
- **Language:** GDScript only. No C#, no GDExtension additions without discussion.
- **Premise:** 2000s-era mall retail simulator. Management hub + specialty stores (retro games, pocket creatures, sports memorabilia, video rental, electronics).
- **Entry scene:** `res://game/scenes/bootstrap/boot.tscn`. Boot loads content → validates registry → loads `user://settings.cfg` → inits audio → opens main menu.
- **Source layout:**
  - `game/autoload/` — singletons (event_bus, content_registry, game_manager, etc.)
  - `game/scenes/` — one scene per screen; one responsibility per scene
  - `game/scripts/` — shared logic not attached to a specific scene
  - `game/content/` — JSON content (stores, items, milestones, unlocks)
  - `game/resources/` — `.tres` resources
  - `game/scenes/ui/`, `game/themes/`, `game/assets/` — presentation
  - `tests/` — GUT tests + shell validators
  - `docs/` — design + research docs (`docs/research/` has 50+ research notes; consult before designing new UI/systems)

## 2. Style
- **Line length:** ~100 cols soft limit; don't rewrap existing code just to fit.
- **Indentation:** tabs (Godot default). Do not mix.
- **Typing:** always use static types on function signatures, exports, and non-trivial locals. `func close_day(day: int) -> int:` not `func close_day(day):`.
- **Strings:** use `StringName` literals (`&"interact"`) for hot-path comparisons (signals, input actions, content IDs).
- **Signals:** past-tense phrases with typed params — `signal item_sold(store_id: StringName, item_id: StringName, price: int)`.
- **Comments:** default to none. Only explain non-obvious *why* (workaround, invariant, surprising constraint). Never narrate what code does.
- **Printing:** `push_error` / `push_warning` for diagnostics, not `print` in committed code.
- **Node lookups:** prefer exported `@onready var` references or `%UniqueName`; avoid long `$Path/To/Node` chains.

## 3. Naming
- **Files/dirs:** `snake_case.gd`, `snake_case.tscn`, `snake_case.json`. Directories plural for peers (`scenes/`, `components/`), singular for autoloads.
- **Classes (`class_name`):** `PascalCase`. Reserve for types referenced across scenes. Do **not** add `class_name` to one-off scene scripts or UI leaves — we've already hit collisions (`AuditOverlay`, `ObjectiveRail` are now anonymous on purpose).
- **Functions/vars:** `snake_case`. Private: `_leading_underscore`.
- **Constants:** `SCREAMING_SNAKE_CASE`.
- **Enums:** `PascalCase` type, `SCREAMING_SNAKE` members.
- **Nodes in scenes:** `PascalCase` matching role (`ShelfSlot`, `CustomerSpawner`).
- **Content IDs:** globally unique `snake_case` — `store_retro_games`, `item_pokemon_base_charizard`. Prefer typed constants over scattered magic strings.
- **Tests:** mirror source — `game/autoload/economy.gd` ↔ `tests/test_economy.gd` or `tests/unit/test_economy.gd`.

## 4. Testing
- **Framework:** [GUT](https://github.com/bitwes/Gut), vendored in `addons/gut/`. Extend `GutTest`.
- **Run all tests:**
  ```bash
  bash tests/run_tests.sh
  ```
  Resolves Godot from `$GODOT` / `$GODOT_EXECUTABLE` / `godot` on PATH / common macOS paths. Imports assets, runs GUT headless, runs `game/tests/run_tests.gd` if present, writes `tests/test_run.log`, then runs every `tests/validate_*.sh`.
- **What to test (required):**
  - Pure logic: `PriceResolver` multiplier chains, `ReputationSystem` thresholds, save migrations, content validators.
  - Integration: full sale loop, day-close, objective director advancement.
  - Content correctness: every store's referenced items resolve; no duplicate IDs; banned-term regex actually catches the patterns.
- **What not to test:** getters/setters, scene layout/anchors, Godot built-ins.
- **Manual audit:** automated tests don't certify feel. Every milestone passes the interaction audit in `docs/design.md §9` before shipping.
- **CI:** `.github/workflows/validate.yml` runs GUT + content validator + banned-terms regex. Red build blocks merge. `export.yml` builds release artifacts on tags.

## 5. Dependencies
- **Allowed:**
  - Godot 4.6.2 built-ins.
  - GUT (already vendored at `addons/gut/`).
- **Adding new addons:** requires discussion. Must be vendored under `addons/`, MIT/BSD/MPL-compatible with our LICENSE, and justified against "can we do this with built-ins?" Prefer writing the 20 lines of GDScript.
- **Banned:**
  - No network dependencies at runtime. The game is offline.
  - No trademarked terms in content or code — `validate.yml` runs a banned-terms regex (Nintendo platforms, Nike, etc.). If you're adding retro content, invent fictional analogues. Update `validate.yml` patterns carefully; we've regressed on false positives before.
- **Content, not code:** new stores/items/milestones are JSON in `game/content/`, not new scripts. A designer must be able to add content without touching GDScript.

## 6. Git
- **Branch:** work off `main`. Feature branches `feature/<short-slug>`, fixes `fix/<short-slug>`.
- **Commits:** imperative, descriptive first line. Recent history uses natural sentences (`Update reputation thresholds in reputation_system.gd ...`) — match that. No strict Conventional Commits prefix required, but scope + reason in the body is appreciated for non-trivial changes.
- **Never commit:**
  - `.godot/` (import cache)
  - `user://` equivalents, save files, `exports/` artifacts unless a release step requires it
  - Secrets or signing material
- **PRs:**
  - Must pass `validate.yml` (GUT + content validator + banned terms).
  - Include a short "what/why" and, for gameplay-affecting changes, a note on which interaction-audit items were re-checked.
  - Keep PRs scoped. Don't bundle refactors with feature work.

## 7. Dev Setup
1. Install **Godot 4.6.2** (standard editor build — matches CI).
2. Clone and open `project.godot` in the editor; let it finish importing assets.
3. Run with **F5** (entry scene is preconfigured).
4. Run tests from repo root: `bash tests/run_tests.sh`.
5. Optional: set `GODOT` env var to your Godot binary path for consistent scripting.
6. Export presets live in `export_presets.cfg` (Windows / macOS / Linux). Local artifacts go to `exports/<platform>/`.

## 8. Important Rules
These are project-specific and override generic instincts.

1. **Legibility before depth.** If a screen doesn't answer "what can I do right now?" in under 3 seconds, the screen is wrong. Don't add systems behind invisible UI.
2. **Vertical slice first.** One store, one sale loop, one day close — closed and satisfying — before broadening. Do not add generality for stores #2+ until #1 ships. Code that presumes multiple stores must not exist before two are playable.
3. **Management hub, not walkable world.** The mall is a stylized clickable hub. Player-controller movement, collision, and interact volumes belong only in explicitly feature-flagged walkable scenes.
4. **Content is data.** Stores/items/milestones/customers are JSON under `game/content/`, loaded and **validated at boot** by `ContentRegistry`. Missing required fields must crash boot with a clear `assert`/`push_error` message — never `if data.has("price"):` as a silent fallback.
5. **Signals over polling, autoloads sparingly.** Cross-system comms go through `EventBus` with typed signals. The autoload list in `project.godot` is already large — justify any new autoload against "could this be a plain Node or component?"
6. **`class_name` is opt-in, not reflex.** Only add `class_name` for types referenced across scenes. We've had collisions; anonymous scene scripts are preferred for one-offs.
7. **No trademarks.** All retro references are fictionalized (`pc_booster_canopy`, `pc_booster_neo_spark`). `validate.yml` enforces this — if you change its regexes, verify both hits and false-positives.
8. **Runtime gameplay errors degrade, boot errors crash.** A customer who can't resolve a price leaves the store (log + recover). A missing content field at boot aborts loudly.
9. **Saves are versioned.** Every save carries `version: int`. Add a migration, don't mutate old loaders. Back up to `user://backups/` before destructive migration steps.
10. **Anti-pattern watchlist:** brown-on-brown UI, debug overlays leaking into player view, hidden `_unhandled_input` blockers, magic strings for content IDs, autoload sprawl, scope creep past the slice.
11. **Research before design.** `docs/research/` contains 50+ notes (onboarding, drawer panels, objective rails, focus/input conflicts, palette, visual hierarchy). Before proposing UI or interaction changes, grep `docs/research/` for prior analysis.
12. **Match engine version.** Local runs and tests must use Godot 4.6.2. Do not bump engine version to work around a bug without raising it first.
```
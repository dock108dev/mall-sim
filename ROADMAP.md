# Mallcore Sim — Roadmap

Delivery is phased; each phase is a set of issues that can be opened verbatim. Phases 0–5 are the critical path to a shippable vertical slice. Phases 6–12 scale the slice into a full game.

---

## Phase 0 — Interaction Audit

Goal: prove or disprove the playable loop from cold boot to day-close using automatable checkpoints.

- [ ] Add `AuditOverlay` debug autoload (disabled in release). Exposes `pass_check/fail_check` and prints `[AUDIT] <key>: PASS|FAIL` to stdout.
- [ ] Instrument five checkpoints: `player_spawned`, `player_moved`, `trigger_reached`, `store_entered`, `transaction_completed`.
- [ ] Add `debug_add_item(dict)` and `debug_spawn_customer(dict)` on every store controller.
- [ ] Write headless audit runner (`tests/audit_run.sh`) that launches the boot scene, steps physics, and parses `[AUDIT]` lines into a PASS/FAIL table.
- [ ] CI job fails if any checkpoint fails.
- [ ] Deliverable: a markdown table in `docs/audits/` regenerated on every run.

## Phase 1 — Hub vs. Walkable Decision (lock it in)

Decision rule from research: mechanics are menu-native (refurb, pack opening, grading, warranty, late fees). Commit to **clickable management hub with ambient walkable flavor**. Mall Tycoon 2002 pattern.

- [ ] Replace/confirm `res://game/scenes/mall/mall_hub.tscn` as the concourse diorama.
- [ ] Each store frontage is a `StorefrontCard` (Area2D + sub-viewport) that emits `storefront_clicked(store_id)`.
- [ ] Clicking a card opens a side `DrawerHost` (`PanelContainer`) with the store's mechanic UI, not a scene change.
- [ ] Ambient customer sprites pathfind the concourse; removing the node must not break any mechanic.
- [ ] No player avatar. Delete any dangling `player.tscn` + controller references.
- [ ] Archive old walkable-world scenes under `docs/archive/`.

## Phase 2 — Visual Grammar Reset

Goal: everything readable at 1080p, colorblind-safe, consistent.

- [ ] Implement the four-layer palette as `Theme` resources (World / Surface / Store-accent / Semantic). Source values from `docs/research/sim-game-visual-hierarchy-palette.md`.
- [ ] Two panel tiers: **dark panel** for running state (HUD, ticker), **light panel** for decisions (dialogs, day summary).
- [ ] Typography: rounded bold sans for UI, condensed gothic for counters, `+80` tracking minimum on labels.
- [ ] Every semantic state carries a shape/icon (✓ ! ✕ ◆) in addition to color.
- [ ] Accent budget audit: store-identity + alert pixels ≤10 % of screen. Add a dev-overlay that samples and reports.
- [ ] Shared `ActionDrawer.tscn` replaces any per-store drawer duplication.

## Phase 3 — Persistent Objective Rail

- [ ] `ObjectiveStrip` as `CanvasLayer` autoload, layer 10, anchored top-right.
- [ ] Three slots only: OBJECTIVE / NEXT ACTION / KEY HINT.
- [ ] Content lives in `game/content/objectives.json`; no hardcoded strings in GDScript.
- [ ] `ObjectiveDirector` listens to `day_started`, `store_entered`, `item_stocked`, `first_sale_completed` and emits `EventBus.objective_changed(payload)`.
- [ ] Auto-hides after day 3 once one full loop completes. Setting toggle to re-enable.
- [ ] Survives scene transitions (autoload, not per-scene).

## Phase 4 — Retro Games Vertical Slice (Gate)

**Nothing else starts until this is undeniable.** The research names **pack opening (Pocket Creatures)** as the 60-second golden path, but Retro Games is our declared anchor store. Resolve the tension in one issue (#4-0) before implementing.

- [ ] #4-0 Decide: is the 60-second golden path Retro Games refurbishment, or Pocket Creatures pack opening? Document the call in `docs/decisions/`.
- [ ] One storefront card wired to one drawer.
- [ ] Three shelf slots with three seeded items (original names, no trademarked cartridge titles).
- [ ] Refurb tiers: `Clean → Repair → Restore`, each a single click with an animated condition bump.
- [ ] One customer archetype ("Nostalgic Parent") spawns, asks "How much?", accepts two price tiers.
- [ ] `CheckoutSystem` processes sale → emits `item_sold` with full `PriceBreakdown`.
- [ ] Day ends → `DaySummary` modal shows: revenue, best sale, one forward hook.
- [ ] GUT integration test: boot → drawer open → refurb → sale → `day_closed`. Full signal chain asserted.

## Phase 5 — Day 1–7 Progression

- [ ] `ProgressionSystem` consumes `milestone_reached` and emits `UnlockSystem.unlock(id)`.
- [ ] Seven scripted days with milestone gates (first sale, first refurb, first rare pull, first haggle, reputation 25, revenue target, second store unlock).
- [ ] `RandomEventSystem` wakes on day 3; telegraphs next-day events in the HUD ticker 12 in-game hours in advance.
- [ ] `ReputationSystemSingleton` feeds PriceResolver reputation multiplier.
- [ ] `DaySummaryPanel` always names one "story beat" even on zero-revenue days (tie to `AmbientMomentsSystem`).

## Phase 6 — Pocket Creatures

Implement full signature mechanic: pack opening + meta shifts + tournaments.

- [ ] 11 original creatures in `pocket_creatures_cards.json` — no trademarked species, types, or art references. Names invented.
- [ ] Pack opening animation: foil-tear SFX, 6–10 face-down flips, rarity-weighted chime on reveal.
- [ ] Pull table: 60 / 30 / 9 / 1 / <1 (Common → Secret).
- [ ] `MetaShiftSystem` rotates "hot" creature every N days; feeds PriceResolver `meta_shift` multiplier.
- [ ] `TournamentSystem` runs weekly; winners drive trend spikes.
- [ ] Deterministic RNG: `hash(pack_id + tick)`.

## Phase 7 — Video Rental

- [ ] Item schema: `release_date`, `rarity` (common / new / ultra_new), `base_rental_fee`, `late_fee_per_day`.
- [ ] New-release premium window: 0–7 days ultra_new, 7–21 days new, then common.
- [ ] Overdue tracker emits `rental_overdue(customer_id, item_id)`; late fees post to ledger at day close.
- [ ] Ten original made-up titles per genre; no real film titles or studio names.

## Phase 8 — Electronics + Sports Cards

- [ ] **Electronics** — warranty upsell prompt on sale (`none / basic_1yr / premium_2yr`), demo unit on floor increases footfall multiplier.
- [ ] **Sports Cards** — promote the binary authenticator to a multi-tier grading mechanic (PSA-style 1–10 scale with population count). If scope-cut, defer with a written decision doc and ship with a clearly-labeled "authentication only" mode.
- [ ] Per-store content: original players, teams, franchises. No real leagues or likenesses.

## Phase 9 — Cross-Store Economy + 30-Day Arc

- [ ] Cross-store trend propagation: a trend on one category lifts related categories (retro games ↔ sports cards "vintage" shelf).
- [ ] 30-day main arc with monthly rent, quarterly lease review, and an ending evaluator choosing from 5+ endings based on final stats.
- [ ] `EndingEvaluator` reads persisted stats and emits `ending_selected(id)`; content in `game/content/endings/`.

## Phase 10 — Ambient + Narrative Layer

Optional depth; passive players must have a complete game without it.

- [ ] Seven customer archetypes (Browser, Haggler, Nostalgic Parent, Collector Kid, Teenager, Power Walker, Sample Grazer).
- [ ] Six recurring minor characters (all original names + backstories).
- [ ] Four secret threads, each with three-layer reveal (Surface / Signal / Substrate), each with a non-resolution path.
- [ ] `AmbientMomentsSystem` rotates slice-of-life vignettes in the HUD ticker.
- [ ] Every thread revelation preceded by ≥2 observable signals (fairness rule).

## Phase 11 — Audio + Visual Polish

- [ ] Per-store music stems in `audio_registry.json`; `AudioManager` crossfades on drawer open.
- [ ] Mall ambience bed: food court murmur, escalator hum, HVAC low end.
- [ ] Particle polish on rare pulls, condition jumps, warranty acceptance.
- [ ] CRT/retro shader (see `docs/research/crt-retro-ui-godot-shader.md`) applied only to the Retro Games drawer.

## Phase 12 — CI, Testing, Export, Ship

- [ ] Pinned Godot 4.6.2 in both `.github/workflows/validate.yml` and `export.yml`.
- [ ] GUT content-integrity suite green on `main`.
- [ ] Save migration chain unit tests for every version bump.
- [ ] Interaction-audit table archived per-commit.
- [ ] Export presets: Windows, macOS, Linux. Itch.io upload job.
- [ ] Content-originality audit: grep for trademarked terms (Pokémon, Nintendo, Blockbuster, PSA, ESPN, etc.); fail CI on any hit.

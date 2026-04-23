# Decision 0006: Pocket Creatures — Delete Trade System Scaffolding

**Date:** 2026-04-23
**Status:** Accepted
**Related:** ISSUE-009 (this ADR), ISSUE-030 (follow-on deletion), ADR 0003 /
ADR 0004 / ADR 0005 (parallel Phase 0 kill-or-commit decisions),
`docs/roadmap.md` Phase 0 exit criteria

## Decision

**Delete (Option B)** the Pocket Creatures trade system scaffolding. The trade
feature was already largely removed during earlier Phase 0 triage — the
`TradeSystem`, `TradeFlowController`, `TradeOfferDisplay`, `TradeValuationDisplay`,
and `test_trade_system` sources are gone (orphan `.uid` files remain), and
`SaveManager._migrate_v1_to_v2` already erases the `trade` root key as
obsolete. What remains is a disconnected `TradePanel` scene + script, two
locale strings, and an uncalled controller seam. This ADR finishes the cut.

Option A (wire trade into `game_world.gd` with NPC trade offers, a trade-value
model, and a fair-trade UI) is rejected because the supporting code no longer
exists, Pocket Creatures already ships a complete loop (packs, tournaments,
meta shifts), and rebuilding trade from a 256-line shell would add a parallel
partial loop in direct violation of the "one complete loop before five
partial ones" non-negotiable.

## Context

ISSUE-009 framed the trade system as "scaffolded but not wired into
`game_world.gd`." A walk of the current code shows the scaffolding is
substantially thinner than that framing suggests — most of it has already
been removed.

| Surface | File | State |
|---|---|---|
| Controller | `game/scripts/stores/pocket_creatures_store_controller.gd` (326 LOC) | Zero trade methods. Ships pack opening, tournament hosting, meta-shift pricing, and seasonal event hooks. `get_store_actions()` exposes `open_pack` and `host_tournament` only — no `trade` action. |
| Trade UI | `game/scenes/ui/trade_panel.tscn` (104 LOC) + `game/scripts/ui/trade_panel.gd` (152 LOC) | Self-contained modal. `show_trade(wanted, offered, …)` and local `trade_accepted` / `trade_declined` signals. No caller anywhere in the repo. Not instantiated by `GameWorld._setup_ui` or `_setup_deferred_panels`. |
| Trade system | `game/scripts/systems/trade_system.gd` | **Deleted.** Only the orphan `.uid` file survives. |
| Trade flow controller | `game/scripts/ui/trade_flow_controller.gd` | **Deleted.** Orphan `.uid` only. |
| Trade offer display | `game/scripts/ui/trade_offer_display.gd` | **Deleted.** Orphan `.uid` only. |
| Trade valuation display | `game/scripts/ui/trade_valuation_display.gd` | **Deleted.** Orphan `.uid` only. |
| Trade tests | `game/tests/test_trade_system.gd` | **Deleted.** Orphan `.uid` only. |
| EventBus signals | `game/autoload/event_bus.gd` | Zero `trade_*` signals. `TradePanel`'s `trade_accepted` / `trade_declined` are local panel signals with no subscribers. |
| Save persistence | `game/scripts/core/save_manager.gd:925–938` | `_migrate_v1_to_v2` explicitly lists `"trade"` in `OBSOLETE_ROOT_KEYS` — the Phase 0 removal is already baked into the save schema. |
| Content data | `game/content/items/pocket_creatures.json`, `game/content/stores/pocket_creatures/creatures.json`, `store_definitions.json`, `tutorial_contexts.json` | Zero trade data fields. Matches are flavor text only ("trade-table demand", "trade negotiations"). |
| Localization | `game/assets/localization/translations.en.csv:138–139` + `.es.csv:138–139` | Two orphan rows: `TRADE_CONDITION`, `TRADE_VALUE`. Referenced only by a `tr()` marker comment in `trade_panel.gd:46`. |

Pocket Creatures' shipping loop runs end-to-end without trade:

- `open_pack` / `open_pack_with_cards` → `PackOpeningSystem` → `EventBus.items_revealed`.
- `host_small_tournament` / `host_large_tournament` → `TournamentSystem` → `EventBus.tournament_resolved`.
- `resolve_card_price` → `PriceResolver` with `meta_shift` and seasonal `tournament_price_spike_multiplier` slots.
- Starter inventory seeded on `store_entered`; sealed-pack counting on `inventory_item_added`; save/load of `_pack_inventory_count`.

## Rationale

**The code to wire doesn't exist.** Option A would require re-authoring
`TradeSystem` (offer generation, valuation, acceptance), `TradeFlowController`
(NPC pacing, queue integration), `TradeOfferDisplay` / `TradeValuationDisplay`
(richer UI surfaces than the shell panel), trade `EventBus` signals, save/load
persistence, objective-rail integration, and the interactable that opens the
panel. The 256 LOC that survive are a disconnected UI shell — not a
scaffolding that can be "wired in."

**Pocket Creatures already has one complete loop.** Per `docs/design.md`
§"One complete loop before five partial ones": the store's signature loop is
buy packs → open → grade meta → host tournaments → recycle into pricing via
`MetaShiftSystem` + seasonal `tournament_price_spike_multiplier`. That loop
runs end-to-end in the controller, has save/load coverage, and has named
audit-checkpoint candidates. Adding a parallel partial trade loop would
fragment attention and duplicate the "sell card to NPC" surface that
`CheckoutSystem` already resolves.

**Save schema has already moved on.** `_migrate_v1_to_v2` marks the `trade`
root key as an obsolete Phase 0 removal. Reintroducing a trade save block
would require a new save version and undo a migration the rest of the
codebase trusts.

**Parallel with ADR 0003 / ADR 0004 / ADR 0005 but opposite verdict.** Those
three ADRs found large controllers (766 / 533 / 589 LOC), real scenes,
populated catalogs, and zero stubbed core verbs — evidence of an end-to-end
mechanic near the finish line. Trade presents the opposite pattern: zero
controller methods, zero catalog fields, deleted system/flow/display scripts,
an already-migrated save schema, and a dangling UI shell. Same kill-or-commit
discipline, opposite evidence, opposite verdict.

**Non-negotiable alignment.** Per `docs/design.md` §"Content is data,"
deleting the trade shell does not remove any data-driven content — the JSON
catalogs have no trade fields. Per §"Management hub, not walkable world," the
disconnected panel was never reachable through the hub anyway.

## Consequences

- **ISSUE-030** is filed to execute the deletion and leave the tree tidy:
  - Delete `game/scripts/ui/trade_panel.gd` and its `.uid`.
  - Delete `game/scenes/ui/trade_panel.tscn` (and any `.uid` if present).
  - Delete orphan `.uid` files for the already-removed scripts:
    `game/scripts/systems/trade_system.gd.uid`,
    `game/scripts/ui/trade_flow_controller.gd.uid`,
    `game/scripts/ui/trade_offer_display.gd.uid`,
    `game/scripts/ui/trade_valuation_display.gd.uid`,
    `game/tests/test_trade_system.gd.uid`.
  - Remove the `TRADE_CONDITION` and `TRADE_VALUE` rows from both
    `translations.en.csv` and `translations.es.csv`.
  - Verify no remaining references via grep (`trade_panel`, `TradePanel`,
    `show_trade`, `trade_accepted`, `trade_declined`, `TRADE_CONDITION`,
    `TRADE_VALUE`); only the existing flavor-text matches in catalogs and
    the `SaveManager` migration comment / `OBSOLETE_ROOT_KEYS` entry should
    remain.
  - Update `docs/roadmap.md` Phase 0 line "Pocket Creatures: finish or delete
    the trade system" and the Phase 1 prerequisite "Pocket Creatures trade
    system wired into `game_world.gd` if kept from Phase 0" to reflect the
    cut.
- Per the ISSUE-009 acceptance criterion, after ISSUE-030 ships no
  trade-related symbols will remain in the Pocket Creatures controller or
  content JSON. Today's audit already finds none in the controller; ISSUE-030
  removes the UI shell and orphan `.uid` / locale rows.
- `SaveManager._migrate_v1_to_v2`'s `OBSOLETE_ROOT_KEYS = ["trade"]` entry is
  **retained** — it is load-bearing for old saves on disk. The comment is
  updated to cite this ADR.
- Store count for shipping remains six. `store_definitions.json` does not
  change; Pocket Creatures' store entry has no trade fields to remove.
- No trademarks: deletion removes no parody-name content. The "Pocket
  Creatures" parody name is preserved.
- If a later phase wants a trade-in or player-to-NPC offer mechanic, it
  should be reintroduced as a new feature against the then-current
  architecture (single-owner autoloads per `docs/architecture/ownership.md`,
  EventBus signal catalog) rather than resurrected from the deleted shell.

# State Assessment — Mallcore Sim

Date: 2026-04-19

This is a raw, unsanitized pass through the repository to assess what is
actually working, what is scaffolded but not player-facing, and where trust
breaks. Written to inform the finalization roadmap, not as ongoing how-to
documentation.

---

## What this app actually is right now

A 2000s-mall retail sim in Godot 4.x, 5 stores, driven by a signal bus and a
stack of autoloads, fed by JSON content at boot. Strip the branding and the
secret narrative scaffolding off and the core loop is:

- stand in a store, stock shelves, price items, sell to AI customers, haggle
  sometimes, close the day, read a day summary, repeat
- at some cadence you unlock new stores, upgrades, fixtures, staff
- at some cadence market/seasonal/random events nudge prices
- eventually you hit an ending condition and get a little credits sequence

That's the *real* game. Pricing + inventory + checkout + customer flow + day
cycle + a modest progression curtain — that's what's actually hooked up
end-to-end and working. Everything else orbits it at varying distances and
varying levels of truth.

On top of that core there are five store "flavors" that all reach for a
signature mechanic. Only some of them land. And there's a whole second layer
above the mechanics — ambient moments, secret threads, completion tracker,
ending evaluator, meta shifts, performance reporting — that is clearly reaching
for something bigger and mostly reaches into empty air from the player's POV.

The AIDLC harness in `.aidlc/` is doing a ton of heavy lifting on the meta
side — 500+ planned issues, ~120 implemented, 0 verified, 5 failed, and
autosync commits every 10 cycles. This isn't just a game. This is also a case
study in loop-driven development where the loop has been outpacing finishing
work.

## What it is trying to be

Trying to be three things at once:

1. A deep retail sim where each of the five storefronts has a real,
   store-specific signature loop (authenticate, refurbish, rent+return, open
   packs + tournaments + meta, electronics lifecycle + warranty).
2. A nostalgia / vibe / narrative piece with ambient moments, secret threads,
   multiple distinct endings, performance reporting, a completion meta-layer.
3. A polished single-player indie game you hand someone and they just... play.

Right now it is closest to #1, middling on #3, and #2 is almost entirely
backend with no player-facing surface.

## What feels real

- **Pricing, checkout, haggle, inventory** — this is the spine. Works.
  `checkout_system.gd` + `haggle_system.gd` + `inventory_system.gd` are
  coherent, tested, and genuinely wired through EventBus.
- **Day cycle / time phases / customer spawning** — phases (PRE_OPEN →
  MORNING_RAMP → MIDDAY_RUSH → AFTERNOON → EVENING) are real, spawn pressure
  moves with them, day summary closes it out. Good backbone.
- **Retro games refurbishment** — the most honest store mechanic in the build.
  Real queue, real time-to-repair, real parts cost, real inventory-location
  state during refurb, UI panels, save/load support. `refurbishment_system.gd`
  is the reference standard for what "signature store mechanic" should feel like
  here.
- **Pocket Creatures pack opening + meta shifts + tournaments** —
  `pack_opening_system` and `meta_shift_system` actually change prices, actually
  telegraph shifts two days out, actually integrate into market value.
  Tournaments are wired. This store is probably the richest.
- **Reputation tiers** — 4 tiers, real budget multipliers, real customer volume
  effects, decay floor at 50. This is doing real work.
- **Progression unlocks** — day/revenue/rep thresholds unlock new stores and
  surfaces. Clean and coherent.
- **Build mode** — place/rotate/remove fixtures, pay costs, save per-store.
  Scope-appropriate and actually works.
- **Save/load across 20+ systems** — fully serialized, validation pass after
  load. Good.
- **5-tier init order in `game_world.gd`** — the init dependency graph is real
  and commented. One of the strongest architectural points in the repo.

## What feels fake-done

These have panels, classes, JSON, commits, and test files, but do not actually
deliver a player experience.

- **Video rental.** `video_rental.gd::rent_item()` returns false.
  `_check_overdue_rentals()` and `_process_daily_returns()` are empty. Stub
  comments pointing at ISSUE-057/058. A whole store "flavor" is not a store
  flavor yet. `tape_wear_tracker.gd` exists waiting for a rental flow to tick.
- **Warranty for electronics.** `warranty_manager.gd` has fee math, acceptance
  probability, daily claim processing. There is a `warranty_dialog.tscn` in
  `game/scenes/ui/`. Nothing instantiates it in the deferred panel setup. The
  checkout system references a warranty dialog that is never set. System built,
  UI never attached.
- **Electronics demo units.** `ElectronicsStoreController` manages the list,
  but the scene-side `electronics.gd::designate_demo()` returns false and
  `get_demo_browse_bonus()` returns 0. Acknowledged stub. No way for the player
  to actually flag a demo unit.
- **Sports authentication depth.** Dialog shows, flag flips, multiplier applies.
  That's it. It's a binary yes/no. `_get_season_modifier()` returns 1.0 and is
  explicitly stubbed. The sports store mechanic is a dialog, not a mechanic.
- **Trade system (pocket creatures).** `trade_system.gd` exists, has an
  initializer, has a panel. Nothing in `game_world.gd` calls
  `initialize_trade_system()`. Dead code path. Player never sees it.
- **Secret threads.** `secret_thread_manager.gd` + `secret_thread_state.gd` +
  `secret_thread_system.gd` with a 7-phase progression model (DORMANT →
  WATCHING → ACTIVE → REVEALED → RESOLVED). JSON defines threads like
  `the_regular`, `the_skeptic_critic`, `ghost_tenant`, `mall_legend_threads`.
  Zero UI surface. No thread log, no progression view, no cue beyond some
  notifications. Ambitious narrative layer that the player has no way to
  participate in.
- **Ambient moments.** Loads `ambient_moments.json` (2 definitions), queues up
  to 3, delivers as transient notifications. That's it. No log, no timeline, no
  "moments you've witnessed" screen, no recall. A flavor system with no flavor
  surface.
- **Completion tracker.** 14 criteria, emits `all_milestones_completed` when
  full, feeds ending eval. No first-class player surface showing "you're at
  X/14." It's an endgame trigger dressed up as a feature.
- **Performance report system.** Generates structured end-of-day data. Surfaces
  a day summary. Does not meaningfully influence later decisions — no trends
  over days, no per-store week-over-week view, no "your best day" surface.
- **Milestone UI triplication.** `milestone_popup` + `milestone_banner` +
  `milestones_panel` — three components for the same idea. Unclear which is
  canonical. Reads like iterations stacked rather than replaced.
- **Duplicate store controllers.** For every store there's a `<store>.gd` plus
  `<store>_store_controller.gd`, and for electronics also
  `electronics_lifecycle_manager.gd`. `game_world.gd` wires the controllers,
  the scene-sided `.gd` files are in varying states of hollow. Legacy refactor
  residue.

## Data and content concerns

- **Content type detection has four fallback layers** — dict `type`, events-dir
  special case, directory-name heuristic, file-basename heuristic. A new file in
  the wrong directory will be silently classified wrong. Should require explicit
  `type` field; reject at boot instead of heuristic-rescuing.
- **Cross-reference validation gaps.** `validate_all_references()` checks item
  store_type, store starting_inventory, and scene paths. It does not check:
  market event target IDs, seasonal event category tags, trend category tags,
  supplier catalog references, milestone trigger IDs, secret thread precondition
  IDs, ending stat references.
- **Economy math scatter.** Price multipliers come from: difficulty, reputation
  tier, trend, market event, seasonal event, random event, meta shift, sports
  season boost, condition, warranty, authentication, lifecycle phase. Different
  systems read different multiplier inputs. Wants a single `PriceResolver` with
  a trace of which multipliers applied.
- **Save versioning policy.** Save version is `1`. Migrations are chained but
  the policy for when to bump, what to refuse, and what is forward-only is not
  formalized.

## What I would push hard next

In priority order:

1. **Decide the fate of scaffolded systems** — finish or cut video rental,
   warranty, demo units, trade system, secret threads UI, ambient moments UI.
2. **Mall overview screen.** Per-store cards. Event feed. This is what turns
   five stores from five separate games into a mall.
3. **Single PriceResolver with trace.** Every multiplier goes through one path.
   Tooltip exposes the trace.
4. **UI texture pass.** Push 2000s mall feel into chrome, typography, and HUD.
5. **Unified in-store action drawer.** One shape for haggle, refurb,
   authenticate, warranty, trade.
6. **Content contract validation at boot.** Require `type` field. Validate every
   cross-reference.
7. **Consolidate duplicate controllers and content paths.**
8. **Collapse milestone UI to one component.**
9. **Shore up content volumes.** More ambient moments, more threads with payoffs,
   more seasonal variety.
10. **Run AIDLC in finish mode, not feature mode.** Cap new issues. Burn down the
    unverified backlog.

## North star

A 2000s specialty-retail mall that feels alive, fair, and specific. Five stores,
each with one signature mechanic that matters and is legible. One mall overview
that makes running five stores feel like a single business. One coherent visual
period texture. One honest price model you can trace. One narrative layer —
whichever layer — that the player can actually see. Nothing bolted on. Nothing
invisible. Nothing stubbed.

Finish 1.0. Then talk about 2.0.

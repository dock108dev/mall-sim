# BRIANDUMP — Mallcore Sim

Dumping after a hard pass through the repo. Not prettifying this. Not hedging.

---

## What this app actually is right now

A 2000s-mall retail sim in Godot 4.x, 5 stores, driven by a signal bus and a stack of autoloads, fed by JSON content at boot. Strip the branding and the secret narrative scaffolding off and the core loop is:

- stand in a store, stock shelves, price items, sell to AI customers, haggle sometimes, close the day, read a day summary, repeat
- at some cadence you unlock new stores, upgrades, fixtures, staff
- at some cadence market/seasonal/random events nudge prices
- eventually you hit an ending condition and get a little credits sequence

That's the *real* game. Pricing + inventory + checkout + customer flow + day cycle + a modest progression curtain — that's what's actually hooked up end-to-end and working. Everything else orbits it at varying distances and varying levels of truth.

On top of that core there are five store "flavors" that all reach for a signature mechanic. Only some of them land. And there's a whole second layer above the mechanics — ambient moments, secret threads, completion tracker, ending evaluator, meta shifts, performance reporting — that is clearly reaching for something bigger and mostly reaches into empty air from the player's POV.

The AIDLC harness in `.aidlc/` is doing a ton of heavy lifting on the meta side — 500+ planned issues, ~120 implemented, 0 verified, 5 failed, and autosync commits every 10 cycles. This isn't just a game. This is also a case study in loop-driven development where the loop has been outpacing finishing work.

## What it is trying to be

Trying to be three things at once:

1. A deep retail sim where each of the five storefronts has a real, store-specific signature loop (authenticate, refurbish, rent+return, open packs + tournaments + meta, electronics lifecycle + warranty).
2. A nostalgia / vibe / narrative piece with ambient moments, secret threads, multiple distinct endings, performance reporting, a completion meta-layer.
3. A polished single-player indie game you hand someone and they just... play.

Right now it is closest to #1, middling on #3, and #2 is almost entirely backend with no player-facing surface.

## What feels real

- **Pricing, checkout, haggle, inventory** — this is the spine. Works. `checkout_system.gd` + `haggle_system.gd` + `inventory_system.gd` are coherent, tested, and genuinely wired through EventBus.
- **Day cycle / time phases / customer spawning** — phases (PRE_OPEN → MORNING_RAMP → MIDDAY_RUSH → AFTERNOON → EVENING) are real, spawn pressure moves with them, day summary closes it out. Good backbone.
- **Retro games refurbishment** — the most honest store mechanic in the build. Real queue, real time-to-repair, real parts cost, real inventory-location state during refurb, UI panels, save/load support. `refurbishment_system.gd` is the reference standard for what "signature store mechanic" should feel like here.
- **Pocket creatures pack opening + meta shifts + tournaments** — pack_opening_system and meta_shift_system actually change prices, actually telegraph shifts two days out, actually integrate into market value. Tournaments are wired. This store is probably the richest.
- **Reputation tiers** — 4 tiers, real budget multipliers, real customer volume effects, decay floor at 50. This is doing real work.
- **Progression unlocks** — day/revenue/rep thresholds unlock new stores and surfaces. Clean and coherent.
- **Build mode** — place/rotate/remove fixtures, pay costs, save per-store. Scope-appropriate and actually works.
- **Save/load across 20+ systems** — fully serialized, validation pass after load. Good.
- **5-tier init order in `game_world.gd`** — the init dependency graph is real and commented. One of the strongest architectural points in the repo.

## What feels fake-done

This is the list that matters. These have panels, classes, JSON, commits, and test files, but do not actually deliver a player experience.

- **Video rental.** `video_rental.gd::rent_item()` returns false. `_check_overdue_rentals()` and `_process_daily_returns()` are empty. Stub comments pointing at ISSUE-057/058. A whole store "flavor" is not a store flavor yet. `tape_wear_tracker.gd` exists waiting for a rental flow to tick.
- **Warranty for electronics.** `warranty_manager.gd` has fee math, acceptance probability, daily claim processing. There is a `warranty_dialog.tscn` sitting in `game/scenes/ui/`. Nothing instantiates it in the deferred panel setup. The checkout system references a warranty dialog that is never set. System built, UI never attached.
- **Electronics demo units.** `ElectronicsStoreController` manages the list, but the scene-side `electronics.gd::designate_demo()` returns false and `get_demo_browse_bonus()` returns 0. Acknowledged stub. No way for the player to actually flag a demo unit.
- **Sports authentication depth.** Dialog shows, flag flips, multiplier applies. That's it. It's a binary yes/no. `_get_season_modifier()` returns 1.0 and is explicitly stubbed. The sports store mechanic is a dialog, not a mechanic.
- **Trade system (pocket creatures).** `trade_system.gd` exists, has an initializer, has a panel. Nothing in `game_world.gd` calls `initialize_trade_system()`. Dead code path. Player never sees it.
- **Secret threads.** `secret_thread_manager.gd` + `secret_thread_state.gd` + `secret_thread_system.gd` with a 7-phase progression model (DORMANT → WATCHING → ACTIVE → REVEALED → RESOLVED). JSON defines threads like `the_regular`, `the_skeptic_critic`, `ghost_tenant`, `mall_legend_threads`. Zero UI surface. No thread log, no progression view, no cue beyond some notifications. Ambitious narrative layer that the player has no way to participate in.
- **Ambient moments.** Loads `ambient_moments.json` (2 definitions), queues up to 3, delivers as transient notifications. That's it. No log, no timeline, no "moments you've witnessed" screen, no recall. A flavor system with no flavor surface.
- **Completion tracker.** 14 criteria, emits `all_milestones_completed` when full, feeds ending eval. No first-class player surface showing "you're at X/14." It's an endgame trigger dressed up as a feature.
- **Performance report system.** Generates structured end-of-day data. Surfaces a day summary. Does not meaningfully influence later decisions — no trends over days, no per-store week-over-week view, no "your best day" surface.
- **Milestone UI triplication.** `milestone_popup` + `milestone_banner` + `milestones_panel` — three components for the same idea. Unclear which is canonical. Reads like iterations stacked rather than replaced.
- **Duplicate store controllers.** For every store there's a `<store>.gd` plus `<store>_store_controller.gd`, and for electronics also `electronics_lifecycle_manager.gd`. `game_world.gd` wires the controllers, the scene-sided `.gd` files are in varying states of hollow. This is legacy refactor residue.
- **Root-level content duplication.** `fixtures.json`, `upgrades.json`, `pocket_creatures_cards.json`, `items_retro_games.json`, `items_sports_memo.json`, `items_video_rental.json`, `milestone_catalog.json` all still sit at `game/content/` root even though there are now proper subdirs for most of them. The milestone system literally reads from the legacy path while the loader prefers the new path. That's exactly the kind of split-brain that will bite during a save migration later.

## What the next major version should be

I'm going to call it straight: **this is not ready for a "next major version." The current major is not finished. Call it 0.x and finalize it.**

There is a real game in here. It does not need more mechanics. It needs the existing scaffolded mechanics turned real, the secret/ambient/meta backbone either surfaced or pruned, and the UI consolidated. The AIDLC planning index has 500+ issues and 120ish implemented — that is a tell. The harness has been generating forward motion without a hard finishing pass.

The next real push is a **"Lock 1.0" / Finalization** release, not a next-version evolution. Concretely that push is:

1. **Finish or kill every stubbed store mechanic.** Specifically:
   - Video rental: finish rent/return/overdue/late-fee/tape-wear or cut the store to 4.
   - Electronics: finish warranty dialog + demo-unit designation, or cut warranty from checkout and reshape electronics around the lifecycle curve alone.
   - Sports: turn authentication into a real mechanic (risk, partial info, grading states, cost, time) or accept that it's a flavor checkbox and move on.
   - Retro games: fine. Keep.
   - Pocket creatures: finish or cut the trade system, don't leave the orphan.
2. **Make secret threads and ambient moments visible or remove them.** A thread system with no thread log is a waste of maintenance. Either give the player a "stories / regulars / legends" tab where they can see thread state, or delete `secret_thread_*` and pull the scaffolding. Same for ambient moments — either give them a surface with recall and weight, or make them simple flavor ticks and stop pretending they're a system.
3. **Collapse milestone UI to one component.** Pick popup OR banner OR panel. Not all three.
4. **Delete the duplicate store `.gd` classes and the content-root duplicate JSONs.** One controller per store. One path per content type. Make `ProgressionSystem` read from the canonical progression/milestones path.
5. **Normalize the data layer.** Stop branching on whether a type is a typed `Resource` or a raw entry dictionary. Endings, secret threads, seasonal config, difficulty config — some go through typed resources, some don't. Pick a rule.
6. **Warranty, trade, demo, refurb should all share a common "in-store player action" pattern.** Right now each is its own dialog + its own wiring + its own event names. Unify the in-store modal/drawer convention so all of them feel like part of the same game.
7. **Ship a finished content pass.** 2 ambient moments, 2 secret threads, 2 seasons — that's thin for a game that advertises this stuff as a vibe layer. If it's going to exist, ship 10+ ambient moments, a handful of actual threads with a payoff, and enough seasonal variety that running to day 90 feels different from day 30.

That's the next major. Not "2.0." It's "the 1.0 that the scaffolding already thinks it is."

## What the UI / UX is doing well and poorly

### What it's doing well

- **HUD is tight.** `hud.gd` is focused: cash, day/time, phase, speed, reputation, milestones entry. It doesn't try to be a dashboard. Good.
- **Pricing/inventory/checkout feels native.** Panel layering works. Inventory → pricing → checkout → haggle is a coherent flow that reads like a single loop, not four separate screens.
- **Day summary as a natural punctuation.** Good rhythm, lands at the right point in the loop.

### What it's doing poorly

- **Panels are global even when they're store-specific.** Authentication, refurbishment, pack opening, trade, warranty — these are instantiated (or would be) for all runs even though only one store uses each. Fine for memory, bad for mental model. Panels should live with the store controller, not the world.
- **No consistent modal convention.** Haggle is one kind of modal. Refurbishment is another. Authentication is a dialog. Warranty wants to be a dialog. Trade wants to be a panel. Each re-invents. There is no "in-store action modal" base.
- **Navigation between panels is implicit.** Open-on-keybind, close-on-escape. No global "what am I in" indicator, no breadcrumb, no panel stack manager. This will hurt the second the player has to stack 2-3 actions (e.g., inventory → refurb → back to inventory).
- **Milestone surfacing is inconsistent.** Popup, banner, and panel doing overlapping jobs. Pick one and make it the source of truth.
- **Tutorial overlay is in the global UI layer but onboarding state is in its own autoload.** That seam shows — players will feel tutorials come and go slightly off-beat.
- **The 2000s mall vibe is not showing up in the UI.** This is the biggest UX miss. The product premise is "2000s specialty retail mall." The UI is neutral functional Godot panels. None of the period texture (logos, CRT feel, mallish signage, era-specific fonts) is carrying into the chrome. The setting lives in item descriptions and store names only.
- **Ambient moments have no visible surface.** See fake-done list. They exist in backend only.
- **No "state of the mall" view.** The game spans 5 stores but there's no single screen that shows me per-store rep, revenue, inventory health, staffing, standing. I have to enter each store to check. For a multi-store sim, that's a real omission.

### UX shifts that matter most for finalization

- Add a **Mall overview / state dashboard** as a first-class HUD entry. Per-store cards: rep tier, cash contribution today, inventory health, active events, problems flagged.
- Add a **Stories / Regulars / Moments log** if secret threads and ambient moments are staying in. Otherwise remove them from user-facing scope.
- Replace the milestone triplication with a **single milestone tray** with a popup hook for new unlocks.
- Unify all in-store actions into a consistent **action drawer** pattern. Haggle, refurbish, authenticate, warranty, trade — all same shape.
- Push 2000s-mall texture into the chrome. Period typography, slight CRT warmth on the HUD, mall-map-style for the mall overview. Right now the UI is agnostic; it shouldn't be.

## Feature / flow coherence

### What naturally belongs together

- Inventory / pricing / checkout / haggle → this is the transaction cluster. Coherent.
- Time / day phases / day summary / ending evaluator → session rhythm cluster. Coherent.
- Market events / seasonal events / random events / trend system / market value → market dynamics cluster. Coherent but noisy; hard for the player to tell which force is moving a price right now.
- Progression / milestones / unlocks / completion tracker → progression cluster. Needs UI consolidation but belongs together.
- Reputation / customer system / queue / staff → service-quality cluster. Belongs together. Should be visualized together.

### What feels bolted on

- Secret threads and ambient moments relative to everything else. They ride on the signal bus but the player has no entry point.
- Meta shift system is great but siloed to pocket creatures. If other stores don't have equivalent "meta" pressure, then the pocket creatures store plays a different game than the others.
- Tournament system is pocket-creatures-only and lives at a world tier even though it's store-local.
- Trade system is entirely orphaned.

### What should become first-class next

- The **multi-store mall** is the product's actual premise. Treat the mall as the unit of play. A mall overview, cross-store trends, an event ticker, per-store KPIs — that's what the next push should center on.
- **Events telegraphing.** Market/seasonal/random/meta events need a single "what's happening" feed so the player can make decisions against them instead of being surprised by them.

### What should stay secondary / admin / hidden

- Performance report system as a backend feed to day summary and endings — fine, don't promote it to its own screen.
- Completion tracker — fine as an ending trigger; don't build a dedicated UI for it unless it becomes a visible challenge run mode.
- Debug overlay — keep it debug-only, which the repo already does correctly.

## Data / API / content validation concerns

This is a local Godot game, not a client-server app, so "API" is really the content contract. But the same flavor of trust-break applies.

- **Content type detection has four fallback layers** (dict `type`, events-dir special case, directory-name heuristic, file-basename heuristic). That's three too many. Right now it's tolerant, which is nice, but it also means a new file in the wrong directory will be silently classified wrong. Convert to a single rule — `type` field required in the dict, otherwise the file is rejected at boot. Reject early, don't heuristic-rescue.
- **Split-brain content paths.** `game/content/milestones/` and `game/content/progression/` both hold milestone definitions. Loader prefers new path, `ProgressionSystem` reads old path directly. This is a live landmine.
- **Root-level content duplicates are a save-migration risk.** When `items_retro_games.json` changes semantics vs `items/retro_games.json`, a save that stores canonical item IDs across a refactor will break. Lock the canonical path now.
- **Canonical IDs vs display names.** `ContentRegistry.resolve` normalizes aliases. That's good. But it means display-facing strings and runtime IDs can drift. Any code that uses a display string as a lookup key is a bug waiting to happen. Worth an audit pass.
- **Cross-reference validation.** `validate_all_references()` checks item store_type, store starting_inventory, and scene paths. It does not check: market event target IDs, seasonal event category tags, trend category tags, supplier catalog references, milestone trigger IDs, secret thread precondition IDs, ending stat references. That's a lot of field coupling that goes unvalidated at boot.
- **Save versioning.** Save version is currently `1` and older saves are migrated. That's fine until the next schema break. Need a policy: when do we bump? What do we refuse? Right now it's vibes.
- **Economy math scatter.** Price multipliers come from: difficulty, reputation tier, trend, market event, seasonal event, random event, meta shift, sports season boost, condition, warranty, authentication, lifecycle phase. Different systems read different multiplier inputs. There is a real risk that two systems apply the same effect or that an effect stops stacking correctly. This wants a single `PriceResolver` that everything funnels through, with a trace of which multipliers applied so you can debug and expose it in a tooltip.
- **Customer AI trust.** Customers use archetypes + patience + budget + preference tags. Hard to know without playing whether the distribution feels fair. Deserves recorded-session playtesting and a validator that captures per-day customer stats for sanity.
- **Ending eval fairness.** 13 endings, 22 tracked stats, priority ordering. Easy to imagine an edge case where a "bankruptcy" ending triggers over a "crisis operator recovery" ending even when the player actually recovered, or vice versa. Needs a deterministic golden-path test per ending.
- **Tests over code, not content.** 300+ GUT tests cover systems. I saw almost nothing that validates *content correctness* at boot (e.g., "every milestone has a valid trigger," "every ending has stat refs that exist," "every thread precondition exists"). That's the kind of test that pays back constantly in a content-heavy game.

## Where trust is strong and where it breaks

### Trust is strong

- Core transaction flow (buying, pricing, selling, haggle).
- Day phase pacing and end-of-day summary.
- Reputation tier behavior (changes feel consistent with player action).
- Refurbishment flow in retro games — players will trust this.
- Pack opening in pocket creatures — drops feel structured.
- Save/load round-tripping.

### Trust breaks fast

- **Video rental store existing at all.** The moment a player tries to rent a tape and nothing happens, the premise is gone.
- **Warranty prompts that never appear.** If the product markets "offer warranties on electronics" and the dialog never shows, that's a lie.
- **Secret threads whose progress you can't see.** Players will either ignore them entirely (because they're invisible) or feel cheated by the ending screen telling them a thread concluded that they never knew existed.
- **Multi-source price multipliers.** First time a player sees a price and can't figure out *why* that price, trust erodes. A trace/tooltip showing "base 20 → demand +10% → meta shift +50% → rep tier +20% → 36" would fix it; its absence will undermine the sim's core claim of being a fair market.
- **The duplicate controllers and orphaned systems.** These won't be visible to the player, but they'll surface as small bugs when systems disagree about state (e.g., the electronics scene `.gd` says X, the controller says Y). Those are the bugs that look like haunted behavior.
- **Milestone UI triplication.** The player will see the same milestone announced twice in two different components and distrust the progression model.

## Product discipline — where focus shows, where I clearly threw stuff at the wall

**Focus shows in:**
- Core transaction loop.
- Retro games store (this one was clearly taken seriously to completion).
- Pocket creatures store (nearly complete).
- 5-tier initialization ordering.
- Save/load coverage.
- Testing on core systems.

**I threw stuff at the wall in:**
- Meta narrative (secret threads, ambient moments, endings, completion tracker). This is the biggest pile. Five systems, thin content, no UI.
- Store-specific signature mechanics. Two of five stores (retro games, pocket creatures) are real. Sports is shallow, electronics is half-wired, video rental is not there. Treating every store as having a signature mechanic is too broad; either commit or simplify some stores to "just sell things with nice-looking items."
- Duplicate controllers. Every store has 2-3 classes because refactors weren't finished.
- Content-root legacy JSONs alongside new structured subdirs.
- Three milestone UI components.

AIDLC is doing a lot here and it shows both ways. On the plus side, the architectural bones are clean and the test coverage on core systems is real. On the minus side, the planning index has the harness writing "next features" faster than the game is closing "finish this feature properly." Classic loop-driven drift. Needs a forced finalization pass.

## What I would push hard next

In priority order, not time order:

1. **Decide the fate of the scaffolded systems** — finish or cut. List:
   - Video rental flow: finish or cut store.
   - Warranty dialog: finish or cut from checkout.
   - Demo units: finish or cut from electronics.
   - Trade system: finish or delete.
   - Secret threads UI: add or delete the system.
   - Ambient moments UI: add or delete the system.
2. **Mall overview screen.** First-class. Per-store cards. Event feed. This is what turns five stores from "five separate games" into "a mall."
3. **Single price-resolver with trace.** Every multiplier goes through one path. Tooltip exposes the trace. Fairness is visible.
4. **UI texture pass.** Push 2000s mall feel into the chrome, typography, and HUD. Right now the setting is in the text, not the UI.
5. **Unified in-store action drawer.** One shape for haggle, refurb, authenticate, warranty, trade. Kill ad-hoc dialogs.
6. **Content contract validation at boot.** Reject on bad `type`. Validate every cross-reference (events, trends, suppliers, threads, endings). No more heuristic rescue.
7. **Consolidate duplicate controllers and content paths.** One class per store. One canonical path per content type. Migrate and delete the rest.
8. **Collapse milestone UI to one component.**
9. **Shore up content volumes.** More ambient moments, more threads with payoffs, more seasonal variety. Thin flavor content will feel fake next to a 300-test system layer.
10. **Run AIDLC in finish mode, not feature mode.** Cap new issues. Burn down the 123 "implemented, 0 verified" backlog. Verification and closure > next feature.

## Blunt take

The repo is more mature than it looks in patches and less mature than it looks in total. The core loop is real. The architecture is honest. A meaningful amount of the "signature" content is scaffolding, and an entire meta-narrative layer exists without player-facing surface. The biggest trap right now is calling this "next major version" when what it really needs is a finalization pass on the current one. Every "next feature" added before finishing the current ones is going to make the gap between backend systems and player-visible game wider.

The AIDLC loop is genuinely producing. It is also genuinely not closing. That's the single biggest lever.

## North star

**A 2000s specialty-retail mall that feels alive, fair, and specific.** Five stores, each with one signature mechanic that matters and is legible. One mall overview that makes running five stores feel like a single business. One coherent visual period texture. One honest price model you can trace. One narrative layer — whichever layer — that the player can actually see. Nothing bolted on. Nothing invisible. Nothing stubbed.

Finish 1.0. Then talk about 2.0.

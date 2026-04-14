# Mallcore Sim - Full Repo Audit Braindump

## What You Said You Need

- Game should be playable and functional, not just "systems technically exist."
- Leasing must reliably work.
- Entering a store must not go black or feel dead.
- Visual quality needs a strong pass; current look is too basic/flat.
- You want a practical path from "prototype wiring" to "actually fun sim."

## Current Reality (Directly Aligned to Your Feedback)

- Movement and click interaction are now present, but core loop reliability still breaks immersion.
- Leasing and store ownership flow have edge cases that can make the game feel broken.
- Store interior rendering and camera/environment ownership are inconsistent, causing black/dim/flat scenes.
- Many systems are present but not consistently integrated into a meaningful player loop.
- Visual direction exists, but lighting/material/environment control is fragmented and over-stacked.

## Highest-Impact Functional Problems

### 1) Store identity mismatch across code/content (critical architecture bug)

- Different store ids are used in different layers (runtime, content JSON, item store_type tags, scene maps).
- Example pattern: runtime ids like `sports_memorabilia` vs content ids like `sports`.
- This causes failures in:
  - starting inventory generation
  - ownership display in lease UI
  - per-store inventory filtering
  - rent lookup from store definitions
  - scene/store mapping consistency

Why this matters:
- This is the #1 reason systems feel "wired but nonfunctional." The game disagrees with itself about what a store is.

### 2) Lease flow can close UI even on backend lease failure

- Lease dialog emits success path and closes.
- Mall/economy handler can still fail to deduct cash and abort ownership.
- End result: user sees close/confirm behavior but no ownership outcome.

Why this matters:
- Feels like a broken button even when some code paths run.

### 3) Store interiors can render with wrong world environment

- Multiple `WorldEnvironment` nodes exist across hallway and stores.
- In this composition, one environment can dominate based on tree order.
- Store-authored lighting/ambient profile may never become active when expected.

Why this matters:
- You enter a store and see black/flat/dim output that reads as "scene is broken."

### 4) Build-mode and camera-dependent systems can remain bound to old camera

- Build mode camera references are initialized once and not always refreshed on store enter/exit.
- This leads to dead-looking interactions and incorrect ray behavior in interiors.

Why this matters:
- Even if movement works, interactions can still feel randomly dead in key contexts.

### 5) New game seed/setup does not guarantee meaningful first-play loop

- Starter inventory generation is not robustly guaranteed via canonical ids.
- Some systems initialize before required dependencies exist (ordering issue).
- Store controller dependent wiring is incomplete until after entering a store.

Why this matters:
- First 5-10 minutes can feel empty/nonfunctional, which kills confidence immediately.

## Visual Audit - Why It Still Looks Basic

### What is working

- There is an intentional mall mood direction (warm practical + neon accents).
- Material library is structured and reusable.
- Storefront sign/interactable structure is improving.

### What still hurts presentation

- Lighting is over-layered (scene lights + procedural lights + accent lights), causing washout/flat contrast.
- Environment/post-processing setup is minimal and inconsistent.
- Geometry remains primarily primitive boxes; without strong AO/glow/grade, it reads placeholder.
- Visual language is not yet cohesive (some areas high contrast, others low-information beige).

## Why It Feels Nonfunctional Even With "Lots Wired Up"

- You have breadth (many systems), but weak orchestration (ids, state transitions, initialization order, ownership of truth).
- The game currently behaves like multiple partial games sharing one scene tree.
- Functional confidence requires fewer but reliable contracts:
  - canonical store identity
  - canonical active camera/environment
  - canonical store ownership + slot mapping
  - canonical start/load state application

## Priority Fix Plan (If the goal is "playable and convincing fast")

### Phase A - Reliability Backbone (do first)

1. Canonicalize store ids across all layers.
   - Add one alias/normalization map if migration cannot be done in one pass.
   - Route all store lookups through one normalization function.

2. Make lease flow transactional.
   - Dialog closes only on confirmed success.
   - Add explicit lease failure signal + user-facing reason.

3. Fix ownership persistence model.
   - Persist `slot_index -> store_id` mapping, not just a flat owned list.
   - Reapply storefront state from that mapping after load.

4. Fix world environment ownership.
   - One authoritative environment path at runtime (global/shared/camera-driven).
   - Avoid competing `WorldEnvironment` nodes.

5. Ensure camera-dependent systems refresh on store transitions.
   - Build mode, ray systems, and any camera-cached tools rebinding on enter/exit.

6. Sync time source.
   - Remove duplicate day truth (`GameManager.current_day` vs `TimeSystem.current_day`) or sync strictly from one source.

### Phase B - First Real Play Loop

1. New game seed guarantees:
   - valid starter inventory
   - valid owned store state
   - valid in-store interactions on first entry

2. Store switch propagation:
   - all relevant panels/systems receive active store id/type.

3. Save/load parity:
   - load applies same runtime state shape as live session transitions.

### Phase C - Visual Quality Pass (after A/B)

1. Lighting cleanup:
   - reduce overlapping omnis
   - establish key/fill/accent ratios
   - keep one visual authority per zone

2. Environment grade:
   - shared environment resources per zone type
   - conservative glow for emissive readability
   - AO/contact depth tuning

3. Storefront readability:
   - stronger entry silhouette
   - threshold/floor cues
   - consistent sign hierarchy

4. Material cohesion:
   - unify roughness/value ranges so assets sit in same world.

## Practical Development North Star

For the next milestone, optimize for this user experience:

1. Start new game.
2. Lease succeeds clearly or fails clearly (never ambiguous).
3. Enter store, scene is lit/readable, interactions work immediately.
4. Stock, sell, and see customer/economy feedback in same session.
5. End day, continue, and state remains coherent.

If any step fails, fix that before adding new content/features.

## Brutally Honest Summary

- The project is promising and has substantial scaffolding.
- The main issue is not "missing systems"; it is "integration truth and runtime ownership."
- Right now it feels like a prototype because state contracts are loose.
- Tighten identity/state/camera/environment contracts first, then visual polish will finally land.
- Once those contracts are locked, this can quickly move from "nonfunctional demo" to "actual simulator."

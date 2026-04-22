# BRAINDUMP.md

# Mallcore Sim — audit / wiring / integration braindump v2

This is the corrected take after the latest pass.

Yes, it looks a bit better.
No, it is still not actually playable.

The new screenshots tell a much clearer story now:

- the main menu is cleaner
- the mall overview is more legible
- the store cards are clearer
- the UI contrast is improved
- the game is now at least trying to communicate the next action

But the actual player result is still:

- pick a store
- hit a dead grey/empty screen
- still no movement
- still no trustworthy store entry flow
- still no visible playable world/state
- still feels like systems are disconnected even when UI exists

So this is **not a feature problem**.
This is still an **audit, wiring, scene-flow, state, and integration validation problem**.

That needs to be the full focus.

---

# The real state right now

## What improved
Credit where it is due:

- the mall overview is much more understandable now
- the store cards being visible behind the overlay helps
- the menu is cleaner and less muddy
- the tutorial messaging is more explicit
- the game now looks more like it knows what it wants to be

That is real progress.

## What is still broken
The actual loop is still failing at the handoff from hub -> store.

That means the game is currently succeeding at:
- presenting navigation options

and failing at:
- executing the chosen option into a playable state

That is a classic integration gap.

---

# Updated diagnosis

## 1. The hub is no longer the main problem
Before, the whole thing looked visually incoherent.
Now the hub is mostly good enough to support testing.

The main problem has shifted.

Now the big failure point is:

**store transition / store scene readiness / player controller activation / playable state entry**

That is good news, because it means the target is narrower.

---

## 2. The “grey screen after selecting store” is the whole story
This is the kind of bug that usually means one of these:

- scene loads but the actual store content node is missing
- scene loads but camera is not pointed at anything useful
- scene loads but store visuals are hidden, offscreen, or behind z/order/layer issues
- scene loads but player/controller never gets possession
- scene loads but tutorial or UI state is suppressing movement/input
- scene loads but expected store world is not instantiated from data
- scene loads but wrong mode is active (hub mode, placeholder mode, empty controller mode)
- scene transition works but store bootstrap/init does not

This is exactly why the next step should be **audit and truth-table validation**, not feature work.

---

## 3. The game now looks like a partially connected app
This is the important difference from the first round.

Before, it looked like “maybe the visuals are bad and nothing works.”
Now it looks more like:

- the menu layer works
- the hub layer mostly works
- the instruction layer exists
- the state labels exist
- the store selection affordance exists

But the actual connected chain behind it is still not reliable.

So this now feels much less like “design the whole game”
and much more like:

**trace every step of the live path and find where the chain breaks.**

That is the work.

---

# The correct mandate for this pass

## Do not add features
Do not expand mechanics.
Do not add narrative layers.
Do not add more UI concepts.
Do not add polish-only work.
Do not add more stores.
Do not add content volume.

## Do this instead
- audit
- trace
- wire
- validate
- remove dead paths
- prove the current intended path actually works
- fix integration gaps
- confirm scene/controller/state ownership
- confirm input and camera are live after transition
- confirm world/store content is actually instantiated and visible

This pass should feel like a systems integration hardening sprint, not product expansion.

---

# What I think is happening

My best guess is the mall overview and store selection are now basically functioning, but after selection one of these is true:

## Possibility A — wrong scene loads
The game is transitioning to a scene shell or placeholder scene instead of the actual playable store scene.

## Possibility B — correct scene, wrong child content
The scene loads, but the selected store interior/controller/content never gets injected or attached.

## Possibility C — visuals are there, camera is wrong
The store scene may exist, but the camera is pointed into empty space or an unlit region, making it appear grey/blank.

## Possibility D — visuals and scene load, but player is dead
The store scene may be correct, but input is not bound, movement is disabled, focus is captured, or tutorial state blocks control.

## Possibility E — store is meant to be card-driven, but world mode still takes over
The game may be in a weird half-mode where:
- the hub says click card to enter
- the code transitions to a world/store scene
- that scene expects another layer to initialize
- that layer never does

That would explain why it feels like the game is structurally close but not actually connected.

My suspicion is it is some mixture of B, D, and E.

---

# What we should work on now

## Workstream 1 — full golden-path audit
Need a single audit document that traces the exact runtime chain for:

### New Game -> Mall Overview -> Store Select -> Store Ready -> First Interaction

For each step, verify:

- which scene is active
- which controller owns the state
- which UI layer is visible
- which input mode is active
- whether movement is enabled
- whether the player node exists
- whether the camera exists and is current
- whether the selected store content was instantiated
- whether interactables exist
- whether tutorial state is blocking anything
- whether any failure falls back silently

No guessing. No “should.”
Only runtime truth.

---

## Workstream 2 — pass/fail matrix
Build a hard validation matrix like this:

### Boot / Menu
- app boots: PASS / FAIL
- new game starts: PASS / FAIL
- load game works: PASS / FAIL

### Mall Hub
- mall overview visible: PASS / FAIL
- store cards render: PASS / FAIL
- selected store is highlighted correctly: PASS / FAIL
- tutorial objective matches expected action: PASS / FAIL

### Transition
- clicking store card triggers transition: PASS / FAIL
- expected store id is passed forward: PASS / FAIL
- expected scene is loaded: PASS / FAIL
- store-specific controller initializes: PASS / FAIL
- store content instantiates: PASS / FAIL

### Store Ready State
- camera is valid/current: PASS / FAIL
- player controller exists: PASS / FAIL
- movement enabled: PASS / FAIL
- interact prompt visible when relevant: PASS / FAIL
- first actionable verb exists: PASS / FAIL

### Store Loop
- inventory opens: PASS / FAIL
- shelf/display interaction works: PASS / FAIL
- pricing interaction works: PASS / FAIL
- sale/customer flow works: PASS / FAIL
- day close works: PASS / FAIL

Anything not passing is the work.
That is the roadmap right now.

---

## Workstream 3 — scene ownership audit
Need to figure out who actually owns store entry.

Right now it feels ambiguous whether store entry is controlled by:
- mall hub scene
- world scene
- store controller
- tutorial system
- game world/root scene
- some transition manager

That ambiguity is usually where these bugs breed.

We need to explicitly define:

- who receives store selection
- who loads the store
- who instantiates visuals
- who activates player/input
- who declares the store “ready”
- who surfaces the first objective

If more than one system is trying to do any of those, it needs consolidation.

---

## Workstream 4 — kill silent failure
This feels like a project where too many things can fail quietly and still leave the player on a technically loaded screen.

That has to stop.

For this pass:
- if store content fails to instantiate, fail loud
- if camera is missing, fail loud
- if player controller is missing, fail loud
- if selected store id is invalid, fail loud
- if transition completes without entering a playable state, fail loud

A blank/grey screen is the worst possible behavior because it hides the actual broken link.

---

## Workstream 5 — define “store ready” as a real state
Right now it feels like the code may be treating “scene loaded” as success.
That is not success.

A store should only be considered ready when all of this is true:

- selected store id resolved
- correct store controller loaded
- correct scene tree built
- camera active
- movement/input enabled or intentionally disabled with explicit UI reason
- at least one obvious interaction available
- player objective updated
- no hidden modal is stealing focus

If any of those are false, store entry is not complete.

---

# Updated product call

## Still no feature expansion
This is now even more true than before.

The improved hub makes the next gap obvious:
**the project is still failing on playable-state transition, not on missing game ideas.**

So the next phase should be framed as:

### “Playability hardening pass”
Not:
- content pass
- roadmap expansion
- narrative pass
- art pass
- feature completion sprint

This is a hardening / integration / validation pass.

---

# What should probably be cut or paused for now

Pause anything that is not directly tied to:
- scene transition reliability
- input activation
- camera correctness
- store content instantiation
- first actionable interaction
- day-loop validation

Specifically demote:
- extra milestone presentation work
- more event surface work
- more hub cosmetics
- meta systems
- flavor-only scene dressing
- additional store complexity beyond the one active path being debugged

---

# Visual take on the newest screenshots

## Main menu
Good enough.
Not where time should go.

## Mall overview
Much better.
Still not final, but now absolutely usable as a debugging hub.

The blue background is already doing more for readability than the old brown soup.
That alone proves the earlier diagnosis was correct: contrast and hierarchy mattered.

## Tutorial / bottom rail
Still a little clunky, but at least it is trying to state a task.
That is fine for now.

## Store entry result / grey-black screen
This is the new centerpiece of the problem.

This screen says:
- the game knows which store you picked
- the HUD remains alive
- the app did not crash
- some transition completed

But:
- nothing meaningful is present
- movement still appears dead
- no clear store world exists
- no clear interactive object exists
- the player is stranded in a technically-running but functionally-empty state

This is why the next task is not design.
It is runtime truth-finding.

---

# Strongest recommendation

## Treat the store-entry bug as the primary blocker for the entire project
Not a minor issue.
Not one ticket among many.
Not “we’ll get to it after polish.”

This is the blocker because if store entry is unreliable, then:
- all store mechanics are irrelevant
- all narrative systems are irrelevant
- all content is irrelevant
- all day-loop work is untrusted
- the whole game feels fake even if parts are implemented

So the mandate should be:

**No new systems until New Game -> Mall -> Store -> First Action is proven stable.**

---

# The exact implementation prompt I would give the team now

## Objective
Run a strict audit-and-wire pass on Mallcore Sim focused only on getting the current gameplay chain fully connected and validated.

## Scope
Do not add new features except where a missing critical connector is required to complete the existing path.

## Required focus
1. Trace the runtime path from New Game to first in-store action.
2. Identify where selected store state, scene loading, controller activation, camera setup, input mode, or store content instantiation breaks.
3. Remove silent failure and replace it with explicit failure states/logging.
4. Establish a real “store ready” contract and enforce it.
5. Verify one complete path to first actionable interaction.

## Deliverables
- audit doc of current scene/controller/input flow
- pass/fail matrix for the golden path
- list of dead or duplicate transition code paths
- fix set that makes one store load into a real playable state
- validation notes proving movement/input/camera/store-content readiness after transition

## Acceptance criteria
- selecting a store never lands on a blank or grey dead state
- selected store content is visibly present
- camera is valid and useful
- movement works if movement is intended
- if movement is not intended, the screen clearly presents the next clickable action
- first interaction is obvious and testable
- no silent transition failures remain in the active flow

---

# Final blunt summary

This is closer than before, but it is still mostly a shell around a broken handoff.

The game now looks like it has:
- a menu
- a hub
- a task rail
- store selection

What it still does not reliably have is:
- a working arrival state after store selection

So the work now is not invention.
It is not expansion.
It is not feature creep.

It is:

**audit the live chain, wire the broken links, remove dead-end states, validate store readiness, and do not move on until one full path is actually real.**

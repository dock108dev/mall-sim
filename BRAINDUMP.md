# Mallcore Sim — BRAINDUMP
## Blunt Reality
This is no longer a “what should we build?” problem.
This is a **“we built a lot, but the runtime chain is not verified or connected” problem.**
The latest state proves:
- UI is better
- Hub is usable
- Store selection exists
- Systems likely exist underneath
But the actual experience is still:
> Pick store → dead/grey state → no movement → no interaction → no trust
That means:
**The game is failing at execution, not design.**
---
# The Most Important Signal (From AIDLC)
- 0 issues verified  
- 1 failed  
That is the entire story.
This repo is currently optimized for:
> writing code
Not for:
> proving the game actually works
---
# New Core Principle
## 🚫 “Implemented” ≠ Progress  
## ✅ “Verified in runtime” = Progress
Nothing counts unless it is:
- visible
- interactable
- testable in a live path
- part of a complete loop
---
# What Changed
The diagnosis is the same, but stronger:
### Before:
“Feels disconnected”
### Now:
**It is disconnected, and the system confirms it (0 verified)**
So we tighten the mandate:
> This is now a **verification-first, runtime-truth, integration pass**
---
# The Real Problem
## The chain is broken here:

New Game
→ Mall Overview
→ Store Selection
→ Store Scene Load
→ Store Ready State ❌ (THIS FAILS)
→ First Interaction

Everything before store-ready mostly works.
Everything after store-ready is irrelevant until that works.
---
# What “Store Ready” Actually Means
Right now, the code likely treats:
> scene loaded == success
That is wrong.
## Store is ONLY ready if ALL of this is true:
- store id is resolved correctly
- correct scene is loaded (not placeholder)
- store controller is initialized
- store content is instantiated (items, shelves, etc.)
- camera is active and pointing at something meaningful
- player controller exists
- input is enabled (or intentionally disabled with UI explanation)
- no modal is stealing focus
- at least one visible actionable interaction exists
- objective text matches what the player can actually do
If ANY of these are false:
> Store entry is broken
---
# What Is Likely Happening
One (or more) of these is true:
### A. Wrong scene
Loading a shell / placeholder scene instead of real store scene
### B. Scene loads, content doesn’t
Store visuals or logic never instantiated
### C. Camera invalid
Looking into empty space → “grey screen”
### D. Input dead
Movement disabled, UI focus trapped, tutorial blocking
### E. Split ownership
Multiple systems trying to control:
- transition
- store init
- player state
→ resulting in nothing fully completing
---
# The Mandate for This Phase
## 🚫 DO NOT
- add features
- expand stores
- add content
- add narrative
- polish UI beyond clarity fixes
- “move forward”
## ✅ DO
- audit
- trace
- validate
- wire
- remove dead paths
- enforce runtime truth
- fail loudly instead of silently
---
# Workstreams
## 1. Golden Path Audit (MANDATORY)
Trace this EXACT flow:

New Game → Mall → Click Store → Store Loads → Player Can Act

For each step, log:
- active scene
- active controller
- UI state
- input state
- camera state
- instantiated nodes
- expected vs actual store id
- failure points
No guessing. Only runtime truth.
---
## 2. Pass / Fail Matrix
Build this and DO NOT proceed without it:
### Boot
- app loads: PASS / FAIL
- new game starts: PASS / FAIL
### Mall
- hub renders: PASS / FAIL
- store cards visible: PASS / FAIL
- selection works: PASS / FAIL
### Transition
- click triggers transition: PASS / FAIL
- store id passed correctly: PASS / FAIL
- correct scene loads: PASS / FAIL
### Store Ready
- camera valid: PASS / FAIL
- player exists: PASS / FAIL
- input active: PASS / FAIL
- store content visible: PASS / FAIL
- interaction available: PASS / FAIL
### Loop
- inventory works: PASS / FAIL
- action works: PASS / FAIL
- day close works: PASS / FAIL
👉 Anything FAIL = current work
---
## 3. Scene Ownership Audit
Right now, ownership is unclear.
Define EXACTLY:
- who receives store selection
- who loads scene
- who instantiates content
- who enables input
- who sets camera
- who declares “store ready”
- who updates objective
If multiple systems touch same responsibility → consolidate
---
## 4. Kill Silent Failure
This is critical.
Replace ALL silent failures with:
- logs
- asserts
- visible debug states
Examples:
- missing store → crash or error UI
- missing camera → fail loud
- missing player → fail loud
- empty store scene → fail loud
👉 A grey screen is the worst possible outcome because it hides truth
---
## 5. Enforce “Store Ready” Contract
Create a single function/state:

enter_store(store_id) → READY or FAIL

No partial success.
Either:
- fully playable
or
- explicitly failed
Nothing in between.
---
---
# New Acceptance Criteria (Non-Negotiable)
## The game is “working” ONLY if:
- selecting a store NEVER leads to blank/grey state
- store scene visibly contains content
- camera is correct
- player can act OR is clearly instructed
- at least one interaction works
- no silent failures exist
---
# Visual Observations (Latest)
## Good
- hub is much better
- blue background improves contrast
- store cards readable
- UI hierarchy improving
## Still Broken
- store entry = dead state
- no visual confirmation of success
- no interaction anchor
- no camera authority
- no player trust
---
# Product Call (Final)
## STOP trying to prove:
- 5 stores
- narrative systems
- polish
- content volume
## START proving:
> one store can load, be entered, and be interacted with
That is the entire game right now.
---
# One Sentence Summary
**The project is not blocked by missing features — it is blocked by unverified, disconnected runtime flow.**
Fix the chain.
Everything else can wait.
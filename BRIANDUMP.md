# Mallcore Sim — comprehensive audit braindump

This is **not** a feature expansion pass.  
This is a **full-game cleanup, connection, audit, polish, stabilization, and readiness pass**.

The goal is simple:

By the end of this work, the game should feel like a real, coherent, playable thing with **no obvious dead ends, disconnected systems, placeholder nonsense, broken flows, dangling code paths, half-wired content, or “yeah that part kind of exists but not really” behavior**.

The target outcome is:

- I can sit down and do a **one-day playthrough**
- the game feels structurally sound
- the codebase is readable and maintainable
- all major systems are actually connected
- all obviously intended content paths work
- all junk, drift, duplication, and abandoned experiments are either removed or clearly fenced off
- the game is tested hard enough that I trust it
- and **after** that is done, a final tutorial / guided play walkthrough can be written based on the actual stabilized game

---

## core framing

This audit is about **making the existing game whole**.

Not bigger.  
Not more ambitious.  
Not “while we’re here let’s add three new systems.”  
Not “this would be cool eventually.”

Just:

- tighten everything
- connect everything
- remove fake complexity
- make existing systems behave cleanly
- make code understandable
- make the game playable end to end
- make it feel crisp
- make it ready for a real human play session

This is a **product quality pass**, a **code quality pass**, and a **playability readiness pass** at the same time.

---

## non-goals

These are explicitly out of scope unless required to complete or stabilize already-existing intended flows:

- no new mechanics just because they sound fun
- no major scope expansion
- no new stores unless one is already partially implemented and broken in a way that blocks intended structure
- no redesigning the whole game loop unless the current one is fundamentally nonfunctional
- no “future-proof abstraction” rabbit hole unless current code is unreadable or dangerously tangled
- no content sprawl
- no polishing isolated shiny details while core flows still feel broken
- no broad rewrite for ego or aesthetics alone
- no giant refactor that regresses playability
- no fake completeness via comments/docs while the actual game remains half-wired

---

## primary outcome

The game should be **audit-clean enough** that after this pass I can do a focused one-day playthrough and evaluate the actual product instead of fighting the prototype.

That means:

### player-facing
- boot works
- main menu works
- entering game works
- gameplay loop is understandable
- progression functions
- economy functions
- interactions are coherent
- store flows are connected
- UI gives me enough signal to play without confusion
- save/load works if present or intended
- session flow is stable
- nothing major softlocks, dead-ends, or lies to me

### developer-facing
- code is readable
- responsibilities are clear
- dead code is gone or fenced off
- systems are not half-connected
- naming is sane
- data flow is traceable
- important scenes/resources/scripts are easy to find
- test/verification process exists and is repeatable
- major risks are known, logged, and resolved or explicitly deferred

---

## philosophy for this pass

### 1. no dangling wires
If something exists, it should be one of these:
- used and working
- intentionally disabled and clearly marked
- removed

No more “I think this is supposed to power that other thing maybe.”

---

### 2. no fake systems
Anything that looks like a system from the player side but is actually smoke and mirrors needs to be fixed, simplified, or hidden.

Examples:
- menu options that go nowhere
- objects that imply interaction but do nothing
- progression stats that never matter
- inventory/economy hooks that don’t affect anything
- tutorial prompts for nonfunctional actions
- UI tabs for empty or irrelevant sections

---

### 3. readable beats clever
This pass should bias toward:
- obvious code
- clean scene ownership
- simple wiring
- explicit state
- fewer hidden side effects
- fewer magical global dependencies

The code should feel like something I can reopen in a month and understand.

---

### 4. playability beats architecture purity
If there is tension between:
- theoretically elegant structure
- and a stable, testable, understandable playable build

the playable build wins.

But no hack pile either. The right answer is pragmatic cleanup.

---

### 5. test from the player path outward
Do not test in component isolation only.  
The real question is:

**Can I boot the game and actually play it without hitting confusion, broken flow, or structural cracks?**

---

## scope of the audit

This should be a **comprehensive audit** across all existing intended layers:

### game structure
- boot flow
- main menu flow
- transition into world
- pause/menu/settings flow
- save/load/continue flow if present
- quit/restart loop
- scene transitions
- state resets between sessions

### gameplay loop
- what the player is supposed to do minute to minute
- what the player is supposed to pursue over a session
- whether actions produce understandable results
- whether the loop is actually complete enough for extended play
- whether pacing works at all for a one-day session

### world and navigation
- movement
- camera
- input responsiveness
- collision
- level traversal
- store access
- interaction zones
- map/wayfinding if present
- blocked or inaccessible areas
- geometry jank
- placeholder level oddities

### store / business interactions
- entering stores
- store identity clarity
- store systems actually being connected
- item display / stock / purchase / management flows if present
- whether each store type has an actual loop or just vibes
- interaction consistency across stores
- whether stores feel like variants of the same game or actually meaningfully wired setups

### economy and progression
- currency
- earning/spending loop
- inventory/value relationships
- unlocks
- milestones
- progression pacing
- reward clarity
- whether there is any false progression that looks real but does nothing
- whether the current economy can sustain a one-day playthrough

### UI/UX
- HUD
- prompts
- menu navigation
- button consistency
- labels and naming
- empty states
- visual hierarchy
- readability
- whether the game tells me enough without overexplaining
- whether feedback exists after key actions
- whether the UI exposes broken internal state

### content/data
- JSON/resource pipelines
- item data integrity
- store data integrity
- progression data
- config data
- mismatched IDs
- missing references
- stale resources
- duplicate content definitions
- content that exists in data but is not reachable in-game
- content that is referenced in-game but missing in data

### code quality
- script organization
- ownership boundaries
- scene-script relationships
- naming consistency
- signal/event clarity
- duplicated logic
- hidden globals
- dead code
- old experiments
- TODO sprawl
- brittle assumptions
- missing null guards / safety checks
- logging/debug leftovers
- unnecessary complexity

### stability
- crashes
- softlocks
- bad state transitions
- race-ish issues
- input edge cases
- load/save corruption risks
- broken initialization order
- inconsistent reset behavior
- interaction spam issues
- missing fallback handling

### performance and smoothness
- frame pacing
- unnecessary scene churn
- heavy update loops
- overactive signals
- expensive polling
- resource leaks
- hitching on transitions
- unnecessary load spikes
- interaction latency
- visible stutter sources

### test coverage / verification
- reproducible smoke tests
- scenario testing
- structured checklist for full-day play readiness
- regression protection around critical paths
- sanity pass for data integrity
- script-level verification where practical

---

## desired end state

By the end of this pass, I want the repo and the game to feel like this:

### codebase
- there is a clear entry flow
- the scene tree and script structure make sense
- the current game loop is discoverable from the code
- the critical paths are easy to trace
- dead branches are removed
- incomplete branches are clearly marked or fenced
- data and runtime usage actually match
- “why does this exist?” moments are rare

### game build
- the build launches cleanly
- menus feel intentional
- the world is navigable
- interactions are obvious and functional
- economy/progression are connected
- no major parts feel fake
- the session feels smooth
- the game holds together for a real one-day run

### product confidence
- I can do a focused playthrough after the pass without mentally compensating for prototype slop
- I know what still needs design iteration later
- but the current build is structurally honest and coherent

---

## audit deliverables

The audit work should produce real outputs, not just vague confidence.

### deliverable 1 — architecture and wiring audit
A concrete audit of:
- scenes
- scripts
- singleton/global state
- data files/resources
- event/signal flow
- store/system connectivity
- menu/gameplay/progression connectivity

This should identify:
- disconnected pieces
- half-connected pieces
- duplicate logic
- dead logic
- fake or misleading hooks
- state ownership problems
- brittle flow dependencies

---

### deliverable 2 — dead code and drift cleanup
A pass that:
- removes unused scripts/resources where safe
- removes or fences abandoned experiments
- consolidates obvious duplicates
- aligns names with actual purpose
- strips noise that makes the repo harder to reason about

No fake cleanup.  
Do not hide junk under more junk.

---

### deliverable 3 — critical path stabilization
The main playable route through the game should be identified and hardened.

This means:
- boot to menu
- menu to world
- world to store interactions
- store to economy/progression loop
- pause/settings/save/load as applicable
- session continuity
- end-of-session / return flow if applicable

Every critical path should be explicitly verified.

---

### deliverable 4 — data integrity pass
A full check that:
- resources resolve correctly
- IDs match
- no missing references
- store/item/config data aligns with runtime usage
- no hidden placeholder values break flow
- content declared in data is either reachable or removed
- runtime doesn’t depend on data that does not exist

---

### deliverable 5 — readability pass
Not a vanity rewrite. A targeted cleanup to make the code easier to maintain.

Expected improvements:
- clearer file names
- clearer function names
- reduced nesting where possible
- clearer comments only where helpful
- better separation of responsibilities
- less mystery state
- easier traceability of core game flows

---

### deliverable 6 — playthrough readiness test plan
A structured checklist for:
- smoke test
- interaction test
- economy/progression test
- long-session test
- save/load/reset test
- store coverage test
- obvious edge cases

This needs to exist before calling the audit complete.

---

### deliverable 7 — post-fix final walkthrough basis
Once the build is stabilized, produce the basis for a final “how to play the current game in one day” tutorial.

Important:
This tutorial is **after** the audit/fixes, not before.  
It must reflect the real stabilized build, not aspirational design.

---

## execution order

## phase 1 — repo comprehension and truth gathering
Before changing anything, fully map the current repo reality.

### goals
- identify the actual boot path
- identify all active scenes/scripts
- identify all major systems
- identify all data/resource sources
- identify globals/singletons
- identify intended player loop as implemented, not as imagined
- identify incomplete/abandoned branches

### outputs
- repo map
- current gameplay flow map
- known risks list
- suspected dangling wires list
- suspected dead code list
- suspected fake system list

---

## phase 2 — connectivity audit
Trace all important wires.

### questions
- what calls what?
- what owns what state?
- which systems are actually connected?
- which scenes are reachable?
- which content paths are reachable?
- which UI elements are backed by real behavior?
- which store interactions are real vs implied?
- where does progression state actually live?
- where does economy state actually live?
- are there duplicate truths?

### target
One source of truth per important area where possible.  
Or at least obvious ownership.

---

## phase 3 — cleanup and structural correction
After understanding the repo:
- remove dead code/resources where safe
- fence incomplete branches that should not surface
- consolidate duplicated behavior
- fix naming/ownership confusion
- simplify overcomplicated flow where possible
- make critical systems easier to trace

This is where the repo starts feeling less like a prototype graveyard.

---

## phase 4 — functional stabilization
Now fix actual broken or incomplete connectivity in the existing intended systems.

Examples:
- menu option not routed correctly
- interaction signals not hooked up
- item/store data not reaching UI/runtime
- economy writes not reflected in progression
- progression not updating dependent systems
- save/load not restoring the right state
- session reset not clearing correctly
- UI panels not bound to actual data
- store-specific behavior not actually executing

Again: no new features.  
Only make intended things actually work end to end.

---

## phase 5 — polish for crispness and smoothness
Once structurally sound:
- fix responsiveness issues
- remove janky transitions
- smooth interactions
- tighten UI feedback
- fix rough camera/input edges
- address obvious performance hitches
- remove friction that makes the build feel cheaper than it is

This is where the game should start feeling “crisp.”

---

## phase 6 — testing and playthrough hardening
Run the build like a real player would.

### test categories
- fresh boot test
- new game test
- core loop test
- store coverage test
- long-session test
- input abuse/spam test
- save/load test
- transition test
- progression sanity test
- economy sanity test
- “what if I do weird things” test

Everything important should be tested with actual player-like behavior, not just direct script invocation.

---

## phase 7 — tutorial preparation after stability
Only after the build is verified:
- document the stabilized player flow
- write a one-day playthrough guide
- explain how to start, what to do, what systems matter, and how to meaningfully experience the current build

This tutorial should feel like:
“Here is how to actually play the game as it exists now.”

Not:
“Here is what the game might become.”

---

## specific audit questions that must be answered

### game flow
- what is the exact current intended loop?
- can a new player discover it without guessing?
- do early interactions train the rest of the session correctly?
- is there any point where the game stops giving meaningful direction?

### world
- can I move around without fighting controls or layout?
- are all accessible areas intentional?
- are blocked areas communicated?
- are there any places where geometry/collision feels unfinished?

### stores
- does each existing store meaningfully function?
- does each store have enough wiring to justify its presence?
- are store interactions consistent enough to learn?
- is any store mostly decorative while pretending not to be?

### economy
- does money/value actually drive decisions?
- can I earn and spend coherently?
- do prices/rewards feel sane enough for the current build?
- is there fake economy state anywhere?

### progression
- does anything advance in a way that matters?
- are there goals, unlocks, or milestones that are real and connected?
- does the session have momentum?
- is there anything that looks like progression but is not actually used?

### UI
- is the player ever missing key information?
- is the player shown too much irrelevant information?
- are prompts/contextual actions accurate?
- are menus honest reflections of available functionality?

### code
- can I trace the main loop in code without detective work?
- does each file do what its name suggests?
- are signals and events obvious?
- are there duplicate implementations of the same concept?
- does the code invite bugs because of confusion?

### stability
- what are the top crash/softlock risks?
- what states are least trustworthy?
- what actions break sequence assumptions?
- what must be hardened before a one-day playthrough?

---

## quality bar for completion

This pass is complete when:

### structural
- no major dangling systems remain in active player-facing areas
- no major dead code confusion remains around core systems
- important scene/script/data wiring is understood and cleaned up

### functional
- all intended current core flows work end to end
- no major fake systems remain exposed
- no obvious broken interactions remain in the main play path

### experiential
- the build feels coherent for a one-day play session
- the player can understand what to do
- the game responds smoothly enough to feel trustworthy
- prototype grime is materially reduced

### technical
- code is materially easier to read and maintain
- state ownership is clearer
- the test checklist exists and passes
- the repo feels like a real project, not a pile of experiments

---

## acceptance criteria

### repo / codebase
- critical files, scenes, and systems are mapped and understandable
- dead/unused/dangling code is removed or clearly fenced
- duplicated logic is reduced where it creates confusion
- names and file organization better reflect actual responsibilities
- core systems are easier to trace and debug

### connectivity
- menus, scenes, stores, data, UI, economy, and progression are actually wired together
- no core player-facing UI implies behavior that does not exist
- no important data dependencies are missing or silently broken
- no core flow depends on hidden fragile setup

### game quality
- game boots and flows cleanly
- interactions are smooth enough for sustained play
- no major softlocks/blockers remain in the one-day play path
- current content is stable enough to support real testing by me

### testing
- structured audit/test checklist exists
- critical path tests pass
- regression checks on major systems pass
- one-day playthrough readiness is explicitly verified, not assumed

### post-audit handoff
- game is ready for my one-day playthrough
- then a final tutorial can be written based on the actual audited build

---

## preferred implementation style

- favor clean, direct fixes over broad rewrites
- keep the current intended architecture where it is sound
- simplify where architecture drift created confusion
- remove junk instead of layering abstraction on top of junk
- keep comments high-value and sparse
- leave the code in a state that feels calm, obvious, and trustworthy
- validate each major cleanup/fix with an end-to-end check, not just local confidence

---

## validation loop requirement

Every major audit/fix batch should include a validation loop:

1. identify the intended behavior
2. identify the actual current behavior
3. trace the full path end to end
4. fix the root cause, not just visible symptom
5. verify the connected systems still align
6. confirm there is a single clear source of truth
7. run focused regression checks around the touched area
8. update the audit notes / checklist
9. only then move on

No “looks right probably.”

---

## final note

The spirit of this pass is:

**Make Mallcore Sim honest.**

Make it so every visible piece earns its place.  
Make it so the repo makes sense.  
Make it so the game holds together.  
Make it so I can actually sit down for a day and play the thing instead of interpreting a prototype.

No new toys.  
No ambition creep.  
Just a ruthless, comprehensive audit and cleanup so the current game becomes real enough to trust.

# Shelf Life — Next Phase Brain Dump
## Phase Goal: Stabilize the First-Day Loop, Improve the Visual Readability, and Add Real Game Regression Testing
The current build is promising because the game loop is actually starting to exist:
- Player starts Day 1
- Vic/tutorial content appears
- Customer/register task exists
- Inventory/back room/shelf tasks exist
- Money, day/time, store stats, objective HUD, and interaction prompts exist
- The store space is navigable enough to begin testing the gameplay
But every pass is also breaking something:
- Tutorial text duplicates.
- Objective text duplicates.
- HUD panels fight each other.
- Some UI is too dim to read.
- Some state updates appear to fire more than once.
- Modal layering is messy.
- The store still visually reads like a gray/brown prototype blockout.
- Agent passes are producing churn instead of obvious forward progress.
This phase should do two things at the same time:
1. Stabilize and clean up the actual first-day gameplay experience.
2. Add real automated game testing in CI so we stop rediscovering the same bugs manually.
This is not a “make the whole game bigger” phase.
This is a “make the first 10 minutes reliable, testable, and less ugly” phase.
Do not add new major systems unless required to stabilize the first-day flow.
Do not add more economy depth yet.
Do not add more customer complexity yet.
Do not add new day types yet.
Do not keep patching visible symptoms without adding tests that would catch the regression next time.
---
# Core Problem
The build has crossed into the danger zone where enough things are wired that changes feel real, but the game does not yet have enough guardrails to prevent regressions.
The player-facing symptoms are obvious:
- “First clock-in...” appears twice.
- “Talk to the customer at the register.” appears twice.
- A tutorial popup, a letter, HUD objectives, bottom task text, and right panel are all competing.
- Some panels are too large, too empty, or too low-contrast.
- The store looks mechanically functional but visually unintentional.
The technical issue underneath is probably that multiple managers/UI scripts are independently pushing text and state instead of rendering from a single source of truth.
This phase needs to fix that and then lock it down with automated tests.
---
# Non-Negotiable Phase Rules
## Rule 1 — No Duplicate Messages
A given tutorial beat, milestone, unlock, or objective should only display once in its intended surface.
Current bad examples:
- “First clock-in. Vic walked you through the register...” renders twice in the same modal.
- “Talk to the customer at the register.” appears twice in the bottom task area.
- The same unlock/info can appear in both a modal and the side panel without clear purpose.
Fix this at the state/event layer.
Do not fix duplicates by trimming strings in the UI after the fact.
Do not add one-off “if text already exists” hacks in three different UI scripts.
There should be a single event/message/objective source of truth.
Add dedupe keys for:
- tutorial event id
- objective id
- modal id
- unlock id
- milestone id
- day/phase combination where needed
Acceptance:
- Starting Day 1 does not duplicate tutorial text.
- Restarting Day 1 does not duplicate tutorial text.
- Re-rendering the HUD does not duplicate objectives.
- Reopening/closing modals does not append duplicated content.
- Signal/listener reconnects do not cause doubled messages.
---
## Rule 2 — One Source of Truth for Objectives
Objectives should not be scattered across tutorial scripts, HUD scripts, interaction scripts, and task-feed append calls.
Create or clean up a single objective model.
Suggested shape:
```gdscript
ObjectiveState:
  id: String
  label: String
  status: String # locked | active | complete | hidden
  priority: int
  interaction_target_id: String
  completion_event_id: String
  visible_in_today_panel: bool
  visible_in_event_log: bool
  visible_as_interaction_prompt: bool

The HUD should render from objective state.

The game logic should update objective state.

The task/event log should record transitions, not continuously re-add the active objective.

Acceptance:

* Every objective has a stable id.
* Every objective has one lifecycle.
* UI renders from current objective state.
* Objective text is not appended every frame/tick.
* Each objective appears at most once per intended UI surface.
* Completing an objective does not leave ghost copies behind.

⸻

Rule 3 — UI Surfaces Need Clear Jobs

Right now the UI is trying to say everything everywhere. Give each surface a job.

Top Left

Money only.

Keep it readable.
No extra status spam here.

Top Center

Day/time only, plus rare milestone toast.

Milestone toasts should be short.
They are not for tutorial paragraphs.

Example:

Day 1 — 9:00 AM

Right Panel

Store status and today’s checklist.

This should answer:

* What day is it?
* What is the store state?
* What am I broadly doing today?

Suggested structure:

DAY 1 — OPENING
Store
On Shelves: 0
Back Room: 0
Customers: 0
Sold Today: 0
Today
• Help the first customer
• Check the back room delivery
• Stock Retro Games
• Close the day

The right panel should not be a giant empty black rectangle.
It should not duplicate the bottom-left log.
It should not show stale/hidden objectives as if they are current.

Bottom Left

Recent event log only.

Good:

Register access unlocked.
Customer served.
Delivery checked.
Retro Games shelf stocked.

Bad:

Talk to the customer at the register.
Talk to the customer at the register.
Check the back room delivery.
Stock the Retro Games shelf.
Close the day at the register.

The bottom-left area should not be the full objective list if the right panel already owns that job.

Bottom Right

Current interaction prompt only.

Example:

Talk to customer    E
Check delivery      E
Stock shelf         E
Close day           F4

This should be contextual and short.

Modal / Letter UI

Only for intentional pauses.

The Vic letter is a good idea.
The tutorial popup is fine too.
But they should not both fight for attention.

Modal priority matters.

Suggested modal priority:

1. Pause/menu/system modal
2. Letter/story modal
3. Tutorial/mechanical popup
4. Milestone toast
5. HUD

When a higher-priority modal is open:

* lower-priority blocking modals should queue
* interaction prompts should hide
* HUD can dim, but not become unreadable junk
* no popup should appear behind another popup

Acceptance:

* Only one blocking modal is active at a time.
* The player always knows what button/click closes the current modal.
* A queued popup displays after the current modal closes, if still relevant.
* No tutorial text appears behind the Vic letter.

⸻

First-Day Flow Target

The first-day loop should be boringly reliable before the game gets bigger.

1. Start Day 1

Player spawns in the store.

Visible:

* money
* day/time
* right-side Today panel
* one clear immediate objective

No duplicate popups.
No duplicate objective text.

Suggested first active objective:

Talk to the customer at the register.

2. Vic Intro

Show one intro surface.

Preferred:

* Vic letter appears first.
* Player presses E/click to close.
* Then the first active objective is clearly visible.

Do not show the “Showing the Ropes” popup and the Vic letter at the same time unless intentionally staged.

If both exist:

* letter first
* tutorial unlock popup after letter closes
* no duplicate text between them

3. Register Customer

Player walks to the register and interacts.

On completion:

* customer count updates exactly once
* sold today updates exactly once
* money updates exactly once
* objective completes exactly once
* event log shows one confirmation
* next objective activates: check back room delivery

4. Back Room Delivery

Player goes to the back room and checks delivery.

On completion:

* back room inventory increases exactly once
* objective completes exactly once
* event log shows one confirmation
* next objective activates: stock Retro Games shelf

5. Stock Shelf

Player stocks the shelf.

On completion:

* shelf inventory increases
* back room inventory decreases
* objective completes exactly once
* event log shows one confirmation
* next objective activates: close day at register

6. Close Day

Player closes the day.

On completion:

* day summary appears once
* rent/sales/profit are shown cleanly
* no duplicate summary modal
* day state is ready for Day 2 or end-of-slice depending on current scope

⸻

Required Visual Cleanup

The game does not need to look final yet, but it needs to look intentional.

Right now the store reads like:

* big brown floor
* gray walls
* floating signs
* dark panels
* placeholder counters/shelves

That is okay for a prototype, but this phase should make the first room readable.

Store Readability Goals

A new player should be able to identify:

* register
* customer/register area
* back room
* delivery area
* Retro Games shelf
* Used Games shelf
* entrance/exit
* current objective target

Required improvements:

* Better signage contrast.
* Cleaner shelf labels.
* Stronger register silhouette.
* Clearer back room marker.
* Slightly better lighting around interactables.
* Remove or reduce random colored block signs unless they mean something.
* Add subtle current-objective target highlighting.

Lighting

Current lighting is muddy.

Do a simple pass:

* brighten the room slightly
* use warmer light near the register
* use softer fill light across the floor
* avoid heavy global dim unless a modal is open
* make modal dimming strong enough to focus attention but not so dark the HUD/game becomes unreadable

Materials

Keep it simple:

* floor should look like one intentional material
* walls should be less dead-gray
* shelves/counters/register should separate visually from the floor
* interactable objects should have better contrast than background props

Objective Target Highlight

Add a subtle indicator to the current target.

Options:

* faint outline
* small floating marker
* glow
* floor marker
* small contextual label

Do not overdo it. This is not a mobile quest marker festival.
Just enough that the player does not wander around a boxy room guessing what is clickable.

Acceptance:

* The register is visually obvious.
* The back room is visually obvious.
* The current target is discoverable.
* Screenshots look like a deliberate prototype, not accidental garbage.

⸻

Required Architecture Cleanup

Add a Test-Friendly Gameplay Harness

Before we add CI testing, make the game testable.

Add a dev/test-only gameplay harness that can drive first-day state transitions without requiring physical player movement.

Suggested methods:

start_new_game()
start_day(day_number)
close_active_modal()
simulate_interaction(target_id)
complete_objective(objective_id)
get_current_day()
get_current_time()
get_money()
get_inventory_state()
get_customer_count()
get_sold_today()
get_active_objectives()
get_completed_objectives()
get_visible_objective_labels()
get_event_log()
get_open_modal_id()
get_open_modal_title()
get_open_modal_body()
get_modal_queue()
get_current_interaction_prompt()
get_current_interaction_target()
get_hud_view_model()

Important:
The harness may bypass walking/collision.
The harness may not bypass the real game state transitions.

This should not be a separate fake version of the game.
It should call the same managers and events that real gameplay uses.

Good:

simulate_interaction("register_customer")

calls the same interaction completion code the player would trigger by pressing E at the register.

Bad:

money += 50
objective = "check_delivery"

inside the test only.

⸻

Add Dev-Only Debug Visibility

Add a dev-only debug panel or dump command.

It should expose:

Current Day:
Current Time:
Current Phase:
Money:
Customers:
Sold Today:
Inventory On Shelves:
Inventory Back Room:
Active Objective:
Completed Objectives:
Unlocked Systems:
Open Modal:
Queued Modals:
Queued Messages:
Current Interaction Target:
Current Interaction Prompt:

This can be hidden behind a debug key or only enabled in test/dev builds.

Purpose:
When the UI duplicates something, we should know whether:

* state duplicated
* event emitted twice
* signal connected twice
* UI appended instead of rendering
* modal queue duplicated
* objective manager restarted incorrectly

Stop guessing.

⸻

Add Event Logging

Every important state transition should log once.

Example:

EVENT game_started
EVENT day_started day=1 time=09:00
EVENT modal_opened id=vic_day_1_letter
EVENT modal_closed id=vic_day_1_letter
EVENT objective_started id=talk_to_customer
EVENT interaction_available target=register_customer
EVENT interaction_completed target=register_customer
EVENT stat_changed money 500 -> 550
EVENT stat_changed customers 0 -> 1
EVENT objective_completed id=talk_to_customer
EVENT objective_started id=check_back_room_delivery

Acceptance:

* State changes are auditable.
* Duplicate UI issues can be traced to event duplication or render duplication.
* CI tests can assert event counts.

⸻

Automated Game Testing in CI

We are not using web.
Do not add Playwright.
Do not build a browser export test.
This is a native Godot project, so CI should run Godot-side tests.

The goal is to add real regression testing for the first-day gameplay loop.

Use a Godot test framework compatible with this repo.

Preferred options:

* GUT
* gdUnit4

Pick the one that is easiest to wire into the current Godot version and repo structure.

The point is not framework purity.
The point is that pull_request and main CI can run game tests and fail when the first-day loop breaks.

⸻

CI Deliverables

Add:

/tests/
  unit/
  integration/
  snapshots/
/test_harness/
  GameplayTestHarness.gd
/ci/
  run_godot_tests.sh
.github/workflows/game-ci.yml
TESTING.md

Names can vary if the repo has a convention already, but the concepts should exist.

⸻

CI Workflow Requirements

The CI workflow should run on:

* pull requests
* pushes to main

It should:

1. Check out the repo.
2. Install/use the expected Godot version.
3. Import/build enough project metadata if needed.
4. Run the Godot test suite headlessly.
5. Publish test output/logs as artifacts if tests fail.
6. Fail the PR if first-day regression tests fail.

Do not require manual editor steps.
Do not require local-only files.
Do not require a developer to visually inspect screenshots to know the build is broken.

Suggested workflow shape:

name: game-ci
on:
  pull_request:
  push:
    branches: [ main ]
jobs:
  godot-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Godot
        run: |
          ./ci/setup_godot.sh
      - name: Run Godot Tests
        run: |
          ./ci/run_godot_tests.sh
      - name: Upload Test Logs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: godot-test-logs
          path: |
            test-results/
            logs/

If the repo already has a preferred Godot action/container, use it.
Do not over-engineer the setup.

⸻

Required Automated Tests

Test 1 — Project Boots

Given the project
When CI opens the main scene in test/headless mode
Then the scene loads without script errors
And required managers exist:
- GameState
- ObjectiveManager
- TutorialManager
- InventoryManager
- CustomerManager
- ModalManager
- HUDController

Acceptance:

* Broken autoloads fail CI.
* Missing scene paths fail CI.
* Script parse errors fail CI.
* Missing required managers fail CI.

⸻

Test 2 — Day 1 Initial State

Given a fresh new game
When Day 1 starts
Then:
- day equals 1
- time equals 9:00 AM
- money equals configured starting money
- customers equals 0
- sold today equals 0
- shelf inventory equals expected starting value
- back room inventory equals expected starting value
- exactly one primary objective is active
- active objective is talk_to_customer
- no objective label appears twice
- no tutorial event appears twice
- no more than one blocking modal is open

This directly protects against the bugs shown in the screenshots.

⸻

Test 3 — Intro Modal Does Not Duplicate Text

Given a fresh Day 1 start
When the intro/tutorial content appears
Then:
- modal body does not contain duplicated paragraphs
- modal event id was emitted once
- modal opened once
- modal queue does not contain duplicate copies of the same modal

Also test:

When the modal is closed
And the HUD re-renders
Then the modal text is not appended anywhere else

And:

When Day 1 is restarted in the same process
Then intro text still appears only once
And signal/listener connections do not double-fire

This protects against the classic Godot bug where entering/restarting scenes reconnects signals and everything fires twice.

⸻

Test 4 — Objective Render Dedupe

Given Day 1 has started
When the HUD view model is generated
Then:
- active objective ids are unique
- visible objective labels are unique per surface
- bottom-left event log does not duplicate the active objective
- right panel Today list does not contain duplicate rows

This should test the HUD model, not pixels.

Good:

get_hud_view_model().right_panel.today_objectives

Bad:
Taking screenshots and OCR-ing them.

⸻

Test 5 — Day 1 Golden Path

This is the load-bearing test.

Given a fresh Day 1 start
When the player closes the intro
Then active objective is talk_to_customer
When the harness simulates interacting with register_customer
Then:
- talk_to_customer is complete
- money increases exactly once
- customers served increases exactly once
- sold today increases exactly once
- event log contains one customer-served event
- active objective becomes check_back_room_delivery
When the harness simulates interacting with back_room_delivery
Then:
- check_back_room_delivery is complete
- back room inventory increases exactly once
- event log contains one delivery-checked event
- active objective becomes stock_retro_games
When the harness simulates interacting with retro_games_shelf
Then:
- stock_retro_games is complete
- shelf inventory increases
- back room inventory decreases
- event log contains one shelf-stocked event
- active objective becomes close_day
When the harness simulates interacting with close_day_register
Then:
- close_day is complete
- day summary modal opens once
- final stats match expected values
- no duplicate modal is open

This is the test that should fail if future agent passes break the first day.

⸻

Test 6 — Modal Priority

Given a letter modal is open
When a tutorial unlock event fires
Then:
- the tutorial popup is queued
- it does not display behind the letter
- there is still only one blocking modal open
When the letter closes
Then:
- the queued tutorial popup may display if still relevant
- the modal queue does not duplicate it

Acceptance:

* No stacked blocking modals.
* No modal behind a modal.
* Interaction prompts hide while blocking modal is open.

⸻

Test 7 — Interaction Prompt Correctness

Given the active objective is talk_to_customer
When the player is not near the register/customer
Then the interaction prompt is empty or hidden
When the player/harness focuses register_customer
Then the interaction prompt is:
"Talk to the customer" with input "E"
When the interaction completes
Then the prompt clears or updates to the next valid target

Also test:

The prompt does not remain stuck on the previous target.
The prompt does not display while a blocking modal is open.

⸻

Test 8 — Stats Update Exactly Once

Given starting money is 500
When register_customer interaction completes once
Then money equals 550 or the configured expected value
And the money_changed event fired once
And customer count increased by one
And sold today increased by one

Also test:

When the same completed interaction is triggered again
Then it does not pay out twice unless explicitly designed to allow repeat customers.

This matters because duplicate signal firing can make the UI look okay while the sim quietly corrupts money/inventory.

⸻

Test 9 — HUD View Model Snapshot

Do not snapshot pixels yet.
Snapshot the HUD data model.

For each Day 1 phase, serialize:

{
  "money": 500,
  "day": 1,
  "time": "9:00 AM",
  "store_stats": {
    "on_shelves": 0,
    "back_room": 0,
    "customers": 0,
    "sold_today": 0
  },
  "active_objectives": ["talk_to_customer"],
  "completed_objectives": [],
  "event_log": [],
  "interaction_prompt": null,
  "modal": {
    "id": "vic_day_1_letter",
    "title": "Vic Harlow — Day 1",
    "body_hash": "..."
  }
}

Snapshots should be stable enough to catch accidental UI/state changes but not so brittle that copy edits become painful.

Use body hashes for long modal text if exact copy churn is expected.

Acceptance:

* Snapshot diffs are readable in CI output.
* A duplicate objective changes the snapshot and fails.
* A wrong active objective changes the snapshot and fails.
* A stuck modal changes the snapshot and fails.

⸻

Manual QA Checklist

Add this to TESTING.md.

Fresh Start QA

1. Start a new game.
2. Confirm money starts at intended value.
3. Confirm Day 1 / 9:00 AM is visible.
4. Confirm Vic intro appears once.
5. Confirm no duplicate text in modal.
6. Close intro.
7. Confirm only one active objective is shown.
8. Confirm bottom-left is not duplicating the full objective list.
9. Walk to customer/register.
10. Confirm interaction prompt appears once.
11. Press E.
12. Confirm money updates once.
13. Confirm customers/sold today update once.
14. Confirm next objective activates once.
15. Check delivery.
16. Confirm back room count updates once.
17. Stock shelf.
18. Confirm shelf/back room counts update correctly.
19. Close day.
20. Confirm summary appears once.

Regression Failure Rules

The phase is not done if:

* Any objective appears twice.
* Any modal text repeats.
* Multiple blocking overlays appear at once.
* HUD becomes unreadable.
* Interaction prompt remains for the wrong target.
* Money/stats update more than once per interaction.
* Restarting the day causes duplicate listeners/messages.
* The first-day golden path cannot be completed in the test harness.
* CI does not fail when one of these issues is intentionally introduced.

⸻

Visual Acceptance Criteria

This pass is not expected to make the game beautiful.

It is expected to make the game readable.

Done means:

* HUD is readable at normal gameplay resolution.
* Right panel looks intentional and useful.
* Bottom-left is an event log, not a duplicate objective dump.
* Bottom-right only shows the current interaction.
* Register/back room/shelves are visually identifiable.
* Current objective target is discoverable.
* Modals do not stack.
* The game no longer looks like six disconnected debug systems are rendering at once.

⸻

Testing Acceptance Criteria

This phase is not done unless CI protects the first-day loop.

Done means:

* Godot tests run in CI.
* CI fails on script/scene boot errors.
* CI fails on duplicated intro modal text.
* CI fails on duplicated objective labels.
* CI fails on stacked blocking modals.
* CI fails if Day 1 golden path breaks.
* CI fails if money/customer/inventory updates fire more than once.
* Test logs are uploaded on failure.
* TESTING.md explains how to run the same tests locally.

⸻

Agent Implementation Order

Step 1 — Inspect Current State Flow

Before changing anything, map the current flow:

* Where Day 1 starts
* Where objectives are created
* Where tutorial messages are emitted
* Where modals are opened
* Where HUD lists are rendered
* Where interactions complete
* Where money/inventory/customer stats update
* Where signals are connected

Write this down briefly in TESTING.md or a small implementation note.

Do not guess.

Step 2 — Add Event Logging

Add logging around current state transitions before refactoring.

This helps prove whether the duplicate bugs are from:

* duplicate state events
* duplicate signal connections
* duplicate render appends
* duplicate modal queue entries

Step 3 — Add Test Harness

Add the gameplay test harness.
Keep it dev/test-only.
It should call real managers.

Step 4 — Add Baseline Tests

Start with:

* project boot
* Day 1 initial state
* intro modal dedupe
* objective dedupe

Make these fail against current bugs if possible.
Then fix the bugs.

Step 5 — Fix Objective/Modal/HUD Source of Truth

Refactor only as much as required to make state/rendering clean.

Do not rewrite the entire game.
Do not add more systems.

Step 6 — Add Day 1 Golden Path Test

Once the harness works, add the full first-day test.

This becomes the main regression lock.

Step 7 — Visual Cleanup Pass

After state and tests are stable, do the visual cleanup:

* HUD contrast
* right panel structure
* bottom log/prompt cleanup
* signs/lighting/interactable clarity
* current target highlight

Step 8 — Final Validation

Run:

* automated tests locally
* CI workflow
* manual QA checklist

Capture any known issues in a short KNOWN_ISSUES.md or TESTING.md section.

⸻

What Not To Do

Do not use Playwright.
Do not add web export testing.
Do not use screenshots/OCR as the first testing strategy.
Do not test pixels before testing state.
Do not keep appending UI text directly from gameplay events.
Do not have multiple systems independently own objective text.
Do not add more gameplay depth until the first-day loop is stable.
Do not accept “works when I played it once” as done.

⸻

Final Definition of Done

The next phase is complete when:

1. The first-day gameplay loop works from start to close-day.
2. The intro/tutorial content appears once.
3. Objectives do not duplicate.
4. Modals do not stack.
5. HUD surfaces have clear jobs.
6. Store visuals are readable enough to understand the space.
7. Godot-side automated tests run in CI.
8. CI protects the first-day golden path.
9. Future agent passes cannot casually re-break these exact problems without a failing test.

The goal is to get out of the loop where every pass “fixes” something visually while quietly breaking state somewhere else.

Lock the loop down first.
Then make it better.
# Shelf Life — Visual Pass Brain Dump
## Phase Goal: Build a Real HUD, Notification System, and First-Room Visual Baseline
The play loop is stable enough now that the next phase should be a **visual and UI systems pass**.
This is not a new gameplay phase.
This is not the time to add more store systems, more customer behavior, or more day logic.
The goal is to make the current stable loop look and feel intentional:
- HUD elements should not overlap.
- Notices should not fight the side panel.
- Store stats should not float randomly behind/above panels.
- Notifications should have one system and one placement.
- The objective list should be readable.
- The store should look like a deliberately stylized prototype, not a debug room with UI stuck on top.
Right now the game is becoming playable, but the screen composition is still messy.
---
# Current Visual Problems
From the latest screenshots:
## 1. Top-center notice overlaps with day/time
The “Showing the Ropes” card is centered near the top, but the `Day 1 — 9:00 AM` text is also top-center. They visually collide.
Problem:
```text
Day 1 — 9:00 AM
[ Showing the Ropes notification ]

This makes both elements feel accidental.

2. Right sidebar overlaps with top-right stat text

The stats:

On Shelves: 0
Back Room: 0
Cust: 0
Sold Today: 0

appear above/behind the right panel instead of inside it.

That should never happen. If the side panel exists, it owns those stats.

3. Notification and side panel fight for attention

The right sidebar sometimes shows:

Unlocked: Register Access

while the top-center notification also explains the same thing.

This creates two competing notification systems.

4. Bottom HUD feels like debug text

The bottom objective area is better than before, but still feels like a raw list. It needs hierarchy:

* current objective
* upcoming objectives
* completed objectives
* recent event log

Those should not all look like the same kind of text.

5. Side panel is too tall and empty

The right panel is a giant black slab. It has useful potential, but currently it has too much empty space and not enough structure.

6. Store visual baseline is still weak

The world is readable enough to move around, but it still needs:

* stronger register area
* better shelf identity
* improved signage
* more intentional lighting
* clearer interactable targets
* less “large empty box” feeling

⸻

Phase Objective

Create a coherent visual language for the current game.

By the end of this phase:

* There is a proper HUD layout.
* There is one notification/toast system.
* The right panel owns store stats and day checklist.
* Top-center only owns day/time unless a modal explicitly replaces it.
* Bottom HUD is cleaned up and reduced.
* Interactable areas are visually readable.
* Current objective target is obvious.
* The first store room looks like an intentional prototype.

⸻

HUD Layout Rules

Rule 1 — Every HUD Region Has One Job

Do not let multiple systems render into the same part of the screen.

Use this layout:

┌──────────────────────────────────────────────────────────────┐
│ $500.00                         Day 1 — 9:00 AM              │
│                                                              │
│                                                ┌───────────┐ │
│                                                │ Store HUD │ │
│                                                │ + Today   │ │
│                                                └───────────┘ │
│                                                              │
│                                                              │
│                                                              │
│                                                              │
│ Event Log                                      Action Prompt │
└──────────────────────────────────────────────────────────────┘

Each region:

Region	Purpose
Top-left	Money only
Top-center	Day/time only
Top-right/right panel	Store stats + today checklist
Center/top-center	Toast notifications only when they do not overlap day/time
Bottom-left	Recent event log
Bottom-center	Optional current objective, only if not redundant
Bottom-right	Current interaction prompt

⸻

Top HUD

Money

Top-left should stay simple:

$500.00

Rules:

* Always readable.
* No extra labels unless needed.
* No animation unless money changes.
* On money change, use a subtle pop or delta text:
    * +$50
    * -$50 rent

Do not spam the event log and HUD with the same money update unless useful.

Day / Time

Top-center owns only:

Day 1 — 9:00 AM

Rules:

* Nothing should overlap it.
* Notifications should not render directly underneath it if they visually collide.
* In-world signs should not intersect it from the camera view.

If a top notification appears, either:

* place it below the day/time with enough margin, or
* move notifications to the upper-left/center-left, or
* make the day/time temporarily part of the notification stack.

⸻

Right Panel Redesign

The right panel should own:

* store stats
* today’s goal
* active checklist
* latest unlock, if needed

It should not be a giant empty slab.

Suggested Structure

DAY 1 — OPENING
Store
Shelves       0
Back Room     0
Customers     0
Sold Today    0
Today
● Help the first customer
○ Check the back room delivery
○ Stock the Retro Games shelf
○ Close the day at the register

Rules

* Move On Shelves, Back Room, Cust, and Sold Today into this panel.
* Delete the floating top-right stat text.
* Do not render stats both inside and outside the panel.
* Reduce panel height if it has little content.
* Give the panel padding and spacing.
* Use one accent color for headers.
* Current objective should be visibly highlighted.
* Future objectives should be muted but readable.
* Completed objectives should show a check or strikethrough, not disappear unless that feels better.

Right Panel Size

Current panel is too tall and empty.

Target:

* Width: roughly 260–320 px equivalent at 1080p.
* Height: content-driven, not full screen.
* Anchor: top-right, below the top HUD.
* Margin: enough that it does not touch the screen edge or stat text.

⸻

Notification / Toast System

There should be exactly one notification system.

Current issue:

* Top-center card says “Showing the Ropes.”
* Right panel says “Unlocked: Register Access.”
* Event log may also say the same thing.

That is three surfaces for one event. UI confetti, but sad.

Notification Types

Define notification types:

NotificationType:
  TOAST
  UNLOCK
  OBJECTIVE_CHANGED
  WARNING
  DAY_SUMMARY
  MODAL

Placement Rules

Toasts

Short-lived, non-blocking.

Examples:

Register access unlocked.
Customer served.
Delivery checked.

Placement:

* top-right above/right panel, or
* upper-center below day/time with safe margin

Duration:

* 2–4 seconds

Rules:

* Do not block movement.
* Do not require Continue.
* Do not overlap day/time.
* Do not overlap the side panel.
* Do not duplicate in the right panel unless it updates actual persistent state.

Unlock Notifications

Unlocks should be toasts, not side-panel body text.

Example:

Unlocked: Register Access

Show once as a toast.
Then disappear.

Do not leave it sitting in the right panel forever unless the panel has an explicit “Recent” section.

Objective Changed

Objective changes can update the right panel and optionally create a subtle toast:

New objective: Check the back room delivery.

But avoid showing this if the right panel update is already obvious.

Blocking Modals

Reserved for:

* Vic letter
* day summary
* pause menu
* major story beat

Do not use blocking modals for routine tutorial text.

⸻

Replace “Showing the Ropes” Treatment

The current “Showing the Ropes” card is visually improved but still too prominent for a routine onboarding hint.

New Treatment

Convert it from a blocking-looking card to a toast or compact tutorial hint.

Current:

Showing the Ropes
First clock-in. Vic walked you through the register and now expects you to ring sales without supervision.

Better as a toast:

Register access unlocked.
Ring up the waiting customer at the counter.

Or as a right-panel objective detail:

Current
Help the waiting customer at the register.

If the title “Showing the Ropes” is kept, use it as a one-time tutorial toast, not a large center card.

Acceptance

* It does not overlap day/time.
* It does not require a click.
* It does not duplicate the side panel.
* It disappears automatically.
* It is logged once if the event log needs it.

⸻

Bottom HUD Cleanup

The bottom strip should not feel like a debug console.

Bottom-left: Event Log

Use only recent events.

Examples:

Register access unlocked.
Customer served.
Delivery checked.

Rules:

* Max 3–4 visible lines.
* Fade older lines.
* Do not show future objectives here.
* Do not show the full checklist here.
* Do not duplicate the current objective unless it just changed.

Bottom-right: Interaction Prompt

Only show the current action:

Talk to the customer    E

Rules:

* Prompt should be large enough to notice.
* Prompt should hide when no interaction is available.
* Prompt should hide during blocking modals.
* Prompt should update immediately when target changes.
* Prompt should not share space with objective list.

Bottom Border / Bar

The orange line is useful, but it currently makes the whole bottom feel like a permanent console.

Consider:

* thinner divider
* smaller background panel
* only show bottom bar when needed
* separate event log and prompt without a full-width heavy bar

⸻

Objective Presentation

Use one persistent checklist in the right panel.

Objective States

Visual states:

● Active objective
✓ Complete objective
○ Upcoming objective

Example:

Today
● Help the first customer
○ Check the back room delivery
○ Stock the Retro Games shelf
○ Close the day at the register

After customer:

Today
✓ Help the first customer
● Check the back room delivery
○ Stock the Retro Games shelf
○ Close the day at the register

Rules:

* Current objective should be bright.
* Completed objective should be muted but recognizable.
* Future objective should be dim, but not invisible.
* Objective text should not appear in multiple places unless each place has a distinct purpose.

⸻

Visual Style Direction

Keep the current low-poly/prototype look, but make it intentional.

The target is not AAA.
The target is “stylized indie shop sim prototype that knows what it is.”

Palette

Current palette:

* dark brown / black panels
* gold-orange accent
* off-white text
* muted gray walls
* warm wood floor
* green register screen

Keep the general direction, but standardize it.

Suggested UI palette:

Panel background: near-black with 75–85% opacity
Panel border: muted amber
Primary text: warm off-white
Secondary text: muted tan/gray
Accent: amber/gold
Success: soft green
Warning: muted orange

Avoid:

* black text on transparent black
* gray text on gray wall
* neon colors unless intentionally used for signs/screens
* random colored squares that do not communicate anything

⸻

Store Visual Improvement Pass

Register Area

This is the most important area right now.

Improve:

* checkout counter silhouette
* register shape
* customer placement
* “Checkout” sign readability
* interaction zone clarity
* lighting around register

The register should be obvious from spawn.

Add:

* small counter mat
* subtle glow on register screen
* better sign placement
* customer marker/shape that reads from distance
* perhaps a queue marker on the floor

Checkout Sign

The giant sign previously collided with the HUD. It is better now, but still needs care.

Rules:

* In-world signs must not intersect HUD.
* Sign should be readable without dominating the camera.
* Move it deeper into the scene or lower it.
* Avoid top-screen cropping.

Shelves

Shelves need stronger identities.

For each shelf:

* readable label
* distinct section sign
* maybe a few placeholder box/game shapes
* subtle color coding only if meaningful

Current signs:

* Used Games
* Retro Games

Good direction, but make them cleaner and less tiny/glowy.

Back Room

Back room needs to read as a destination.

Add:

* clearer doorway
* sign or placard
* boxes visible near entrance
* warmer/cooler light contrast
* objective marker when active

Empty Floor Problem

The center floor is huge and empty.

Options:

* add a few low-poly display tables
* add floor mats
* add queue markers
* add subtle pathing lines
* add a small promo stand
* add cardboard boxes near delivery path

Do not clutter it yet.
Just break up the bowling-alley emptiness.

⸻

Interactable Target Highlighting

The current objective should have a subtle world-space cue.

Options:

* soft outline
* small floating marker
* floor circle
* gentle glow
* sign pulse
* interaction icon

Rules:

* only highlight the active target
* do not use giant quest markers
* hide/reduce highlight after player discovers the target
* highlight should not fight with UI notifications

Example:

Active objective: Talk to customer
Target highlight: register/customer area
Prompt appears when close: Talk to customer    E

⸻

UI System Architecture

Implement HUD through view models, not random node updates.

Suggested View Models

HudViewModel:
  money
  day
  time
  store_stats
  today_objectives
  event_log
  interaction_prompt
  active_toasts
  blocking_modal
ToastViewModel:
  id
  type
  title
  body
  duration
  priority
  created_at
ObjectiveViewModel:
  id
  label
  state # active | complete | upcoming | hidden
InteractionPromptViewModel:
  label
  input
  target_id
  visible

Rules:

* UI renders from models.
* Gameplay updates state.
* State emits events.
* HUD consumes state/events.
* No gameplay script should directly append text into HUD labels.

⸻

Notification Queue Rules

Add a small queue manager.

Rules:

* Toasts queue by priority.
* Duplicate toast ids are ignored within a cooldown window.
* Max visible toasts: 1–2.
* Blocking modals suppress toasts or delay them.
* Toasts should not appear behind modals.
* Unlock/objective notifications should have stable ids.

Example dedupe ids:

unlock_register_access
objective_talk_to_customer_started
customer_served_day1_first
delivery_checked_day1

Acceptance:

* “Unlocked: Register Access” appears once.
* It does not remain forever in the side panel.
* It does not appear at the same time as an equivalent top card.
* It does not duplicate on scene reload.

⸻

Testing Requirements

Now that play is stable, add visual/HUD regression tests at the data level.

Do not start with pixel-perfect screenshot tests.
Start with HUD view model tests.

Test 1 — No HUD Region Overlap by Ownership

Given Day 1 is active
Then store stats are rendered only in the right panel model
And not in floating top-right labels

Test 2 — Notification Does Not Duplicate

When register access unlocks
Then exactly one toast/event is created with id unlock_register_access
And the right panel does not also render it as permanent body text unless explicitly configured

Test 3 — Day Time and Toast Do Not Share Anchor

Given a toast is active
Then the toast anchor is not the same as the day/time anchor
And the toast has configured margin below or away from day/time

Test 4 — Bottom HUD Does Not Contain Full Checklist

Given Day 1 has four objectives
Then the right panel checklist contains the objectives
And the bottom-left event log does not contain future objective rows

Test 5 — Interaction Prompt Only Shows Current Target

Given player is near the customer
Then bottom-right prompt is Talk to the customer / E
Given player moves away
Then prompt clears
Given blocking modal opens
Then prompt hides

Test 6 — HUD Snapshot

Snapshot the HUD model for:

* spawn
* register unlock toast visible
* customer interaction available
* customer served
* delivery objective active

Snapshot should include:

{
  "top_left": {
    "money": "$500.00"
  },
  "top_center": {
    "day_time": "Day 1 — 9:00 AM"
  },
  "right_panel": {
    "stats": {
      "on_shelves": 0,
      "back_room": 0,
      "customers": 0,
      "sold_today": 0
    },
    "objectives": [
      {
        "id": "talk_to_customer",
        "state": "active"
      }
    ]
  },
  "bottom_left": {
    "event_log": []
  },
  "bottom_right": {
    "prompt": {
      "label": "Talk to the customer",
      "input": "E"
    }
  },
  "toasts": [
    {
      "id": "unlock_register_access"
    }
  ]
}

The exact structure can vary. The important part is that the HUD state is testable.

⸻

Manual QA Checklist

Run this after the visual pass.

Spawn

* Money is readable.
* Day/time is readable.
* No top-center card overlaps day/time.
* Store stats are inside the right panel only.
* Right panel does not cover other HUD text.
* Bottom-left is not a full objective dump.
* Bottom-right shows only the current interaction when relevant.

Notification

* Register access unlock appears once.
* Notification does not overlap day/time.
* Notification does not overlap right panel.
* Notification disappears automatically.
* Notification does not also persist as duplicate text elsewhere.

Objective Flow

* Current objective is clear.
* Future objectives are readable but muted.
* Completed objective has a distinct state.
* Objective text does not duplicate across HUD regions.

Register Area

* Register is obvious from spawn.
* Customer/register interaction target is clear.
* Prompt appears when near/looking at customer.
* Prompt disappears when not relevant.

General Visual

* Store is brighter and less muddy.
* Signs are readable.
* Shelves are visually distinct.
* Back room is identifiable.
* Empty floor is slightly broken up.
* Current objective target is discoverable.

⸻

Implementation Order

Step 1 — Define HUD Region Ownership

Before moving pixels, document what each HUD region owns.

Then delete/move any UI element violating that ownership.

Priority fixes:

1. Move top-right stats into the right panel.
2. Stop right panel from showing one-off unlock notices permanently.
3. Move top-center notifications away from day/time.
4. Convert bottom-left into event log only.

Step 2 — Build Toast/Notification Manager

Create one notification path.

Requirements:

* stable ids
* dedupe
* queue
* timeout
* priority
* no overlap with modals
* one anchor location

Step 3 — Refactor Right Panel

Make it the persistent state panel:

* store stats
* today checklist
* current objective highlight

Do not use it as a notification dump.

Step 4 — Clean Bottom HUD

Make bottom-left recent events.
Make bottom-right current interaction.
Remove future objectives from bottom-left.

Step 5 — Add HUD View Model Tests

Before further visual tuning, add tests for:

* no duplicate stats
* no duplicate notifications
* no bottom checklist dump
* prompt visibility
* HUD snapshot

Step 6 — Store Visual Pass

Improve:

* register
* shelves
* signs
* back room
* lighting
* interactable highlight
* floor emptiness

Step 7 — Final Screenshot Review

Compare before/after screenshots.

The screen should now read:

* top = global status
* right = store/day state
* bottom = current action/events
* world = readable destinations

No region should feel like debug leftovers.

⸻

Definition of Done

This visual pass is done when:

* Top-center day/time does not overlap notifications.
* Top-right stats are removed or moved fully into the right panel.
* Right panel has a clear layout and no giant empty slab feel.
* Unlocks/toasts appear through one notification system.
* Notifications do not duplicate across HUD surfaces.
* Bottom-left is an event log, not an objective dump.
* Bottom-right is only the current interaction prompt.
* Current objective is clearly visible once.
* Register/customer area is readable from spawn.
* Shelves and back room are identifiable.
* Store lighting/materials are improved enough that the room looks intentional.
* HUD view model tests prevent the obvious overlap/duplication regressions.

The goal is not “final art.”

The goal is that the game stops looking like the HUD was installed by five raccoons with separate Jira tickets.

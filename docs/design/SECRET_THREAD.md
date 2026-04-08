# Secret Meta-Narrative Thread

## Overview

The game contains a hidden, optional secondary layer beneath the cozy retail surface. It is not the main game. It does not change the core loop. Most players may never notice it. Those who do should find it weird, funny, memorable, and worth replaying for.

---

## Purpose

- Create the lingering feeling that "something is off" about the mall
- Reward curious players who poke at environmental details, read emails closely, and notice pattern breaks
- Provide multiple 100% completion endings that recontextualize the experience
- Generate conversation-worthy moments ("wait, did you get the OTHER ending?")
- Add replay value without adding mandatory playtime

## Tone

- **Dry and deadpan.** Clues are delivered without fanfare. A weird email arrives like any normal email. An odd customer behaves just slightly off.
- **Suspicious, not sinister.** The player should think "huh, that's weird" — not "I'm in danger."
- **Funny in retrospect.** Clues should be the kind of thing players screenshot and share.
- **Tonally consistent.** The mall is cozy. The thread is weird. These coexist. Think: a Coen Brothers subplot happening in the background of a Hallmark movie.

## Non-Interference Rules

The hidden thread must NEVER:

1. Block or gate any core progression milestone (store unlocks, reputation tiers, supplier upgrades)
2. Modify the core gameplay loop (stocking, pricing, selling, customer management)
3. Affect economy balance (no meaningful economic advantage or disadvantage from thread engagement)
4. Add mandatory playtime to the 30-hour core completion target
5. Create anxiety or urgency that violates the "cozy simulation" pillar
6. Require engagement for standard 100% completion criteria
7. Appear in the critical path for any development milestone (M1–M7)

## Clue Cadence

- **Days 1–10**: Zero or near-zero clues. The player learns the game. The mall feels normal.
- **Days 10–20**: 1-2 ambient oddities. An item in the stockroom that doesn't match any catalog. An email with unusual phrasing. Easy to miss.
- **Days 20–40**: If the player has noticed earlier clues, the frequency increases slightly. If not, the thread stays dormant. The thread adapts to attention.
- **Days 40+**: If engaged, clues become more pointed. Suspicious customer behavior, pattern anomalies in financial data, recurring oddities. Still deniable, still optional.
- **Near 100%**: If the thread has escalated, it reaches a decision point before the completion ending.

The thread should feel like it was always there, noticed or not.

## Guaranteed "Something Weird" Moments

At minimum, the game must contain these ambient moments that every player might encounter (even if they don't connect them):

1. A delivery arrives with one extra item not on the order (happens once, early-mid game)
2. A customer asks for a specific item by a name the game doesn't use — then leaves (happens once)
3. An email arrives that seems misaddressed or oddly formal (happens once)
4. A financial summary shows a tiny discrepancy that auto-corrects by next day (happens once)
5. A storefront in the mall that's always "under renovation" with occasional sounds (environmental, persistent)

These are flavor. They establish that the world has texture. They are not actionable unless the player decides to investigate.

## Optional Interaction Categories

If the player actively engages, these are the types of interaction they might encounter:

### Passive discovery
- Reading environmental details (notes, signs, discrepancies)
- Noticing customer behavior patterns
- Observing inventory anomalies

### Active investigation
- Responding to unusual messages
- Inspecting items that don't fit
- Tracking recurring patterns across days
- Visiting the "under renovation" storefront at specific times

### Participation (deepens involvement)
- Fulfilling specific requests from unusual contacts
- Storing or moving flagged items
- Making choices in response to suspicious requests

The player's depth of engagement determines their ending.

## Ending Outcomes at 100% Completion

### 1. Normal — "Mall Empire" Ending
- **Trigger**: Zero or minimal thread interaction
- **Tone**: Celebratory. You built a retail empire. The mall thrives.
- **Feel**: Satisfying, complete, earned

### 2. Questioned — "Something's Off" Ending
- **Trigger**: Moderate clue awareness (noticed things, maybe investigated lightly) but did not deeply participate
- **Tone**: The 100% celebration is slightly off. Background figures exchange looks. An official-looking person appears and asks a few pointed questions, then leaves.
- **Feel**: Unsettling aftertaste. "What was that about?" Motivates replay.

### 3. Takedown — "Raid" Ending
- **Trigger**: Deep engagement — actively responded to suspicious contacts, stored flagged items, made choices that built a clear trail of participation
- **Tone**: Dark comedy. The 100% celebration is interrupted. The dramatic irony: the player's empire was real, but so was the other thing.
- **Feel**: Memorable, earned, makes the player want to tell someone about it

## Hidden State Model

Tracked in save data as a lightweight state object:

- **awareness_score** (0–100): Increments on clue examination. Passive — just looking.
- **participation_score** (0–100): Increments on active engagement. Choosing to do something.
- **thread_phase**: `dormant` → `seeded` → `active` → `escalated`. Controls clue delivery intensity.
- **clues_found**: List of discovered clue IDs.
- **responses**: Map of clue_id → player response type.

Ending determination at 100% completion:
- Low awareness + low participation → Normal
- Moderate awareness + low participation → Questioned
- High awareness + high participation → Takedown

Thresholds should be tunable in config data.

## System Attachment Points

The thread layers onto existing systems — it does not create new ones:

| System | How the thread attaches |
|---|---|
| **Save system** | Adds `secret_state` object (~1KB) to save data |
| **Event system** | Some events have optional hidden variants |
| **Customer AI** | Some customer archetypes have hidden behavior flags |
| **Inventory** | Some items have hidden metadata (e.g., `flagged: true`) |
| **Content data** | Optional `hidden_thread` boolean on relevant content entries |
| **UI** | 3 ending screen variants. No in-game thread UI. |
| **Progression** | Ending selection logic runs at 100% completion. No earlier interaction. |

## Explicitly Out of Scope

- Full narrative script (this is a framework doc, not a content doc)
- Individual clue definitions (created during content authoring, post-M4)
- Specific dialogue for ending sequences (created during M7 polish)
- Any gameplay mechanic that exists solely for the secret thread
- Any system that tracks clue progress in the UI (the thread is invisible)
- Any interaction that forces the player to acknowledge the thread
- Any development work before M4 (core systems must exist first)

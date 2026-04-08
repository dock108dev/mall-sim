# Secret Meta-Narrative Planning Brief

This is NOT the full design document for the hidden thread. This is the planning-level brief that defines scope, constraints, and how the secret meta-narrative should be planned and built later.

---

## Purpose of the Hidden Thread

The game has an optional, hidden secondary layer running beneath the cozy retail surface. It creates a feeling that "something is off" about the mall — not horror, not crime thriller, but dry, weird, suspicious, and memorable. Players who never engage with it finish the game normally. Players who poke at it discover a thread that recontextualizes some of what they've been doing.

**It is not**: a second game, a branching narrative adventure, a crime sim, or a required path.

**It is**: environmental seasoning that rewards curiosity and creates replay value, memorable moments, and conversation-worthy endings.

---

## Tone Constraints

- **Dry and deadpan.** The weirdness is presented without fanfare. A strange email arrives like any normal email. An odd customer behaves just slightly off. A stockroom delivery has something that doesn't belong.
- **Suspicious, not sinister.** The player should think "huh, that's weird" and "wait, was that on purpose?" — not "I'm in danger."
- **Funny in retrospect.** The clues should be the kind of thing players screenshot and post. Memorable through absurdity, not through horror.
- **Tonally consistent with the main game.** The mall is cozy. The thread is weird. These coexist. Think: a weird indie film happening in the background of a Hallmark movie.

---

## Player Experience Constraints

1. **No player should feel punished for ignoring it.** The normal game is complete, satisfying, and reachable without any clue interaction.
2. **No player should feel forced to engage.** Clues are discoverable but never gated or mandatory.
3. **Engagement should feel like a choice, not an accident.** The player consciously decides to dig deeper.
4. **The thread should be ambiguous until late.** Early clues should feel like flavor text or bugs. Only accumulation makes the pattern visible.
5. **It must not create anxiety.** This is a cozy sim. The hidden thread is curious and unsettling, not stressful. Players should smile and say "what the hell?" not alt-F4.

---

## What It Must Not Interfere With

1. **Core gameplay loop.** Stocking, pricing, selling, customer management — these are untouched by the thread.
2. **Progression system.** Store unlocks, reputation, supplier tiers — all function identically regardless of thread engagement.
3. **30-hour core completion.** The thread adds no mandatory time.
4. **100% completion base criteria.** Standard 100% completion (all stores maxed, all items seen, all milestones) does not require thread engagement.
5. **Economy balance.** The thread should not provide meaningful economic advantage or disadvantage.
6. **Performance.** The hidden state tracking is lightweight — flags and counters, not complex systems.

---

## Ending Outcomes

### Normal 100% Secret Ending
- **Trigger**: Player reaches 100% completion with zero or minimal thread engagement
- **Tone**: Celebratory. "You built a retail empire. The mall thrives. You retire as a legend."
- **Feel**: Satisfying, complete, earned

### Questioned / Suspicious Ending
- **Trigger**: Player found a moderate number of clues (enough to raise flags) but didn't dig deep or respond to suspicious requests
- **Tone**: Unsettling. The celebration is slightly off. Background characters exchange looks. An investigator appears but can't prove anything.
- **Feel**: "Wait, what was that about?" — motivates replay to look harder

### Arrest / Raid Ending
- **Trigger**: Player actively engaged with the thread — responded to suspicious requests, interacted with hidden contacts, stored or moved flagged items, made choices that built a clear trail
- **Tone**: Dark comedy. The raid happens during the 100% celebration. Dramatic irony: the player's empire was real, but so was the other thing.
- **Feel**: Memorable, earned, makes the player want to tell someone about it

### Design note on ending triggers
- Endings should be determined by a **hidden suspicion/awareness score** tracked in save state
- The score increments when the player interacts with clues in specific ways
- Different response types (ignore, investigate, participate) produce different score trajectories
- Thresholds for each ending should be tunable in config data

---

## Clue Delivery Categories

Clues are integrated into existing game systems, not bolted on as a separate layer:

### 1. Environmental clues
- Objects in the stockroom that don't match any catalog
- Graffiti or notes in the mall that change subtly over time
- A store that's always "under renovation" with suspicious activity
- Items on shelves that have wrong labels or weird descriptions

### 2. Communication clues
- Emails or messages from unknown senders with odd requests
- Customer dialogue that references things the player hasn't done
- Notes left in returned rental items or traded-in games
- Supplier communications with unusual language or requests

### 3. Customer behavior clues
- A recurring customer who never buys anything but always browses the same section
- A customer who asks for items that don't exist in the game's catalog
- Group visits that seem coordinated but claim to be strangers
- A customer who pays exact change for a high-value item without negotiating

### 4. Inventory/economy clues
- Stock deliveries with an extra item not on the order
- Items whose market value shifts in patterns that don't match normal trends
- Cash register totals that are slightly off in specific ways
- Specific items that particular customers always request

### 5. Temporal/event clues
- Events that only happen at specific times or on specific days
- Patterns visible only when reviewing financial summaries across multiple days
- Seasonal anomalies (a holiday event that triggers out of season)

---

## Hidden State / Suspicion Score Concept

The thread is tracked by a lightweight state object in the save file:

```
secret_state: {
  awareness_score: int,       // 0-100, how much the player has noticed
  participation_score: int,   // 0-100, how much the player has engaged
  clues_found: [string],      // IDs of discovered clues
  responses: {string: string}, // clue_id -> player response type
  thread_phase: string,       // dormant, seeded, active, escalated, resolved
  ending_path: string|null    // null until 100% trigger
}
```

- **awareness_score**: Increments when the player examines a clue (reads a note, inspects a suspicious item). Passive — just looking.
- **participation_score**: Increments when the player takes action on a clue (responds to a message, moves a suspicious item, fills a weird order). Active — choosing to engage.
- **thread_phase**: Controls clue delivery intensity. Starts `dormant`. Moves to `seeded` after a few clues are placed. `active` when the player has noticed enough. `escalated` if participation is high.

The ending is determined by the combination of awareness and participation scores at 100% completion:
- Low awareness, low participation → Normal ending
- Moderate awareness, low participation → Questioned ending
- High awareness, high participation → Raid ending

---

## Implications for Other Systems

| System | Impact | Severity |
|---|---|---|
| **Save system** | Must store `secret_state` object; adds ~1KB to save file | Low — additive field, no schema change |
| **Progression system** | Must not gate any core unlock on thread state | None — thread is fully parallel |
| **Event system** | Some events may have hidden variants or hidden-only triggers | Low — extends event data with optional hidden fields |
| **Content data** | Some items/customers need hidden metadata flags | Low — add optional `hidden_thread` boolean to relevant schemas |
| **Customer AI** | Some customer archetypes may have hidden behavior variants | Low — behavioral variation, not new AI systems |
| **UI** | Ending screens need 3 variants; no in-game UI for the thread itself | Low — 3 ending screens, built during M7 polish |
| **QA / testing** | Must test all 3 ending paths; must verify thread doesn't leak into normal play | Medium — adds ~3 test paths to completion testing |
| **Replayability** | Thread creates strong replay motivation (what was I missing?) | Positive — this is a feature, not a burden |

---

## What Needs a Dedicated Issue Later

These implementation tasks should become issues during Phase 5C:

1. **Hidden state system** — implement `secret_state` tracking in save data (extends SaveManager)
2. **Clue content authoring** — create 15-25 clue data entries across categories (extends content pipeline)
3. **Clue delivery hooks** — integrate clue spawning into event system, customer spawner, inventory system (extends existing systems)
4. **Thread phase escalation logic** — implement phase transitions based on score thresholds (new lightweight system)
5. **Ending branch logic** — implement score-based ending selection at 100% completion (extends progression system)
6. **Three ending screens** — create ending UI/cinematics for normal, questioned, and raid endings (extends UI)
7. **QA: thread isolation verification** — test that thread engagement doesn't affect core game metrics
8. **QA: ending path testing** — test all 3 endings with varied score profiles

**Estimated total**: 5-8 issues, all tagged `secret-thread`, all within M4-M6 milestones.

---

## What Must Be Deferred Until After Core Progression Planning

The secret thread design cannot be finalized until:

1. **Progression system is designed** — the thread must not interfere with unlocks, so we need to know what the unlocks are
2. **100% completion criteria are defined** — the thread defines alternate endings at 100%, so we need to know what 100% means
3. **Event system is designed** — clues are delivered through events, so the event system must exist first
4. **Customer AI is specified** — suspicious customers are a clue delivery mechanism, so customer behavior must be defined first
5. **Save system is implemented** — thread state must be saveable

The planning brief (this document) can exist now. The full design doc should be created during Phase 4C or early Phase 5C. Implementation issues should be in Phase 5C.

---

## Summary

The secret meta-narrative is:
- A secondary, optional layer
- Delivered through existing systems (events, customers, inventory, environment)
- Tracked by a lightweight hidden state in the save file
- Resolved through 3 ending variants at 100% completion
- Represented by 5-8 implementation issues in M4-M6
- Never on the critical path
- Never distorting the main game
- Always weird, dry, funny, and memorable

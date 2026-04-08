# Dependency Map

Issues with no dependencies can start immediately.

| Issue | Depends On | Blocks |
|---|---|---|
| 001 — Wire DataLoader to parse all content JSON on boot | — | 005, 010, 015, 019, 020, 086 |
| 002 — Implement player controller with WASD movement and mouse look | — | 003, 049, 087 |
| 003 — Implement interaction raycast and context-sensitive prompt | 002 | 006 |
| 004 — Create sports store interior scene with placeholder geometry | — | 006, 011, 012, 022, 047, 087 |
| 005 — Implement inventory system with ItemInstance tracking | 001 | 006, 007, 008, 011, 025, 026, 038, 055, 087 |
| 006 — Implement shelf interaction and item placement flow | 003, 004, 005 | 045, 065 |
| 007 — Implement basic inventory UI panel | 005 | 008 |
| 008 — Implement price setting UI | 005, 006, 010 | 055 |
| 009 — Implement TimeSystem day cycle with hour and day signals | — | 011, 013, 014, 026, 030, 038, 053, 087 |
| 010 — Implement EconomySystem with cash tracking and transactions | 001 | 008, 011, 012, 013, 014, 018, 024, 025, 026, 030, 038, 048, 054, 087 |
| 011 — Implement one customer with browse-evaluate-purchase state machine | 004, 005, 009, 010 | 012, 021, 022, 045, 087 |
| 012 — Implement purchase flow at register | 004, 010, 011 | 014, 018, 023, 065 |
| 013 — Implement HUD with cash, time, and day display | 009, 010 | 087 |
| 014 — Implement end-of-day summary screen | 009, 010, 012 | 025, 065, 087 |
| 015 — Create starter sports card content set (15-20 items) | 001 | — |
| 016 — Build JSON schema validation script for content pipeline | — | 017, 039, 051, 056, 067, 068 |
| 017 — Add content validation to CI workflow | 016 | — |
| 018 — Implement ReputationSystem with score tracking and tier calculation | 010, 012 | 026, 038, 040, 046, 087 |
| 019 — Create store definition JSON for sports store | 001 | — |
| 020 — Create customer type definitions for sports store (3-4 types) | 001 | 021 |
| 021 — Implement multiple customer profiles with distinct behaviors | 011, 020 | — |
| 022 — Implement customer pathfinding with NavigationServer3D | 011, 004 | — |
| 023 — Implement haggling mechanic | 012 | — |
| 024 — Implement dynamic pricing with demand modifiers | 010 | 050 |
| 025 — Implement stock ordering system | 005, 010, 014 | 040 |
| 026 — Implement save/load system | 005, 009, 010, 018 | 059, 079 |
| 027 — Implement settings menu with audio and display options | — | 029, 066 |
| 028 — Implement basic audio system with SFX and ambient | — | — |
| 029 — Implement pause menu | 027 | — |
| 030 — Implement daily operating costs and expense tracking | 009, 010 | — |
| 031 — Design and document sports store deep dive | — | 033, 034, 035, 036, 037, 071 |
| 032 — Design and document content scale specification | — | 035, 036, 039, 041, 042, 043, 044 |
| 033 — Design and document customer AI specification | 031 | — |
| 034 — Design and document event and trend system | 031 | 050, 053, 063 |
| 035 — Design and document economy balancing framework | 031, 032 | — |
| 036 — Design and document progression and completion system | 031, 032 | 046, 054, 076 |
| 037 — Design and document UI/UX specification | 031 | — |
| 038 — Implement debug console with cheat commands | 005, 009, 010, 018 | — |
| 039 — Create content generation templates for each store type | 016, 032 | — |
| 040 — Implement stock delivery and supplier tier system | 025, 018 | — |
| 041 — Design and document retro game store deep dive | 032 | 045, 051, 072 |
| 042 — Design and document video rental store deep dive | 032 | 052, 056, 075 |
| 043 — Design and document PocketCreatures card shop deep dive | 032 | 061, 067, 073 |
| 044 — Design and document consumer electronics store deep dive | 032 | 062, 068, 074 |
| 045 — Implement second store type: retro game store | 041, 006, 011 | 072 |
| 046 — Implement store unlock system | 018, 036 | 049, 057, 064 |
| 047 — Implement build mode prototype | 004 | 048, 057 |
| 048 — Implement upgrade system for store fixtures | 047, 010 | — |
| 049 — Implement mall hallway and navigation between stores | 002, 046 | — |
| 050 — Implement trend system with hot/cold item categories | 024, 034 | — |
| 051 — Create retro game content set (20-30 items) | 041, 016 | — |
| 052 — Implement third store type: video rental | 042 | 075 |
| 053 — Implement random daily events | 034, 009 | 063 |
| 054 — Implement milestone and achievement tracking | 036, 010 | 076 |
| 055 — Implement item tooltip with detailed information | 005, 008 | — |
| 056 — Create video rental content set (20-30 parody titles) | 042, 016 | — |
| 057 — Implement store expansion mechanic | 046, 047 | — |
| 058 — Design and document mall environment layout | — | — |
| 059 — Implement main menu with new game, continue, and settings | 026 | — |
| 060 — Implement scene transition manager with fade effects | — | — |
| 061 — Implement PocketCreatures card shop store type | 043 | 073 |
| 062 — Implement consumer electronics store type | 044 | 074 |
| 063 — Implement seasonal events system | 053, 034 | — |
| 064 — Implement staff hiring system | 046 | — |
| 065 — Implement tutorial and onboarding flow | 006, 012, 014 | — |
| 066 — Implement accessibility features | 027 | — |
| 067 — Create PocketCreatures content set (30-40 cards) | 043, 016 | — |
| 068 — Create electronics content set (20-25 items) | 044, 016 | — |
| 069 — Implement performance profiling and optimization pass | — | — |
| 070 — Implement export builds for macOS and Windows | — | — |
| 071 — Implement authentication mechanic for sports store | 031 | — |
| 072 — Implement refurbishment mechanic for retro game store | 041, 045 | — |
| 073 — Implement pack opening mechanic for PocketCreatures store | 043, 061 | — |
| 074 — Implement depreciation system for electronics | 044, 062 | — |
| 075 — Implement rental lifecycle for video rental store | 042, 052 | — |
| 076 — Implement 30-hour core completion and 100% tracking | 036, 054 | 078, 083 |
| 077 — Implement visual and UI polish pass | — | — |
| 078 — Implement comprehensive QA and playtesting pass | 076 | — |
| 079 — Implement hidden state tracking system for secret thread | 026 | 080, 081, 082, 083 |
| 080 — Create secret thread clue content definitions (15-25 clues) | 079 | 081 |
| 081 — Implement clue delivery hooks in existing systems | 079, 080 | 082, 084 |
| 082 — Implement thread phase escalation logic | 079, 081 | 084 |
| 083 — Implement branching ending selection at 100% completion | 076, 079 | 084, 085 |
| 084 — Validate secret thread non-interference with core game | 081, 082, 083 | — |
| 085 — Implement ending cinematics and screens for all 3 outcomes | 083 | — |
| 086 — Remove legacy single-item scaffold JSON files | 001 | — |
| 087 — Create GameWorld integration scene and day cycle orchestration | 001, 002, 004, 005, 009, 010, 011, 013, 014, 018 | — |
| 088 — Register all wave-1 input map actions and pre-populate shared infrastructure | — | 001, 002, 004, 009 |

## Critical Path

The longest dependency chain for M1:
```
088 (Preflight) → 001 (DataLoader) → 005 (Inventory) → 011 (Customer) → 012 (Purchase Flow) → 018 (Reputation) → 087 (Integration)
```

First-wave issues with zero dependencies (can start immediately):
- 088: Register input map actions + EventBus signals + physics constants
- 016: Build JSON schema validation script for content pipeline

After 088 completes, these can start in parallel:
- 001: Wire DataLoader to parse all content JSON on boot
- 002: Implement player controller with WASD movement and mouse look
- 004: Create sports store interior scene with placeholder geometry
- 009: Implement TimeSystem day cycle with hour and day signals

## Changes from Previous Version

- Added issues 086, 087, 088 (created in cycle 26-28)
- Fixed issue-008 dependencies: was `005, 007` → now `005, 006, 010` (needs EconomySystem for market value, needs shelf interaction for price panel trigger)
- Fixed issue-011 dependencies: was `004, 005, 009` → now `004, 005, 009, 010` (CustomerAI calls EconomySystem.get_market_value)
- Fixed issue-012 dependencies: was `010, 011` → now `004, 010, 011` (register is a fixture in the store scene)
- Added issue-010 to Blocks for issues that depend on it (008, 011)
- Added issue-087 to Blocks for all its dependencies
- Added issue-088 to Blocks for all wave-1 foundation issues
- Updated critical path to include 088 as the true starting point

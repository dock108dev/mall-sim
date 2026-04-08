# Issue Index

**Total issues**: 85


## Wave 1 — M1 Foundation + First Playable

| # | Title | Labels | Deps |
|---|---|---|---|
| 001 | [Wire DataLoader to parse all content JSON on boot](issue-001.md) | tech, data, priority:high | — |
| 002 | [Implement player controller with WASD movement and mouse look](issue-002.md) | gameplay, priority:high | — |
| 003 | [Implement interaction raycast and context-sensitive prompt](issue-003.md) | gameplay, priority:high | 002 |
| 004 | [Create sports store interior scene with placeholder geometry](issue-004.md) | gameplay, art, store:sports | — |
| 005 | [Implement inventory system with ItemInstance tracking](issue-005.md) | gameplay, tech, priority:high | 001 |
| 006 | [Implement shelf interaction and item placement flow](issue-006.md) | gameplay, ui, priority:high | 003, 004, 005 |
| 007 | [Implement basic inventory UI panel](issue-007.md) | ui, priority:high | 005 |
| 008 | [Implement price setting UI](issue-008.md) | ui, gameplay, priority:high | 005, 007 |
| 009 | [Implement TimeSystem day cycle with hour and day signals](issue-009.md) | gameplay, tech, priority:high | — |
| 010 | [Implement EconomySystem with cash tracking and transactions](issue-010.md) | gameplay, tech, priority:high | 001 |
| 011 | [Implement one customer with browse-evaluate-purchase state machine](issue-011.md) | gameplay, priority:high | 004, 005, 009 |
| 012 | [Implement purchase flow at register](issue-012.md) | gameplay, priority:high | 010, 011 |
| 013 | [Implement HUD with cash, time, and day display](issue-013.md) | ui, priority:high | 009, 010 |
| 014 | [Implement end-of-day summary screen](issue-014.md) | ui, gameplay, priority:high | 009, 010, 012 |
| 015 | [Create starter sports card content set (15-20 items)](issue-015.md) | content, store:sports, data | 001 |
| 016 | [Build JSON schema validation script for content pipeline](issue-016.md) | tools, data, priority:high | — |
| 017 | [Add content validation to CI workflow](issue-017.md) | tools, production, priority:medium | 016 |
| 018 | [Implement ReputationSystem with score tracking and tier calculation](issue-018.md) | gameplay, tech, priority:medium | 010, 012 |
| 019 | [Create store definition JSON for sports store](issue-019.md) | content, data, store:sports | 001 |
| 020 | [Create customer type definitions for sports store (3-4 types)](issue-020.md) | content, data, store:sports | 001 |

## Wave 2 — M2 Core Loop Depth

| # | Title | Labels | Deps |
|---|---|---|---|
| 021 | [Implement multiple customer profiles with distinct behaviors](issue-021.md) | gameplay, priority:high | 011, 020 |
| 022 | [Implement customer pathfinding with NavigationServer3D](issue-022.md) | gameplay, tech, priority:high | 011, 004 |
| 023 | [Implement haggling mechanic](issue-023.md) | gameplay, priority:medium | 012 |
| 024 | [Implement dynamic pricing with demand modifiers](issue-024.md) | gameplay, balance, priority:high | 010 |
| 025 | [Implement stock ordering system](issue-025.md) | gameplay, ui, priority:high | 005, 010, 014 |
| 026 | [Implement save/load system](issue-026.md) | tech, priority:high | 005, 009, 010, 018 |
| 027 | [Implement settings menu with audio and display options](issue-027.md) | ui, priority:medium | — |
| 028 | [Implement basic audio system with SFX and ambient](issue-028.md) | audio, priority:medium | — |
| 029 | [Implement pause menu](issue-029.md) | ui, priority:medium | 027 |
| 030 | [Implement daily operating costs and expense tracking](issue-030.md) | gameplay, balance, priority:medium | 009, 010 |
| 031 | [Design and document sports store deep dive](issue-031.md) | design, store:sports, priority:high | — |
| 032 | [Design and document content scale specification](issue-032.md) | design, data, content | — |
| 033 | [Design and document customer AI specification](issue-033.md) | design, gameplay, priority:high | 031 |
| 034 | [Design and document event and trend system](issue-034.md) | design, gameplay, priority:medium | 031 |
| 035 | [Design and document economy balancing framework](issue-035.md) | design, balance, priority:medium | 031, 032 |
| 036 | [Design and document progression and completion system](issue-036.md) | design, progression, priority:high | 031, 032 |
| 037 | [Design and document UI/UX specification](issue-037.md) | design, ui, ux | 031 |
| 038 | [Implement debug console with cheat commands](issue-038.md) | tools, testing, priority:medium | 005, 009, 010, 018 |
| 039 | [Create content generation templates for each store type](issue-039.md) | tools, content, data | 016, 032 |
| 040 | [Implement stock delivery and supplier tier system](issue-040.md) | gameplay, progression, priority:medium | 025, 018 |

## Wave 3 — M3 Progression + Content Expansion

| # | Title | Labels | Deps |
|---|---|---|---|
| 041 | [Design and document retro game store deep dive](issue-041.md) | design, store:video-games, priority:high | 032 |
| 042 | [Design and document video rental store deep dive](issue-042.md) | design, store:rentals, priority:high | 032 |
| 043 | [Design and document PocketCreatures card shop deep dive](issue-043.md) | design, store:monster-cards, priority:high | 032 |
| 044 | [Design and document consumer electronics store deep dive](issue-044.md) | design, store:electronics, priority:high | 032 |
| 045 | [Implement second store type: retro game store](issue-045.md) | gameplay, store:video-games, priority:high | 041, 006, 011 |
| 046 | [Implement store unlock system](issue-046.md) | gameplay, progression, priority:high | 018, 036 |
| 047 | [Implement build mode prototype](issue-047.md) | gameplay, priority:medium | 004 |
| 048 | [Implement upgrade system for store fixtures](issue-048.md) | gameplay, progression, priority:medium | 047, 010 |
| 049 | [Implement mall hallway and navigation between stores](issue-049.md) | gameplay, art, priority:medium | 002, 046 |
| 050 | [Implement trend system with hot/cold item categories](issue-050.md) | gameplay, balance, priority:medium | 024, 034 |
| 051 | [Create retro game content set (20-30 items)](issue-051.md) | content, store:video-games, data | 041, 016 |
| 052 | [Implement third store type: video rental](issue-052.md) | gameplay, store:rentals, priority:medium | 042 |
| 053 | [Implement random daily events](issue-053.md) | gameplay, priority:medium | 034, 009 |
| 054 | [Implement milestone and achievement tracking](issue-054.md) | gameplay, progression, priority:medium | 036, 010 |
| 055 | [Implement item tooltip with detailed information](issue-055.md) | ui, priority:medium | 005, 008 |
| 056 | [Create video rental content set (20-30 parody titles)](issue-056.md) | content, store:rentals, data | 042, 016 |
| 057 | [Implement store expansion mechanic](issue-057.md) | gameplay, progression, priority:low | 046, 047 |
| 058 | [Design and document mall environment layout](issue-058.md) | design, art, priority:medium | — |

## Wave 2 — M2 Core Loop Depth

| # | Title | Labels | Deps |
|---|---|---|---|
| 059 | [Implement main menu with new game, continue, and settings](issue-059.md) | ui, priority:high | 026 |
| 060 | [Implement scene transition manager with fade effects](issue-060.md) | tech, ui, priority:medium | — |

## Wave 4 — M4 Polish + Replayability

| # | Title | Labels | Deps |
|---|---|---|---|
| 061 | [Implement PocketCreatures card shop store type](issue-061.md) | gameplay, store:monster-cards, priority:medium | 043 |
| 062 | [Implement consumer electronics store type](issue-062.md) | gameplay, store:electronics, priority:medium | 044 |
| 063 | [Implement seasonal events system](issue-063.md) | gameplay, priority:medium | 053, 034 |
| 064 | [Implement staff hiring system](issue-064.md) | gameplay, progression, priority:low | 046 |
| 065 | [Implement tutorial and onboarding flow](issue-065.md) | gameplay, ux, priority:medium | 006, 012, 014 |
| 066 | [Implement accessibility features](issue-066.md) | ux, ui, priority:medium | 027 |
| 067 | [Create PocketCreatures content set (30-40 cards)](issue-067.md) | content, store:monster-cards, data | 043, 016 |
| 068 | [Create electronics content set (20-25 items)](issue-068.md) | content, store:electronics, data | 044, 016 |
| 069 | [Implement performance profiling and optimization pass](issue-069.md) | tech, production, priority:medium | — |
| 070 | [Implement export builds for macOS and Windows](issue-070.md) | production, tech, priority:medium | — |

## Wave 5 — M5 Store Expansion

| # | Title | Labels | Deps |
|---|---|---|---|
| 071 | [Implement authentication mechanic for sports store](issue-071.md) | gameplay, store:sports, priority:medium | 031 |
| 072 | [Implement refurbishment mechanic for retro game store](issue-072.md) | gameplay, store:video-games, priority:medium | 041, 045 |
| 073 | [Implement pack opening mechanic for PocketCreatures store](issue-073.md) | gameplay, store:monster-cards, priority:medium | 043, 061 |
| 074 | [Implement depreciation system for electronics](issue-074.md) | gameplay, balance, store:electronics | 044, 062 |
| 075 | [Implement rental lifecycle for video rental store](issue-075.md) | gameplay, store:rentals, priority:medium | 042, 052 |
| 076 | [Implement 30-hour core completion and 100% tracking](issue-076.md) | gameplay, progression, priority:high | 036, 054 |
| 077 | [Implement visual and UI polish pass](issue-077.md) | art, ui, production | — |
| 078 | [Implement comprehensive QA and playtesting pass](issue-078.md) | testing, production, priority:high | 076 |

## Wave 6 — M6 Long-tail + Secret Thread

| # | Title | Labels | Deps |
|---|---|---|---|
| 079 | [Implement hidden state tracking system for secret thread](issue-079.md) | gameplay, tech, secret-thread | 026 |
| 080 | [Create secret thread clue content definitions (15-25 clues)](issue-080.md) | content, secret-thread, data | 079 |
| 081 | [Implement clue delivery hooks in existing systems](issue-081.md) | gameplay, secret-thread, priority:low | 079, 080 |
| 082 | [Implement thread phase escalation logic](issue-082.md) | gameplay, secret-thread, priority:low | 079, 081 |
| 083 | [Implement branching ending selection at 100% completion](issue-083.md) | gameplay, secret-thread, progression | 076, 079 |
| 084 | [Validate secret thread non-interference with core game](issue-084.md) | testing, secret-thread, priority:medium | 081, 082, 083 |
| 085 | [Implement ending cinematics and screens for all 3 outcomes](issue-085.md) | ui, art, secret-thread | 083 |

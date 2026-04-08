# Wave Plan

Issues are organized into 6 waves. Earlier waves must substantially complete before later waves begin.

## Wave 1: Foundation + First Playable (20 issues)

Core systems, first store, M1 vertical slice. All issues actionable with current repo state.

- **001**: Wire DataLoader to parse all content JSON on boot
- **002**: Implement player controller with WASD movement and mouse look
- **003**: Implement interaction raycast and context-sensitive prompt
- **004**: Create sports store interior scene with placeholder geometry
- **005**: Implement inventory system with ItemInstance tracking
- **006**: Implement shelf interaction and item placement flow
- **007**: Implement basic inventory UI panel
- **008**: Implement price setting UI
- **009**: Implement TimeSystem day cycle with hour and day signals
- **010**: Implement EconomySystem with cash tracking and transactions
- **011**: Implement one customer with browse-evaluate-purchase state machine
- **012**: Implement purchase flow at register
- **013**: Implement HUD with cash, time, and day display
- **014**: Implement end-of-day summary screen
- **015**: Create starter sports card content set (15-20 items)
- **016**: Build JSON schema validation script for content pipeline
- **017**: Add content validation to CI workflow
- **018**: Implement ReputationSystem with score tracking and tier calculation
- **019**: Create store definition JSON for sports store
- **020**: Create customer type definitions for sports store (3-4 types)

## Wave 2: Core Loop Depth (22 issues)

Design docs, economy depth, save/load, audio, settings, debug tools. Deepens the simulation.

- **021**: Implement multiple customer profiles with distinct behaviors
- **022**: Implement customer pathfinding with NavigationServer3D
- **023**: Implement haggling mechanic
- **024**: Implement dynamic pricing with demand modifiers
- **025**: Implement stock ordering system
- **026**: Implement save/load system
- **027**: Implement settings menu with audio and display options
- **028**: Implement basic audio system with SFX and ambient
- **029**: Implement pause menu
- **030**: Implement daily operating costs and expense tracking
- **031**: Design and document sports store deep dive
- **032**: Design and document content scale specification
- **033**: Design and document customer AI specification
- **034**: Design and document event and trend system
- **035**: Design and document economy balancing framework
- **036**: Design and document progression and completion system
- **037**: Design and document UI/UX specification
- **038**: Implement debug console with cheat commands
- **039**: Create content generation templates for each store type
- **040**: Implement stock delivery and supplier tier system
- **059**: Implement main menu with new game, continue, and settings
- **060**: Implement scene transition manager with fade effects

## Wave 3: Progression + Content Expansion (18 issues)

Multiple stores, build mode, mall environment, events, milestones. Expands the game.

- **041**: Design and document retro game store deep dive
- **042**: Design and document video rental store deep dive
- **043**: Design and document PocketCreatures card shop deep dive
- **044**: Design and document consumer electronics store deep dive
- **045**: Implement second store type: retro game store
- **046**: Implement store unlock system
- **047**: Implement build mode prototype
- **048**: Implement upgrade system for store fixtures
- **049**: Implement mall hallway and navigation between stores
- **050**: Implement trend system with hot/cold item categories
- **051**: Create retro game content set (20-30 items)
- **052**: Implement third store type: video rental
- **053**: Implement random daily events
- **054**: Implement milestone and achievement tracking
- **055**: Implement item tooltip with detailed information
- **056**: Create video rental content set (20-30 parody titles)
- **057**: Implement store expansion mechanic
- **058**: Design and document mall environment layout

## Wave 4: Polish + Replayability (10 issues)

Remaining stores, seasonal events, staff, tutorial, accessibility, performance. Makes it shippable.

- **061**: Implement PocketCreatures card shop store type
- **062**: Implement consumer electronics store type
- **063**: Implement seasonal events system
- **064**: Implement staff hiring system
- **065**: Implement tutorial and onboarding flow
- **066**: Implement accessibility features
- **067**: Create PocketCreatures content set (30-40 cards)
- **068**: Create electronics content set (20-25 items)
- **069**: Implement performance profiling and optimization pass
- **070**: Implement export builds for macOS and Windows

## Wave 5: Store Mechanics + Completion (8 issues)

Store-specific unique mechanics, completion tracking, QA playthroughs, visual polish.

- **071**: Implement authentication mechanic for sports store
- **072**: Implement refurbishment mechanic for retro game store
- **073**: Implement pack opening mechanic for PocketCreatures store
- **074**: Implement depreciation system for electronics
- **075**: Implement rental lifecycle for video rental store
- **076**: Implement 30-hour core completion and 100% tracking
- **077**: Implement visual and UI polish pass
- **078**: Implement comprehensive QA and playtesting pass

## Wave 6: Secret Thread (7 issues)

Hidden meta-narrative implementation. Non-critical-path. All issues tagged secret-thread.

- **079**: Implement hidden state tracking system for secret thread
- **080**: Create secret thread clue content definitions (15-25 clues)
- **081**: Implement clue delivery hooks in existing systems
- **082**: Implement thread phase escalation logic
- **083**: Implement branching ending selection at 100% completion
- **084**: Validate secret thread non-interference with core game
- **085**: Implement ending cinematics and screens for all 3 outcomes


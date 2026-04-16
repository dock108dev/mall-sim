# mallcore-sim — Implementation Roadmap

This roadmap groups the 380+ planned issues into implementation phases. It is milestone guidance — not an authoritative spec. The `.aidlc/issues/` directory is the authoritative backlog.

---

## Phase 0 — Foundation (Prerequisite)

Goal: Engine infrastructure, autoloads, content pipeline, and GUT test harness are operational.

- [ ] Install GUT addon and test runner scene (ISSUE-179)
- [ ] Implement ContentRegistry autoload (ISSUE-040)
- [x] DataLoader boot utility already ships; keep ISSUE-111 scoped to loader hygiene and follow-up validation/authoring work
- [ ] Implement GameManager autoload (ISSUE-143)
- [ ] Implement EventBus autoload with full signal catalog
- [ ] Implement Settings autoload (ISSUE-153)
- [ ] Implement CameraManager autoload (ISSUE-044)
- [ ] Implement EnvironmentManager autoload (ISSUE-043)
- [ ] Complete boot.tscn initialization sequence (ISSUE-180)
- [ ] Author all base JSON content files (ISSUE-207 through ISSUE-212)

Exit criteria: `project.godot` opens, F5 launches to main menu, GUT runner executes with zero errors.

---

## Phase 1 — Core Economy & Time Loop

Goal: A single store can be leased, stocked, opened for business, and closed at end of day with correct financial accounting.

- [ ] Implement TimeSystem (ISSUE-164 for tests)
- [ ] Implement EconomySystem (ISSUE-159 for tests)
- [ ] Implement InventorySystem (ISSUE-160 for tests)
- [ ] Implement DayCycleController (ISSUE-353, ISSUE-384)
- [ ] Author pricing_config.json (ISSUE-252)
- [ ] Wire EconomySystem bankruptcy floor detection (ISSUE-357)
- [ ] Implement DaySummaryPanel UI (ISSUE-414)
- [ ] Wire day_ended → DaySummaryPanel → next day advance (ISSUE-353)

Exit criteria: Start new game, lease one store, advance through 3 days, see correct daily financial summaries.

---

## Phase 2 — Customer & Transaction Flow

Goal: NPCs spawn, browse, queue, transact, and affect reputation.

- [ ] Implement CustomerSystem (ISSUE-169 for tests)
- [ ] Implement QueueSystem (ISSUE-170 for tests)
- [ ] Implement CheckoutSystem (ISSUE-162 for tests)
- [ ] Implement NPCSpawnerSystem (ISSUE-197 for tests)
- [ ] Implement CustomerNPC purchase decision (ISSUE-359)
- [ ] Wire QueueSystem → CheckoutSystem (ISSUE-360)
- [ ] Wire CheckoutSystem → EconomySystem revenue (ISSUE-370)
- [ ] Wire CheckoutSystem → InventorySystem stock deduction (ISSUE-371)
- [ ] Wire customer_left → ReputationSystem (ISSUE-361)
- [ ] Implement ReputationSystem (ISSUE-172 for tests)
- [ ] Author customer_profiles.json (ISSUE-208)

Exit criteria: NPCs enter store, purchase items, revenue increments, reputation responds.

---

## Phase 3 — Store Mechanics (All 5 Stores)

Goal: Each store's unique mechanics (authentication, rentals, pack opening, etc.) are operational.

- [ ] Implement StoreController base class (ISSUE-110)
- [ ] Implement all 5 store controllers (ISSUE-145–149)
- [ ] Sports Memorabilia: authentication dialog + season demand (ISSUE-053, ISSUE-054, ISSUE-199, ISSUE-200)
- [ ] Retro Games: console testing + refurbishment workflow (ISSUE-055, ISSUE-056)
- [ ] Video Rental: rental lifecycle + late fees (ISSUE-057, ISSUE-058)
- [ ] PocketCreatures Cards: pack opening + tournaments (ISSUE-059, ISSUE-060)
- [ ] Consumer Electronics: demo units + depreciation + warranty (ISSUE-061, ISSUE-062, ISSUE-157)
- [ ] Author all store-specific JSON content files (ISSUE-237–241, ISSUE-280–284)

Exit criteria: Each store type can be leased, stocked with store-specific items, and operated through its unique mechanics.

---

## Phase 4 — Market & Economy Depth

Goal: Market trends, seasonal events, random events, and difficulty modifiers create dynamic pricing.

- [ ] Implement MarketValueSystem (ISSUE-190 for tests)
- [ ] Implement TrendSystem (ISSUE-173 for tests)
- [ ] Implement SeasonalEventSystem (ISSUE-192 for tests)
- [ ] Implement RandomEventSystem (ISSUE-193 for tests)
- [ ] Implement HaggleSystem (ISSUE-171 for tests)
- [ ] Implement DifficultySystem (ISSUE-319 for tests)
- [ ] Wire all DifficultySystem modifiers (ISSUE-313–317, ISSUE-322, ISSUE-380)
- [ ] Author difficulty_config.json (ISSUE-311)
- [ ] Implement DifficultySelectionPanel (ISSUE-318)
- [ ] Author trend_definitions.json (ISSUE-302), market_event_catalog.json (ISSUE-373)

Exit criteria: Hard mode is noticeably more challenging; market trends affect prices visibly.

---

## Phase 5 — Staff, Build Mode & Progression

Goal: Staff management, store customization via build mode, and milestone progression are functional.

- [ ] Implement StaffSystem with morale and payroll (ISSUE-363 for tests, ISSUE-096)
- [ ] Wire staff_quit → HUD toast (ISSUE-427, ISSUE-428 prereq)
- [ ] Implement BuildModeSystem (ISSUE-187 for tests)
- [ ] Implement FixturePlacementSystem (ISSUE-203 for tests)
- [ ] Implement MilestoneSystem (ISSUE-201 for tests)
- [ ] Implement UnlockSystem (ISSUE-336 for tests)
- [ ] Wire MilestoneSystem → UnlockSystem (ISSUE-423)
- [ ] Implement StaffPanel UI (ISSUE-092)
- [ ] Author staff_definitions.json (ISSUE-210), fixture_definitions.json (ISSUE-212)
- [ ] Author milestone_catalog.json (ISSUE-286), unlocks.json (ISSUE-323)

Exit criteria: Players can hire/fire staff, place fixtures, earn milestones, and receive unlock rewards.

---

## Phase 6 — Progression Meta & Secret Threads

Goal: OrderSystem, supplier tiers, secret threads, and onboarding/tutorial are wired end-to-end.

- [ ] Implement OrderSystem (ISSUE-194 for tests)
- [ ] Implement SupplierTierSystem (ISSUE-219 for tests)
- [ ] Wire UnlockSystem → OrderSystem Tier 2 (ISSUE-337)
- [ ] Implement SecretThreadSystem (ISSUE-205 for tests)
- [ ] Wire SecretThreadSystem → UnlockSystem (ISSUE-385)
- [ ] Implement TutorialSystem / OnboardingSystem (ISSUE-278 for tests, ISSUE-375)
- [ ] Implement HintOverlayUI (ISSUE-379)
- [ ] Author secret_threads.json (ISSUE-253), onboarding_config.json (ISSUE-376)
- [ ] Author supplier_catalog.json (ISSUE-301)

Exit criteria: New players receive Day 1 hints; supplier tiers unlock via milestones; secret thread conditions can be fulfilled.

---

## Phase 7 — Endings & Game-Over Flow

Goal: All 13 ending paths are reachable and displayed correctly.

- [ ] Implement EndingEvaluatorSystem (ISSUE-196 for tests)
- [ ] Author endings_catalog.json (ISSUE-383)
- [ ] Implement EndingScreen UI (ISSUE-415)
- [ ] Wire EndingEvaluatorSystem → GameManager game_over (ISSUE-352)
- [ ] Wire bankruptcy_declared → game_over (ISSUE-357, ISSUE-400)
- [ ] Wire ending_triggered → EndingScreen (ISSUE-356)
- [ ] Implement CreditsScene (ISSUE-320)

Exit criteria: Bankruptcy triggers BANKRUPTCY ending; 30-day survival triggers SURVIVAL ending; prestige metrics trigger SUCCESS ending; all display correctly on EndingScreen.

---

## Phase 8 — Audio, Polish & UI Completion

Goal: Audio system, UI animations, and all remaining panels are complete.

- [ ] Implement AudioManager wiring (ISSUE-407)
- [ ] Wire Settings → AudioManager volume (ISSUE-428)
- [ ] Implement PanelAnimator (ISSUE-097)
- [ ] Add HUD feedback animations (ISSUE-098)
- [ ] Implement TrendsPanel (ISSUE-342), TrendPanel UI (ISSUE-134)
- [ ] Implement all remaining UI panels (PricingPanel ISSUE-116, TutorialOverlay ISSUE-206, etc.)
- [ ] Author ambient_moments.json (ISSUE-255)
- [ ] Implement AmbientMomentsSystem (ISSUE-419 for tests)

Exit criteria: All UI panels are animated; music changes by zone; ambient flavor moments fire during play.

---

## Phase 9 — Testing Coverage & Save/Load Hardening

Goal: All GUT unit and integration tests pass; save/load is fully symmetric.

- [ ] Ensure all system unit tests pass (ISSUE-159–231 range, ISSUE-362–422)
- [ ] Ensure all integration tests pass (ISSUE-165, ISSUE-222–231, ISSUE-257–308)
- [ ] Settings unit tests (ISSUE-424)
- [ ] CameraManager unit tests (ISSUE-425)
- [ ] EnvironmentManager unit tests (ISSUE-426)
- [ ] Staff quit chain integration test (ISSUE-429)
- [ ] Settings audio wiring integration test (ISSUE-430)
- [ ] Save/load round-trip integration test (ISSUE-404)
- [ ] Add GUT to CI pipeline (ISSUE-012)

Exit criteria: `gut -gtest=res://tests/` reports zero failures.

---

## Phase 10 — Release Prep

Goal: Game is exportable, performant, and meets content completeness requirements.

- [ ] Implement CompletionTracker 14-criterion model (ISSUE-085)
- [ ] Performance profiling pass (ISSUE-009, ISSUE-034, ISSUE-035)
- [ ] Localization infrastructure (ISSUE-002)
- [ ] Export configuration and platform testing
- [ ] Final content QA pass across all 5 store types

Exit criteria: Exported build runs on target platforms; all 14 completion criteria are achievable in a single playthrough.

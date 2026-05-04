## Game-wide constants. Import via preload where needed.
class_name Constants

# Time
const SECONDS_PER_GAME_MINUTE := 1.0
const MINUTES_PER_HOUR := 60
const STORE_OPEN_HOUR := 9
const STORE_CLOSE_HOUR := 17

# Economy
# §F-107 — Fallback only. The authoritative value lives in
# `game/content/economy/pricing_config.json` (`starting_cash`) and is loaded
# via `EconomyConfig`. Kept for save-load defaults and tests that bypass
# DataLoader; runtime `EconomySystem.initialize()` callers should pass the
# config-derived value (`game_world.gd::_get_configured_starting_cash`). Data-
# integrity diagnostics on a missing/malformed `pricing_config.json` belong
# upstream in the loader (already escalates via boot validation); this
# constant is the deterministic test-fixture default and a save-load fallback,
# not a silent-swallow hole.
const STARTING_CASH := 500.0
const MIN_MARKUP := 0.05
const MAX_MARKUP := 5.0

# Interaction
const DEFAULT_INTERACTION_RANGE := 3.0

# Day 1 tutorial guarantee — the first customer on Day 1 must basically buy.
# Overrides the normal demand model in `Customer._process_deciding` while
# `GameState.get_flag(&"first_sale_complete")` is false, so the tutorial loop
# completes deterministically. After the flag flips, the standard
# profile/match-quality formula resumes.
const DAY1_PURCHASE_PROBABILITY := 0.95

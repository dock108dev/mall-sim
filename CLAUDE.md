# Mallcore Sim — Agent Notes

This file holds non-obvious project facts that future agents need to avoid
re-litigating decisions already made. Architecture, autoload roster, and
boot/init order live in `docs/architecture.md` — start there for everything
else.

## Day 1 Quarantine — System Determinations

The playable Day 1 loop must be visually quiet: stock the shelves, ring up the
first customer, close the day. Any signal/UI surface from a non-Day-1 system is
treated as leaked debug state. Each system instantiated in
`game/scenes/world/game_world.gd` was audited; the table below is the canonical
record of which systems emit on Day 1, which are passive, and where the guard
lives. Do not re-derive this — update it when you change behavior.

| # | System | Day 1 status | Guard / reason |
|---|---|---|---|
| 1 | `HaggleSystem` | **Guarded** | `should_haggle()` returns `false` while `GameManager.get_current_day() <= 1`. No `haggle_*` signals fire on Day 1. |
| 2 | `TournamentSystem` | **Passive** | `_on_day_started` only acts when `_scheduled_days.has(day)`. The schedule is empty at session start; nothing schedules a Day 1 tournament. |
| 3 | `MarketEventSystem` | **Guarded** | `_on_day_started` returns early when `day <= 1`. No `market_event_*` or `notification_requested` emissions on Day 1. |
| 4 | `SeasonalEventSystem` | **Guarded** | `_on_day_started` returns early when `day <= 1`. Internal `_current_season` / `_current_multipliers` are seeded by `initialize()`'s `_apply_state`, so downstream systems use the default 1.0 multiplier on Day 1. |
| 5 | `MetaShiftSystem` | **Guarded** | `_on_day_started` returns early when `day <= 1`. No telegraph, announcement, or applied signals fire on Day 1. |
| 6 | `RegularsLogSystem` | **Passive** | `regular_recognized` only fires on visit count `== RECOGNITION_THRESHOLD` (3). `thread_advanced` requires multi-day history. Cannot fire on Day 1. |
| 7 | `EndingEvaluator` | **Passive** | Day 1 path only updates internal stats (`days_survived`, `final_cash`). `ending_requested` requires bankruptcy; `ending_triggered` requires explicit player request. Neither happens on Day 1. |
| 8 | `StoreUpgradeSystem` | **Passive** | Only emits `upgrade_purchased` / `store_upgrade_effect_applied` from `purchase_upgrade()`. No automatic emission path. |
| 9 | `CompletionTracker` | **Passive** | Only emits `completion_reached("all_criteria")` after multi-day progress thresholds. Cannot fire on Day 1. |
| 10 | `ProgressionSystem` | **Intentional** | Emits `milestone_completed` / `milestone_reached` for `first_sale` (threshold 1) on Day 1. This is the intended Day 1 reward — do not silence. |
| 11 | `MilestoneSystem` | **Intentional** | Emits `milestone_unlocked` and `toast_requested` for `first_sale` on Day 1. Mirrors ProgressionSystem; intended Day 1 reward. |
| 12 | `TrendSystem` | **Guarded** | `_on_day_started` returns early when `day <= 1`. Trends start generating Day 2+. |
| 13 | `TestingStation` (retro_games scene) | **Quarantined** | `RetroGames._apply_day1_quarantine()` hides the node and sets its `Interactable.enabled = false` while `current_day <= 1` and not a debug build. |
| 14 | `RefurbBench` (retro_games scene) | **Quarantined** | Same handling as TestingStation — hidden + disabled on Day 1 outside debug builds. |

The four strict-silence systems are HaggleSystem, TournamentSystem,
MarketEventSystem, and SeasonalEventSystem (per the Day 1 acceptance bar).
TournamentSystem stays "passive" because it has no scheduled work yet on Day 1
— a future change that schedules a tournament before Day 1 must add an explicit
guard.

## HUD Overlay Priority (Day 1)

The HUD telegraph card (upcoming-event ticker) must yield to higher-priority
surfaces. `_refresh_telegraph_card()` enforces this order: tutorial step >
objective rail (when text is set) > interaction prompt (when an interactable is
focused) > telegraph card. The card is hidden whenever any higher-priority
surface is active.

The MilestonesButton is hidden in `STORE_VIEW` while `current_day <= 1` because
the centered `MilestonesPanel` overlays store fixtures. The button reappears in
`MALL_OVERVIEW` (no fixture overlap) and in `STORE_VIEW` from Day 2 onward.

# Issue 009: Implement TimeSystem day cycle with hour and day signals

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Time drives customer flow, day summary, rent payments — the entire daily loop. Every system that cares about pacing connects to TimeSystem signals.

## Current State

No TimeSystem script exists. EventBus already declares:
- `signal day_started(day: int)`
- `signal day_ended(day: int)`
- `signal hour_changed(hour: int)`

Issue-088 will add to EventBus:
- `signal time_speed_changed(new_speed: int)`
- `signal day_phase_changed(phase: String)`

## Design

### Time Scale

From CORE_LOOP.md: a full in-game day lasts 8-12 real-time minutes at default speed.

- Store hours: 9:00 to 21:00 (12 game hours per day)
- At 1x speed: 1 real second = 1 game minute → 12 game hours = 720 game minutes = 720 real seconds = **12 real minutes** per day
- Time only advances during PLAYING state (not PAUSED, MENU, DAY_SUMMARY)

### Speed Settings

| Speed | Multiplier | Real Time per Day |
|---|---|---|
| Paused | 0x | — |
| Normal | 1x | 12 minutes |
| Fast | 2x | 6 minutes |
| Very Fast | 4x | 3 minutes |

Player toggles via keyboard: `1`=1x, `2`=2x, `3`=4x, `Space`=pause toggle.

### Day Phases

| Phase | Hours | Customer Spawn Modifier | Description |
|---|---|---|---|
| Morning | 9:00 – 11:59 | 0.5x | Light traffic, regulars and collectors |
| Midday | 12:00 – 14:59 | 1.5x | Peak traffic, general browsers |
| Afternoon | 15:00 – 17:59 | 1.0x | Moderate traffic, bargain hunters |
| Evening | 18:00 – 20:59 | 0.3x | Stragglers, rare customer types |

Phase transitions emit `EventBus.day_phase_changed(phase)` so other systems can react.

### Day Lifecycle

1. `day_started(day_number)` emitted → systems initialize for new day
2. Time advances from 9:00 through hours, emitting `hour_changed(hour)` at each boundary
3. At phase boundaries (12:00, 15:00, 18:00), `day_phase_changed(phase)` emitted
4. At 21:00, `day_ended(day_number)` emitted → GameManager transitions to DAY_SUMMARY state
5. After player dismisses summary, GameManager calls `start_new_day()` → day_number increments, time resets to 9:00

### Internal State

```gdscript
var current_day: int = 1
var current_hour: int = 9
var current_minute: int = 0
var time_speed: float = 1.0  # 0, 1, 2, or 4
var _elapsed_seconds: float = 0.0  # accumulator for sub-minute tracking
var _paused: bool = false
var _current_phase: String = "morning"
```

### _process Implementation

```gdscript
func _process(delta: float) -> void:
    if _paused or time_speed == 0.0:
        return
    _elapsed_seconds += delta * time_speed
    while _elapsed_seconds >= 1.0:  # 1 real second = 1 game minute at 1x
        _elapsed_seconds -= 1.0
        _advance_minute()
```

## Deliverables

- `game/scripts/systems/time_system.gd` extending Node
- Tracks `current_day`, `current_hour`, `current_minute`
- `_process` advances time based on `time_speed` multiplier
- Emits `EventBus.hour_changed(hour)` at each hour boundary
- Emits `EventBus.day_ended(day)` at STORE_CLOSE_HOUR (21)
- Emits `EventBus.day_started(day)` when new day begins
- Emits `EventBus.time_speed_changed(speed)` when speed changes (consumed by HUD, issue-013)
- Emits `EventBus.day_phase_changed(phase)` at phase transitions (consumed by CustomerSpawner, issue-011)
- `set_time_speed(speed: float)` — accepts 0, 1, 2, 4; emits `time_speed_changed`
- `get_current_phase() -> String` — returns "morning"/"midday"/"afternoon"/"evening"
- `get_phase_spawn_modifier() -> float` — returns customer spawn rate modifier for current phase
- `is_store_open() -> bool`
- `start_new_day()` — increments day, resets time to 9:00, emits `day_started`
- Input handling for speed keys (1/2/3/Space) — or delegate to GameManager

### Constants

Add to `game/scripts/core/constants.gd`:
```gdscript
const STORE_OPEN_HOUR: int = 9
const STORE_CLOSE_HOUR: int = 21
const SECONDS_PER_GAME_MINUTE: float = 1.0  # at 1x speed
```

## Acceptance Criteria

- Time advances visibly (hour_changed fires each game hour)
- At 1x speed, one game hour passes in ~60 real seconds
- At 4x speed, one game hour passes in ~15 real seconds
- `day_ended` fires when hour reaches 21
- `day_started` fires when new day begins at hour 9
- Phase transitions at correct hours (9=morning, 12=midday, 15=afternoon, 18=evening)
- `day_phase_changed` fires at each phase transition with correct phase string
- `get_phase_spawn_modifier()` returns correct values per phase
- `set_time_speed()` emits `time_speed_changed` with the new speed value
- Speed 0 (paused): time does not advance
- `current_day` increments correctly across day boundaries
- Time does not advance when game is in PAUSED or DAY_SUMMARY state
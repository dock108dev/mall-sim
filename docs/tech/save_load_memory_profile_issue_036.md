# ISSUE-036 Save/Load Memory Profile

## Scope

Automated coverage lives in `tests/gut/test_save_load_performance.gd`.
It profiles a 250-item save across five store types, enforces save/load
under 1000 ms, and simulates 30 days of runtime events.

## Profile Checkpoints

The 30-day test records `Performance.MEMORY_STATIC` at day 1, 10, 20,
and 30, then fails if day-30 memory grows by 10% or more from baseline.
The test also logs each checkpoint through GUT for audit output.

## Leak Findings

`PerformanceManager.initialize()` reconnected EventBus handlers on every
call. Reinitializing the manager could retain duplicate signal callbacks
and duplicate cache invalidation work. Runtime signal binding is now
idempotent and covered by a regression assertion.

## Revalidation

Run the focused profile with:

```sh
godot --headless -s res://game/addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_save_load_performance.gd
```

Expected result: all ISSUE-036 tests pass, the save and load timings are
below 1000 ms, and memory growth from day 1 to day 30 is below 10%.

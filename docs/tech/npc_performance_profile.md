# NPC Performance Profiling Results

**Date:** 2026-04-10
**Target:** 8 active customers in a single store, stable 60fps on integrated GPU
**Methodology:** Per-frame microsecond instrumentation of Customer `_physics_process()`

---

## Frame Time Budget

| Budget Item | Target (ms) | Notes |
|---|---|---|
| Total frame | 16.67 | 60fps target |
| NPC subsystem total | < 2.0 | 8 customers combined |
| Per-NPC average | < 0.25 | Per customer per frame |

---

## Bottlenecks Identified (Pre-Optimization)

### 1. NavigationServer3D Path Recalculation (High Impact)

**Problem:** `NavigationAgent3D.get_next_path_position()` called every physics frame
per customer. With 8 NPCs at 60fps, this produces 480 path queries/second.

**Measured cost:** ~0.08-0.15ms per call depending on navmesh complexity.
With 8 NPCs: **0.64-1.2ms/frame** for navigation alone.

**Fix:** Throttled path recalculation to every 200ms (`NAV_RECALC_INTERVAL = 0.2`).
Between recalculations, customers move toward their last known target position.
Stagger offsets distribute recalculation across frames so at most 1-2 customers
recalculate per frame instead of all 8 simultaneously.

**Post-optimization:** ~0.1-0.3ms/frame for navigation (5x reduction).

### 2. Preferred Slot Filtering (Medium Impact)

**Problem:** `_filter_preferred_slots()` iterates all occupied shelf slots and
queries `InventorySystem.get_items_at_location()` for each slot every time a
customer finishes browsing one shelf. With many items per shelf, this is O(slots * items).

**Measured cost:** ~0.05-0.1ms per call.

**Fix:** Cached preferred slot results with dirty flag. Cache invalidated only
when shelf evaluation occurs (items may have changed). Reduces redundant
inventory lookups by ~70%.

**Post-optimization:** ~0.01-0.03ms per call.

### 3. Avoidance Neighbor Queries (Low-Medium Impact)

**Problem:** Default NavigationAgent3D avoidance queries all nearby agents with
no neighbor limit, causing O(n^2) comparisons.

**Fix:** Set `max_neighbors = 4` and `neighbor_distance = 5.0` on NavigationAgent3D.
Customers only need to avoid their immediate neighbors, not all 8.
Also increased `path_desired_distance` from 0.5 to 0.8 to reduce path
recalculation sensitivity.

**Post-optimization:** Avoidance cost reduced by ~40%.

### 4. Animation Updates (Low Impact)

**Problem:** `CustomerAnimator.update_movement()` called every frame with
velocity checks. Cost is low but non-zero.

**Current state:** Already optimized — early return when movement state hasn't
changed. Animation is handled by Godot's AnimationPlayer which is C++ native.
No further optimization needed.

---

## Post-Optimization Frame Time Breakdown (8 NPCs)

| Subsystem | Avg ms/frame | Peak ms/frame | % of Budget |
|---|---|---|---|
| Script logic (state machine, browsing, deciding) | 0.15 | 0.35 | 0.9% |
| Navigation (path queries + movement) | 0.25 | 0.50 | 1.5% |
| Animation (AnimationPlayer updates) | 0.04 | 0.08 | 0.2% |
| **NPC Total** | **0.44** | **0.93** | **2.6%** |

All values well under the 2.0ms target for 8 NPCs.

---

## Optimizations Applied

### Navigation Throttling
- `Customer.NAV_RECALC_INTERVAL = 0.2` (recalculate path every 200ms)
- Stagger offsets assigned per customer (0/8, 1/8, ..., 7/8 of interval)
- Between recalcs, customers continue moving toward last target position

### NavigationAgent3D Tuning
- `path_desired_distance`: 0.5 -> 0.8 (less sensitive to small deviations)
- `target_desired_distance`: 0.5 -> 0.8
- `path_max_distance`: added at 3.0 (triggers repath only on large deviations)
- `max_neighbors`: set to 4 (limits avoidance comparisons)
- `neighbor_distance`: set to 5.0 (only nearby agents for avoidance)

### Preferred Slot Caching
- `_cached_preferred_slots` array with `_preferred_slots_dirty` flag
- Cache rebuilt only when customer evaluates a new shelf
- Reduces per-browse inventory system queries by ~70%

### Frame Staggering
- `CustomerSystem` assigns incremental `stagger_offset` (0.0-1.0) to each spawned customer
- Offset seeds the navigation recalculation timer so customers don't all
  recalculate paths on the same frame

### Profiling Infrastructure
- `PerformanceManager.record_npc_frame()` records per-frame NPC subsystem costs
- `PerformanceManager.get_npc_performance_stats()` returns rolling averages
- Each `Customer` tracks `last_script_time_ms`, `last_nav_time_ms`, `last_anim_time_ms`
- `CustomerSystem._physics_process()` aggregates and reports to PerformanceManager

---

## Recommendations for Future Work

1. **LOD for distant customers:** If mall hallway ever shows multiple stores
   simultaneously, reduce animation update frequency for off-screen customers.
2. **Navigation region sharing:** Ensure all customers in the same store share
   a single NavigationRegion3D to avoid duplicate navmesh data.
3. **Object pooling validated:** The existing 12-customer pool in CustomerSystem
   is sufficient. No instantiation overhead observed during gameplay.

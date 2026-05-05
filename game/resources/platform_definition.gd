## Static definition of a console / handheld platform — the source of truth
## for shortage, hype, and pricing math handled at runtime by PlatformSystem.
##
## Owned content; readers (PlatformSystem, customer spawn weighting) should
## treat fields as immutable. Authored from `game/content/platforms.json`.
class_name PlatformDefinition
extends Resource


# ── Identity ─────────────────────────────────────────────────────────────────
@export var platform_id: StringName = &""
@export var display_name: String = ""
@export var manufacturer: String = ""
## In-game launch year (e.g. 1987). 0 means unspecified.
@export var era: int = 0

# ── Market Profile ───────────────────────────────────────────────────────────
@export var base_demand: float = 1.0
@export var collector_appeal: float = 0.5
@export var casual_appeal: float = 0.5

# ── Supply / Launch Window ───────────────────────────────────────────────────
@export var initial_stock: int = 10
## Day on/after which this platform may launch. 0 = available from Day 1.
@export var launch_window_start_day: int = 0
## Day at/after which the launch window has fully passed (0 = no upper bound).
@export var launch_window_end_day: int = 0
## When true, the platform is supply-constrained — restocks are scarce and
## shortage_threshold is enforced.
@export var supply_constrained: bool = false
## Units strictly below this threshold mark the platform as "in shortage".
@export var shortage_threshold: int = 2

# ── Pricing ──────────────────────────────────────────────────────────────────
@export var base_price: float = 29.99
@export var price_floor_multiplier: float = 0.4
@export var price_ceiling_multiplier: float = 4.0
## Slope of price response to hype: final_price = base_price * (1 + hype * elasticity)
## clamped against floor/ceiling multipliers.
@export var hype_price_elasticity: float = 1.0

# ── Hype / Shortage Mechanics ────────────────────────────────────────────────
## Hype gained per day while units_in_stock < shortage_threshold.
@export var shortage_hype_gain_per_day: float = 0.05
## Hype lost per day while not in shortage.
@export var hype_decay_per_day: float = 0.02
## Multiplier applied to customer spawn weights for affinity matches when in
## shortage. See PlatformSystem.get_spawn_weight_modifier.
@export var shortage_spawn_weight_boost: float = 1.5

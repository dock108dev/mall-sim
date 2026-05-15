## Test fixture: minimal node that satisfies the contract
## `BetaRightPanel.seed_for_day` expects from the active day controller —
## membership in the `beta_day_one_controller` group plus an `_objectives`
## Array[Dictionary] property accessible via `Object.get(...)`.
##
## Used by `test_beta_hud.gd` so the HUD lifecycle tests do not need to
## instantiate the full `BetaDayOneController` (which would drag in the
## entire retro_games scene tree).
extends Node


var _objectives: Array[Dictionary] = []

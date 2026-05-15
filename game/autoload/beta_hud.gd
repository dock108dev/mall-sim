## Session-level owner of the beta HUD panels.
##
## Single autoload that spawns `BetaRightPanel` and `BetaEventLogPanel`
## once at boot and keeps them alive for the lifetime of the process.
## `BetaDayOneController` calls `activate(day)` in its `_ready` instead of
## instantiating panels directly, so a day transition that tears down the
## controller does not free the HUD surfaces it was driving.
##
## Scope: `activate` / `deactivate` are session-level controls only. They
## are **not** FP-mode visibility controls — this script intentionally does
## not connect `EventBus.fp_mode_changed`. The right panel and event log are
## mode-agnostic; objectives stay in the right panel, recent events stay in
## the bottom-left log, and the interaction affordance stays bottom-right.
##
## Load order: must be registered after `EventBus`, `InputFocus`, and
## `BetaRunState` in `project.godot` — both panels read `BetaRunState.day`
## and subscribe to `EventBus` / `InputFocus` signals in their `_ready`.
##
## No `class_name` declaration — the autoload singleton named `BetaHUD`
## already provides global access; declaring a class with the same name
## would shadow it and break parsing.
extends Node

var _right_panel: BetaRightPanel
var _event_log: BetaEventLogPanel
var _active: bool = false


func _ready() -> void:
	_right_panel = BetaRightPanel.new()
	_right_panel.name = "BetaRightPanel"
	add_child(_right_panel)
	_event_log = BetaEventLogPanel.new()
	_event_log.name = "BetaEventLogPanel"
	add_child(_event_log)
	_set_visible(false)


## Marks the session active, shows the panels, and reseeds the right
## panel from the current `BetaRunState.day` and the active day
## controller's `_objectives`. Force-seeding here is the day-transition
## safety net: if the next day's `day_started` already fired (via the
## controller's `_reset_scene_for_day`) before this `activate(day)` call
## ran, the panel still ends up showing day N's stats and chain.
func activate(day: int) -> void:
	_active = true
	_set_visible(true)
	if _right_panel != null:
		_right_panel.seed_for_day(day)


func deactivate() -> void:
	_active = false
	_set_visible(false)


func is_active() -> bool:
	return _active


## Read-only accessor for tests / external systems that need a direct
## handle on the right panel (e.g. to assert state without traversing the
## scene tree).
func get_right_panel() -> BetaRightPanel:
	return _right_panel


## Read-only accessor for tests / external systems that need a direct
## handle on the event-log panel.
func get_event_log_panel() -> BetaEventLogPanel:
	return _event_log


func _set_visible(v: bool) -> void:
	if _right_panel != null:
		_right_panel.visible = v
	if _event_log != null:
		_event_log.visible = v

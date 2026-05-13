## Tests for the `debug/ui_enabled` two-tier gate on `MomentsTray._ready`.
##
## The committed default is `debug/ui_enabled=false`, so any debug build
## (including headless test runs) starts with the tray hidden. Flipping
## the project setting to `true` at runtime before instantiating the tray
## restores visibility. Release builds (`OS.is_debug_build() == false`)
## always hide, but that branch can't be exercised from a debug test
## binary and is covered by the source contract instead.
extends GutTest

const _SETTING_KEY: String = "debug/ui_enabled"

var _prior_setting: Variant


func before_each() -> void:
	_prior_setting = ProjectSettings.get_setting(_SETTING_KEY, false)


func after_each() -> void:
	ProjectSettings.set_setting(_SETTING_KEY, _prior_setting)


func _make_tray() -> MomentsTray:
	var scene: PackedScene = load("res://game/scenes/ui/moments_tray.tscn")
	var tray: MomentsTray = scene.instantiate() as MomentsTray
	add_child_autofree(tray)
	return tray


func test_committed_default_hides_tray_in_debug_build() -> void:
	# Sanity: the committed project.godot ships with the gate closed so
	# CI / headless screenshot runs stay clean by default.
	assert_false(
		bool(ProjectSettings.get_setting(_SETTING_KEY, false)),
		"debug/ui_enabled must default to false in committed project.godot"
	)
	var tray: MomentsTray = _make_tray()
	assert_false(
		tray.visible,
		"Tray should start hidden when debug/ui_enabled is false"
	)


func test_enabling_setting_restores_tray_visibility() -> void:
	ProjectSettings.set_setting(_SETTING_KEY, true)
	var tray: MomentsTray = _make_tray()
	assert_true(
		tray.visible,
		"Tray should be visible when debug/ui_enabled is true in a debug build"
	)


func test_gate_does_not_disconnect_event_listeners() -> void:
	# Hiding the tray must not block the beta suppression hook from
	# observing the moment_displayed listener — `disable_for_beta()`
	# still needs to disconnect it in beta runs.
	var tray: MomentsTray = _make_tray()
	assert_true(
		EventBus.moment_displayed.is_connected(tray._on_moment_displayed),
		"Tray must still connect moment_displayed even when hidden by gate"
	)


func test_gate_leaves_tray_unsuspended() -> void:
	# Visibility is the only thing the gate touches. Day-cycle code
	# toggles suspension independently, so a fresh gated tray must
	# still report unsuspended for downstream tests / callers.
	var tray: MomentsTray = _make_tray()
	assert_false(
		tray.is_suspended(),
		"Gate must only hide the tray, not suspend its queue machinery"
	)

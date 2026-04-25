## Tests for MetaNotificationOverlay (ISSUE-023) — ambient moments and secret
## threads both surface a card, visibly distinct, and suppress during day-close
## and while a store scene is active.
extends GutTest

const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/meta_notification_overlay.tscn"
)

var _overlay: MetaNotificationOverlay


func before_each() -> void:
	_overlay = _SCENE.instantiate() as MetaNotificationOverlay
	add_child_autofree(_overlay)


# ── Ambient moment surface ────────────────────────────────────────────────────

func test_ambient_moment_signal_spawns_card() -> void:
	EventBus.ambient_moment_delivered.emit(
		&"test_moment", &"toast", "A mysterious note flutters by.", &""
	)
	assert_eq(
		_overlay.get_ambient_card_count(), 1,
		"Ambient signal should spawn one card in the ambient stack"
	)


func test_ambient_empty_text_is_ignored() -> void:
	EventBus.ambient_moment_delivered.emit(&"empty", &"toast", "", &"")
	assert_eq(_overlay.get_ambient_card_count(), 0)


# ── Input focus (does not steal from stores) ─────────────────────────────────

func test_root_and_stacks_pass_mouse_input() -> void:
	var root: Control = _overlay.get_node("Root") as Control
	assert_eq(
		root.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Overlay root must not intercept mouse input"
	)
	assert_eq(
		_overlay.get_ambient_stack().mouse_filter, Control.MOUSE_FILTER_IGNORE
	)


# ── Suppression ───────────────────────────────────────────────────────────────

func test_day_close_suppresses_signals_until_next_day_starts() -> void:
	EventBus.day_closed.emit(1, {})
	EventBus.ambient_moment_delivered.emit(&"m", &"toast", "suppressed", &"")
	assert_eq(
		_overlay.get_ambient_card_count(), 0,
		"Ambient signal during day-close summary must be suppressed"
	)

	EventBus.day_started.emit(2)
	EventBus.ambient_moment_delivered.emit(&"m", &"toast", "post day", &"")
	assert_eq(
		_overlay.get_ambient_card_count(), 1,
		"Signals resume after day_started fires"
	)


func test_store_entered_hides_overlay() -> void:
	EventBus.store_entered.emit(&"retro_games")
	assert_false(_overlay.visible, "Overlay hides while a store scene is active")
	EventBus.ambient_moment_delivered.emit(&"m", &"toast", "inside store", &"")
	assert_eq(
		_overlay.get_ambient_card_count(), 0,
		"Ambient signal while store is active is suppressed"
	)
	EventBus.store_exited.emit(&"retro_games")
	assert_true(_overlay.visible, "Overlay reappears when the store exits")

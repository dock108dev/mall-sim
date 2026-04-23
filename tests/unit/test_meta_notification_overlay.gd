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


# ── Secret thread surface ─────────────────────────────────────────────────────

func test_secret_thread_state_change_spawns_card() -> void:
	EventBus.secret_thread_state_changed.emit(
		&"hidden_shelf", &"dormant", &"stirring"
	)
	assert_eq(
		_overlay.get_secret_card_count(), 1,
		"Secret thread signal should spawn one card in the secret stack"
	)


# ── Distinguishable surfaces ──────────────────────────────────────────────────

func test_ambient_and_secret_surfaces_are_distinguishable() -> void:
	EventBus.ambient_moment_delivered.emit(
		&"m1", &"toast", "ambient body text", &""
	)
	EventBus.secret_thread_state_changed.emit(
		&"t1", &"a", &"b"
	)
	assert_eq(_overlay.get_ambient_card_count(), 1)
	assert_eq(_overlay.get_secret_card_count(), 1)

	var ambient_card: PanelContainer = (
		_overlay.get_ambient_stack().get_child(0) as PanelContainer
	)
	var secret_card: PanelContainer = (
		_overlay.get_secret_stack().get_child(0) as PanelContainer
	)
	assert_eq(
		ambient_card.get_meta(&"variant"),
		MetaNotificationOverlay.AMBIENT_VARIANT,
		"Ambient card carries the ambient variant tag"
	)
	assert_eq(
		secret_card.get_meta(&"variant"),
		MetaNotificationOverlay.SECRET_VARIANT,
		"Secret card carries the secret variant tag"
	)


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
	assert_eq(
		_overlay.get_secret_stack().mouse_filter, Control.MOUSE_FILTER_IGNORE
	)


# ── Suppression ───────────────────────────────────────────────────────────────

func test_day_close_suppresses_signals_until_next_day_starts() -> void:
	EventBus.day_closed.emit(1, {})
	EventBus.ambient_moment_delivered.emit(&"m", &"toast", "suppressed", &"")
	EventBus.secret_thread_state_changed.emit(&"t", &"a", &"b")
	assert_eq(
		_overlay.get_ambient_card_count(), 0,
		"Ambient signal during day-close summary must be suppressed"
	)
	assert_eq(
		_overlay.get_secret_card_count(), 0,
		"Secret signal during day-close summary must be suppressed"
	)

	EventBus.day_started.emit(2)
	EventBus.ambient_moment_delivered.emit(&"m", &"toast", "post day", &"")
	assert_eq(
		_overlay.get_ambient_card_count(), 1,
		"Signals resume after day_started fires"
	)


func test_store_entered_hides_overlay() -> void:
	EventBus.store_entered.emit(&"sneaker_citadel")
	assert_false(_overlay.visible, "Overlay hides while a store scene is active")
	EventBus.ambient_moment_delivered.emit(&"m", &"toast", "inside store", &"")
	assert_eq(
		_overlay.get_ambient_card_count(), 0,
		"Ambient signal while store is active is suppressed"
	)
	EventBus.store_exited.emit(&"sneaker_citadel")
	assert_true(_overlay.visible, "Overlay reappears when the store exits")

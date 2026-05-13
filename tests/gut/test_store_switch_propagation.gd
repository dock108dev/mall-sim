## Smoke test for the active_store_changed signal API. The multi-store panel
## propagation suite that previously lived here was retired with the
## strip-to-bones cut (retro_games is the only surviving store).
extends GutTest


var _signals_received: Array[Dictionary] = []


func before_each() -> void:
	_signals_received.clear()


func test_active_store_changed_signal_exists() -> void:
	assert_true(
		EventBus.has_signal("active_store_changed"),
		"EventBus should have active_store_changed signal"
	)


func test_active_store_changed_emits_on_connect() -> void:
	EventBus.active_store_changed.connect(_on_store_changed)
	EventBus.active_store_changed.emit(&"retro_games")
	assert_eq(
		_signals_received.size(), 1,
		"Should receive one signal emission"
	)
	assert_eq(
		_signals_received[0]["store_id"], &"retro_games",
		"Should receive correct store_id"
	)
	EventBus.active_store_changed.disconnect(_on_store_changed)


func test_active_store_changed_empty_on_exit() -> void:
	EventBus.active_store_changed.connect(_on_store_changed)
	EventBus.active_store_changed.emit(&"")
	assert_eq(
		_signals_received.size(), 1,
		"Should receive signal on hallway exit"
	)
	assert_eq(
		_signals_received[0]["store_id"], &"",
		"Store ID should be empty on hallway exit"
	)
	EventBus.active_store_changed.disconnect(_on_store_changed)


func _on_store_changed(store_id: StringName) -> void:
	_signals_received.append({"store_id": store_id})

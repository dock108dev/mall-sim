## Tests for the unified ActionDrawer: registration, rendering, press routing,
## and per-store controller action descriptors.
extends GutTest


const ACTION_DRAWER_SCENE: PackedScene = preload(
	"res://game/scenes/ui/action_drawer.tscn"
)


var _drawer: ActionDrawer


func before_each() -> void:
	_drawer = ACTION_DRAWER_SCENE.instantiate() as ActionDrawer
	add_child_autofree(_drawer)
	await get_tree().process_frame


func _button_count() -> int:
	return _drawer._button_container.get_child_count()


# ── Registration + rendering ─────────────────────────────────────────────────


func test_drawer_starts_empty() -> void:
	assert_eq(_button_count(), 0, "Drawer should start with no buttons")
	assert_eq(_drawer.get_action_ids().size(), 0)


func test_registers_actions_and_builds_buttons() -> void:
	var actions: Array = [
		{"id": &"stock", "label": "Stock", "icon": ""},
		{"id": &"price", "label": "Price", "icon": ""},
	]
	EventBus.actions_registered.emit(&"retro_games", actions)
	assert_eq(_button_count(), 2, "Drawer should render one button per action")
	assert_eq(_drawer.get_current_store_id(), StringName("retro_games"))
	var ids: Array[StringName] = _drawer.get_action_ids()
	assert_true(ids.has(StringName("stock")))
	assert_true(ids.has(StringName("price")))


func test_re_registration_replaces_buttons() -> void:
	EventBus.actions_registered.emit(
		&"retro_games",
		[{"id": &"stock", "label": "Stock", "icon": ""}]
	)
	assert_eq(_button_count(), 1)
	EventBus.actions_registered.emit(
		&"video_rental",
		[
			{"id": &"rent", "label": "Rent", "icon": ""},
			{"id": &"inspect", "label": "Inspect", "icon": ""},
		]
	)
	assert_eq(_button_count(), 2, "Drawer should rebuild on new registration")
	assert_eq(_drawer.get_current_store_id(), StringName("video_rental"))


func test_store_exited_clears_drawer() -> void:
	EventBus.actions_registered.emit(
		&"retro_games",
		[{"id": &"stock", "label": "Stock", "icon": ""}]
	)
	assert_eq(_button_count(), 1)
	EventBus.store_exited.emit(StringName("retro_games"))
	assert_eq(_button_count(), 0)
	assert_eq(_drawer.get_current_store_id(), StringName(""))


func test_skips_malformed_descriptors() -> void:
	EventBus.actions_registered.emit(
		&"retro_games",
		[
			{"id": &"stock", "label": "Stock", "icon": ""},
			{"label": "Missing id"},
			"not a dict",
		]
	)
	assert_eq(_button_count(), 1, "Only valid descriptors should render")


# ── Press routing ────────────────────────────────────────────────────────────


func test_button_press_emits_action_requested() -> void:
	EventBus.actions_registered.emit(
		&"retro_games",
		[{"id": &"refurbish", "label": "Refurbish", "icon": ""}]
	)
	var captured: Array = []
	var handler: Callable = func(action_id: StringName, store_id: StringName) -> void:
		captured.append([action_id, store_id])
	EventBus.action_requested.connect(handler)
	var button: Button = _drawer._button_container.get_child(0)
	button.pressed.emit()
	EventBus.action_requested.disconnect(handler)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0][0], StringName("refurbish"))
	assert_eq(captured[0][1], StringName("retro_games"))


# ── Store controller action descriptors ──────────────────────────────────────


func _assert_has_action(actions: Array, action_id: StringName, msg: String) -> void:
	var found: bool = false
	for a: Variant in actions:
		if a is Dictionary and StringName(a.get("id", "")) == action_id:
			found = true
			break
	assert_true(found, msg)


func test_base_controller_exposes_core_actions() -> void:
	var c := StoreController.new()
	c.store_type = "retro_games"
	add_child_autofree(c)
	var actions: Array = c.get_store_actions()
	_assert_has_action(actions, &"stock", "base should expose stock")
	_assert_has_action(actions, &"price", "base should expose price")
	_assert_has_action(actions, &"inspect", "base should expose inspect")


func test_retro_games_actions_include_refurbish() -> void:
	var c := RetroGames.new()
	add_child_autofree(c)
	var actions: Array = c.get_store_actions()
	_assert_has_action(actions, &"refurbish", "retro_games exposes refurbish")
	_assert_has_action(actions, &"test", "retro_games exposes test")
	_assert_has_action(actions, &"stock", "retro_games keeps base stock")


func test_video_rental_actions_include_rent() -> void:
	var c := VideoRentalStoreController.new()
	add_child_autofree(c)
	var actions: Array = c.get_store_actions()
	_assert_has_action(actions, &"rent", "video_rental exposes rent")
	_assert_has_action(actions, &"process_returns", "video_rental exposes returns")


func test_electronics_actions_include_warranty() -> void:
	var c := ElectronicsStoreController.new()
	add_child_autofree(c)
	var actions: Array = c.get_store_actions()
	_assert_has_action(actions, &"offer_warranty", "electronics exposes warranty")
	_assert_has_action(actions, &"demo", "electronics exposes demo")


func test_sports_actions_include_authenticate() -> void:
	var c := SportsMemorabiliaController.new()
	add_child_autofree(c)
	var actions: Array = c.get_store_actions()
	_assert_has_action(actions, &"authenticate", "sports exposes authenticate")
	_assert_has_action(actions, &"grade", "sports exposes grade")


func test_pocket_creatures_actions_include_pack() -> void:
	var c := PocketCreaturesStoreController.new()
	add_child_autofree(c)
	var actions: Array = c.get_store_actions()
	_assert_has_action(actions, &"open_pack", "pocket_creatures exposes pack")
	_assert_has_action(actions, &"host_tournament", "pocket_creatures tournament")


func test_emit_actions_registered_reaches_drawer() -> void:
	var c := StoreController.new()
	c.store_type = "retro_games"
	add_child_autofree(c)
	c.emit_actions_registered()
	await get_tree().process_frame
	assert_eq(_drawer.get_current_store_id(), StringName("retro_games"))
	assert_gt(_button_count(), 0)

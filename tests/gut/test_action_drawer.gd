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


# ── Mode enum ────────────────────────────────────────────────────────────────


func test_mode_enum_defines_all_five_modes() -> void:
	assert_eq(ActionDrawer.Mode.IDLE, 0, "IDLE is 0")
	assert_eq(ActionDrawer.Mode.HAGGLE, 1, "HAGGLE is 1")
	assert_eq(ActionDrawer.Mode.REFURB, 2, "REFURB is 2")
	assert_eq(ActionDrawer.Mode.AUTHENTICATE, 3, "AUTHENTICATE is 3")
	assert_eq(ActionDrawer.Mode.WARRANTY, 4, "WARRANTY is 4")
	assert_eq(ActionDrawer.Mode.TRADE, 5, "TRADE is 5")


func test_drawer_starts_in_idle_mode() -> void:
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


# ── Mode switching via open_mode ─────────────────────────────────────────────


func test_open_mode_sets_current_mode() -> void:
	_drawer.open_mode(ActionDrawer.Mode.HAGGLE)
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.HAGGLE)


func test_close_mode_resets_to_idle() -> void:
	_drawer.open_mode(ActionDrawer.Mode.WARRANTY)
	_drawer.close_mode()
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


func test_open_mode_idle_arg_closes() -> void:
	_drawer.open_mode(ActionDrawer.Mode.REFURB)
	_drawer.open_mode(ActionDrawer.Mode.IDLE)
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


# ── Mode switching via action_requested ──────────────────────────────────────


func _register_store_with_actions(store_id: StringName, action_ids: Array) -> void:
	var actions: Array = []
	for aid: StringName in action_ids:
		actions.append({"id": aid, "label": String(aid), "icon": ""})
	EventBus.actions_registered.emit(store_id, actions)


func test_haggle_action_opens_haggle_mode() -> void:
	_register_store_with_actions(&"retro_games", [&"haggle"])
	EventBus.action_requested.emit(&"haggle", &"retro_games")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.HAGGLE)


func test_refurbish_action_opens_refurb_mode() -> void:
	_register_store_with_actions(&"retro_games", [&"refurbish"])
	EventBus.action_requested.emit(&"refurbish", &"retro_games")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.REFURB)


func test_authenticate_action_opens_auth_mode() -> void:
	_register_store_with_actions(&"sports", [&"authenticate"])
	EventBus.action_requested.emit(&"authenticate", &"sports")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.AUTHENTICATE)


func test_warranty_action_opens_warranty_mode() -> void:
	_register_store_with_actions(&"electronics", [&"offer_warranty"])
	EventBus.action_requested.emit(&"offer_warranty", &"electronics")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.WARRANTY)


func test_trade_action_opens_trade_mode() -> void:
	_register_store_with_actions(&"pocket_creatures", [&"open_pack"])
	EventBus.action_requested.emit(&"open_pack", &"pocket_creatures")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.TRADE)


func test_unknown_action_does_not_open_mode() -> void:
	_register_store_with_actions(&"retro_games", [&"stock"])
	EventBus.action_requested.emit(&"stock", &"retro_games")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


func test_wrong_store_action_does_not_open_mode() -> void:
	_register_store_with_actions(&"retro_games", [&"haggle"])
	EventBus.action_requested.emit(&"haggle", &"other_store")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


func test_store_exited_closes_active_mode() -> void:
	_register_store_with_actions(&"retro_games", [&"refurbish"])
	EventBus.action_requested.emit(&"refurbish", &"retro_games")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.REFURB)
	EventBus.store_exited.emit(&"retro_games")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


# ── EventBus signal emission ──────────────────────────────────────────────────


func test_open_mode_emits_action_drawer_opened() -> void:
	var captured: Array = []
	var handler: Callable = func(mode: int) -> void:
		captured.append(mode)
	EventBus.action_drawer_opened.connect(handler)
	_drawer.open_mode(ActionDrawer.Mode.HAGGLE)
	EventBus.action_drawer_opened.disconnect(handler)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], ActionDrawer.Mode.HAGGLE as int)


func test_close_mode_emits_action_drawer_closed() -> void:
	_drawer.open_mode(ActionDrawer.Mode.REFURB)
	var captured: Array = []
	var handler: Callable = func() -> void:
		captured.append(true)
	EventBus.action_drawer_closed.connect(handler)
	_drawer.close_mode()
	EventBus.action_drawer_closed.disconnect(handler)
	assert_eq(captured.size(), 1)


func test_haggle_accept_emits_player_accepted_signal() -> void:
	_register_store_with_actions(&"retro_games", [&"haggle"])
	_drawer.open_mode(ActionDrawer.Mode.HAGGLE)
	var captured: Array = []
	var handler: Callable = func() -> void:
		captured.append(true)
	EventBus.haggle_player_accepted.connect(handler)
	_drawer._on_haggle_accept()
	EventBus.haggle_player_accepted.disconnect(handler)
	assert_eq(captured.size(), 1, "Accept should emit haggle_player_accepted")
	assert_eq(_drawer.get_current_mode(), ActionDrawer.Mode.IDLE)


func test_haggle_decline_emits_player_declined_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.HAGGLE)
	var captured: Array = []
	var handler: Callable = func() -> void:
		captured.append(true)
	EventBus.haggle_player_declined.connect(handler)
	_drawer._on_haggle_decline()
	EventBus.haggle_player_declined.disconnect(handler)
	assert_eq(captured.size(), 1, "Decline should emit haggle_player_declined")


func test_haggle_counter_emits_player_countered_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.HAGGLE)
	var captured_price: Array = []
	var handler: Callable = func(price: float) -> void:
		captured_price.append(price)
	EventBus.haggle_player_countered.connect(handler)
	_drawer._on_haggle_counter()
	EventBus.haggle_player_countered.disconnect(handler)
	assert_eq(captured_price.size(), 1, "Counter should emit haggle_player_countered")


func test_warranty_accept_emits_player_accepted_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.WARRANTY)
	var captured: Array = []
	var handler: Callable = func(_item_id: String, _tier_id: String) -> void:
		captured.append(true)
	EventBus.warranty_player_accepted.connect(handler)
	_drawer._on_warranty_accept()
	EventBus.warranty_player_accepted.disconnect(handler)
	assert_eq(captured.size(), 1, "Warranty accept should emit warranty_player_accepted")


func test_warranty_decline_emits_player_declined_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.WARRANTY)
	var captured: Array = []
	var handler: Callable = func(_item_id: String) -> void:
		captured.append(true)
	EventBus.warranty_player_declined.connect(handler)
	_drawer._on_warranty_decline()
	EventBus.warranty_player_declined.disconnect(handler)
	assert_eq(captured.size(), 1, "Warranty decline should emit warranty_player_declined")


func test_auth_tier_selected_emits_submitted_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.AUTHENTICATE)
	var captured: Array = []
	var handler: Callable = func(_item_id: String, tier: int) -> void:
		captured.append(tier)
	EventBus.authentication_player_submitted.connect(handler)
	_drawer._on_auth_tier_selected(1)
	EventBus.authentication_player_submitted.disconnect(handler)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], 1, "Tier 1 should be emitted")


func test_trade_accept_emits_player_accepted_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.TRADE)
	var captured: Array = []
	var handler: Callable = func() -> void:
		captured.append(true)
	EventBus.trade_player_accepted.connect(handler)
	_drawer._on_trade_accept()
	EventBus.trade_player_accepted.disconnect(handler)
	assert_eq(captured.size(), 1, "Trade accept should emit trade_player_accepted")


func test_trade_decline_emits_player_declined_signal() -> void:
	_drawer.open_mode(ActionDrawer.Mode.TRADE)
	var captured: Array = []
	var handler: Callable = func() -> void:
		captured.append(true)
	EventBus.trade_player_declined.connect(handler)
	_drawer._on_trade_decline()
	EventBus.trade_player_declined.disconnect(handler)
	assert_eq(captured.size(), 1, "Trade decline should emit trade_player_declined")


func test_refurb_start_emits_queued_signal() -> void:
	_register_store_with_actions(&"retro_games", [&"refurbish"])
	_drawer.open_mode(ActionDrawer.Mode.REFURB)
	var captured: Array = []
	var handler: Callable = func(store_id: StringName) -> void:
		captured.append(store_id)
	EventBus.refurb_player_queued.connect(handler)
	_drawer._on_refurb_start()
	EventBus.refurb_player_queued.disconnect(handler)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0], StringName("retro_games"))


# ── Haggle negotiation_started opens HAGGLE mode ─────────────────────────────


func test_haggle_negotiation_started_opens_haggle_mode() -> void:
	EventBus.haggle_negotiation_started.emit(
		"Widget", "Good", 20.0, 15.0, 3, 10.0
	)
	assert_eq(
		_drawer.get_current_mode(), ActionDrawer.Mode.HAGGLE,
		"haggle_negotiation_started should switch to HAGGLE mode"
	)


func test_haggle_completed_closes_haggle_mode() -> void:
	_drawer.open_mode(ActionDrawer.Mode.HAGGLE)
	EventBus.haggle_completed.emit(&"retro_games", &"item_1", 18.0, 20.0, true, 2)
	assert_eq(
		_drawer.get_current_mode(), ActionDrawer.Mode.IDLE,
		"haggle_completed should close to IDLE"
	)


func test_warranty_offer_presented_opens_warranty_mode() -> void:
	EventBus.warranty_offer_presented.emit("item_electronics_1")
	assert_eq(
		_drawer.get_current_mode(), ActionDrawer.Mode.WARRANTY,
		"warranty_offer_presented should open WARRANTY mode"
	)


func test_auth_dialog_requested_opens_authenticate_mode() -> void:
	EventBus.authentication_dialog_requested.emit("card_001")
	assert_eq(
		_drawer.get_current_mode(), ActionDrawer.Mode.AUTHENTICATE,
		"authentication_dialog_requested should open AUTHENTICATE mode"
	)

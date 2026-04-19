## Connects EventBus signals to AudioManager for SFX and BGM switching.
extends Node


var _audio: Node


func initialize(audio_manager: Node) -> void:
	_audio = audio_manager
	_connect_sfx_signals()
	_connect_state_signals()


func _connect_sfx_signals() -> void:
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.customer_ready_to_purchase.connect(
		_on_customer_ready_to_purchase
	)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.haggle_started.connect(_on_haggle_started)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.haggle_failed.connect(_on_haggle_failed)
	EventBus.milestone_unlocked.connect(_on_milestone_unlocked)
	EventBus.fixture_placed.connect(_on_fixture_placed)
	EventBus.fixture_placement_invalid.connect(_on_fixture_placement_invalid)
	EventBus.pack_opened.connect(_on_pack_opened)
	EventBus.refurbishment_started.connect(_on_refurbishment_started)
	EventBus.refurbishment_completed.connect(_on_refurbishment_completed)
	EventBus.item_rented.connect(_on_item_rented)
	EventBus.authentication_completed.connect(_on_authentication_completed)
	EventBus.demo_item_placed.connect(_on_demo_item_placed)


func _connect_state_signals() -> void:
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.storefront_entered.connect(_on_storefront_entered)
	EventBus.storefront_exited.connect(_on_storefront_exited)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)


func _on_item_sold(_id: String, _p: float, _c: String) -> void:
	_audio.play_sfx("purchase_chime")


func _on_customer_ready_to_purchase(_d: Dictionary) -> void:
	_audio.play_sfx("cash_register")


func _on_customer_entered(_d: Dictionary) -> void:
	_audio.play_sfx("door_bell")


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	_audio.play_sfx("purchase_ding")


func _on_item_stocked(_id: String, _shelf: String) -> void:
	_audio.play_sfx("item_placement")


func _on_day_started(_day: int) -> void:
	_audio.play_bgm("mall_open_music", 0.5)


func _on_day_ended(_day: int) -> void:
	_audio.play_sfx("day_end_chime")
	_audio.play_bgm("mall_close_music", 1.0)


func _on_reputation_changed(_store_id: String, _new: float) -> void:
	_audio.play_sfx("notification_ping")


func _on_haggle_started(_item_id: String, _customer_id: int) -> void:
	_audio.play_sfx("haggle_start")


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	accepted: bool, _offer_count: int
) -> void:
	if accepted:
		_audio.play_sfx("haggle_accept")


func _on_haggle_failed(_item_id: String, _customer_id: int) -> void:
	_audio.play_sfx("haggle_reject")


func _on_milestone_unlocked(
	_milestone_id: StringName, _reward: Dictionary
) -> void:
	_audio.play_sfx("milestone_pop")


func _on_fixture_placed(
	_fid: String, _pos: Vector2i, _rot: int
) -> void:
	_audio.play_sfx("build_place")


func _on_fixture_placement_invalid(_reason: String) -> void:
	_audio.play_sfx("build_error")


func _on_pack_opened(_pack_id: String, _cards: Array[String]) -> void:
	_audio.play_sfx("pack_opening")


func _on_refurbishment_started(
	_item_id: String, _cost: float, _duration: int
) -> void:
	_audio.play_sfx("refurbish_start")


func _on_refurbishment_completed(
	_item_id: String, _success: bool, _condition: String
) -> void:
	_audio.play_sfx("refurbish_complete")


func _on_item_rented(
	_item_id: String, _fee: float, _tier: String
) -> void:
	_audio.play_sfx("tape_insert")


func _on_authentication_completed(
	_item_id: Variant, _is_genuine: bool, _result: Variant = null
) -> void:
	_audio.play_sfx("auth_reveal")


func _on_demo_item_placed(_item_id: String) -> void:
	_audio.play_sfx("demo_activate")


func _on_game_state_changed(_old: int, new_state: int) -> void:
	match new_state:
		GameManager.GameState.MAIN_MENU:
			_audio.play_bgm("menu_music")
			_audio.stop_ambient()
		GameManager.GameState.DAY_SUMMARY:
			_audio.play_bgm("day_summary_music")
		GameManager.GameState.GAMEPLAY:
			_play_store_music()
			_play_store_ambient()
		GameManager.GameState.GAME_OVER:
			_audio.stop_bgm(2.0)


func _on_store_entered(_store_id: StringName) -> void:
	# Store interiors use play_ambient / BGM from storefront + active_store handlers.
	# enter_zone() is only for hallway-registered zone IDs (see HallwayAmbientZones).
	pass


func _on_store_exited(_store_id: StringName) -> void:
	pass


func _on_storefront_entered(_slot: int, store_id: String) -> void:
	_play_store_music_for(store_id)
	_play_store_ambient_for(store_id)


func _on_storefront_exited() -> void:
	_audio.play_bgm("mall_hallway_music")
	_audio.play_ambient("mall_hallway")


func _on_active_store_changed(store_id: StringName) -> void:
	_play_store_music_for(String(store_id))
	_play_store_ambient_for(String(store_id))


func _on_day_phase_changed(_new_phase: int) -> void:
	_play_store_music()


func _on_build_mode_entered() -> void:
	_audio.play_sfx("build_mode_enter")
	_audio.play_bgm("build_mode_music", 0.3)


func _on_build_mode_exited() -> void:
	_audio.play_bgm("mall_open_music", 0.3)


func _play_store_music() -> void:
	var store_id: String = String(GameManager.get_active_store_id())
	if store_id.is_empty():
		_audio.play_bgm("mall_hallway_music")
		return
	_play_store_music_for(store_id)


func _play_store_music_for(store_id: String) -> void:
	if not ContentRegistry.exists(store_id):
		_audio.play_bgm("mall_hallway_music")
		return
	var canonical: StringName = ContentRegistry.resolve(store_id)
	var store_def: StoreDefinition = ContentRegistry.get_store_definition(
		canonical
	)
	if store_def == null:
		_audio.play_bgm("mall_hallway_music")
		return

	var music_path: String = store_def.music
	if music_path.is_empty():
		_audio.play_bgm("mall_hallway_music")
		return

	_audio.play_bgm(music_path)


func _play_store_ambient() -> void:
	var store_id: String = String(GameManager.get_active_store_id())
	if store_id.is_empty():
		_audio.play_ambient("mall_hallway")
		return
	_play_store_ambient_for(store_id)


func _play_store_ambient_for(store_id: String) -> void:
	if not ContentRegistry.exists(store_id):
		_audio.play_ambient("mall_hallway")
		return
	var canonical: StringName = ContentRegistry.resolve(store_id)
	var store_def: StoreDefinition = ContentRegistry.get_store_definition(
		canonical
	)
	if store_def == null:
		_audio.play_ambient("mall_hallway")
		return

	var ambient_path: String = store_def.ambient_sound
	if ambient_path.is_empty():
		_audio.play_ambient("mall_hallway")
		return

	_audio.play_ambient(ambient_path)

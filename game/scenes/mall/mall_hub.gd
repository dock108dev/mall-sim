## Persistent root gameplay scene: the mall hub.
## Hosts five StorefrontCards and decorative ambient customer sprites over a
## game_world child that owns all runtime systems. Store mechanics are launched
## via slide-out drawers in response to EventBus.storefront_clicked.
## Also hosts the KPI strip (instantiated at runtime) and routes objective
## store-routing signals to card highlight effects.
class_name MallHub
extends Node

const AMBIENCE_KEY: String = "food_court_murmur"
const DUCK_DB: float = -12.0
const DUCK_DURATION: float = 0.3

## ISSUE-015: clickable Sneaker Citadel tile invokes StoreDirector directly.
## DESIGN.md §2.1 — the director, not SceneRouter, owns the store lifecycle.
const SNEAKER_CITADEL_ID: StringName = &"sneaker_citadel"
const _CHECKPOINT_HUB_CAMERA_OK: StringName = &"mall_hub_camera_ok"

# Test seam — unit tests inject a mock StoreDirector to verify activation
# without booting the full director state machine.
var _director_override: Node = null
var _input_focus_pushed: bool = false

const _KPI_SCENE: PackedScene = preload("res://game/scenes/ui/kpi_strip.tscn")
const _SETTINGS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)

var _duck_tween: Tween = null
var _normal_volume_db: float = -6.0
var _kpi_strip: Control = null
var _settings_panel: SettingsPanel = null

@onready var _storefront_row: Node2D = $HubLayer/ConcourseRoot/StorefrontRow
@onready var _ambient_layer: Node2D = $HubLayer/ConcourseRoot/AmbientCustomers
@onready var _ambience_player: AudioStreamPlayer = $HubAmbiencePlayer
@onready var _hub_layer: CanvasLayer = $HubLayer
@onready var _sneaker_citadel_tile: Button = %SneakerCitadelTile


func _ready() -> void:
	EventBus.storefront_clicked.connect(_on_storefront_clicked)
	EventBus.drawer_opened.connect(_on_drawer_opened)
	EventBus.drawer_closed.connect(_on_drawer_closed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.objective_updated.connect(_on_objective_updated)
	_start_hub_ambience()
	_setup_kpi_strip()
	_wire_sneaker_citadel_tile()
	_push_mall_hub_input_focus()
	_connect_store_director_failed()
	call_deferred("_assert_mall_hub_camera")
	if AuditLog != null:
		AuditLog.pass_check(&"mall_hub_ready", "from=mall_hub.gd")


func _exit_tree() -> void:
	_pop_mall_hub_input_focus()
	_disconnect_store_director_failed()


## Returns the five storefront cards in slot order. Used by tests.
func get_storefront_cards() -> Array[StorefrontCard]:
	var cards: Array[StorefrontCard] = []
	for child: Node in _storefront_row.get_children():
		var card: StorefrontCard = child as StorefrontCard
		if card != null:
			cards.append(card)
	return cards


func _setup_kpi_strip() -> void:
	_kpi_strip = _KPI_SCENE.instantiate() as Control
	_hub_layer.add_child(_kpi_strip)
	_kpi_strip.anchor_left = 0.0
	_kpi_strip.anchor_top = 0.0
	_kpi_strip.anchor_right = 1.0
	_kpi_strip.anchor_bottom = 0.0
	_kpi_strip.offset_left = 0.0
	_kpi_strip.offset_top = 0.0
	_kpi_strip.offset_right = 0.0
	_kpi_strip.offset_bottom = 64.0


func _on_settings_pressed() -> void:
	if _settings_panel == null:
		_settings_panel = _SETTINGS_PANEL_SCENE.instantiate() as SettingsPanel
		add_child(_settings_panel)
	_settings_panel.open()


func _on_storefront_clicked(store_id: StringName) -> void:
	EventBus.enter_store_requested.emit(store_id)


func _on_store_entered(_store_id: StringName) -> void:
	_storefront_row.hide()
	_ambient_layer.hide()
	if _kpi_strip != null:
		_kpi_strip.hide()


func _on_store_exited(_store_id: StringName) -> void:
	_storefront_row.show()
	_ambient_layer.show()
	if _kpi_strip != null:
		_kpi_strip.show()


## When an objective payload carries a "goto:<store_id>" optional_hint,
## highlight the matching store card so the player can act immediately.
func _on_objective_updated(payload: Dictionary) -> void:
	var hint: String = str(payload.get("optional_hint", ""))
	if hint.begins_with("goto:"):
		var target_id: StringName = StringName(hint.substr(5))
		EventBus.hub_store_highlighted.emit(target_id)


func _start_hub_ambience() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = AudioManager.get_ambient_stream(AMBIENCE_KEY)
	if stream == null:
		return
	_normal_volume_db = _ambience_player.volume_db
	_ambience_player.stream = stream
	_ambience_player.play()


func _on_drawer_opened(_store_id: StringName) -> void:
	if not _ambience_player.playing:
		return
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_property(
		_ambience_player, "volume_db", DUCK_DB, DUCK_DURATION
	)


func _on_drawer_closed(_store_id: StringName) -> void:
	if not _ambience_player.playing:
		return
	_kill_duck_tween()
	_duck_tween = create_tween()
	_duck_tween.tween_property(
		_ambience_player, "volume_db", _normal_volume_db, DUCK_DURATION
	)


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


# ── ISSUE-015: Sneaker Citadel tile + StoreDirector handoff ────────────────

## Test seam — unit tests inject a mock director so activation can be verified
## without spinning up the full StoreDirector state machine.
func set_director_for_tests(director: Node) -> void:
	_director_override = director


## Activates Sneaker Citadel via StoreDirector.enter_store. DESIGN.md §2.1
## designates the director (not SceneRouter) as the sole owner of the store
## lifecycle, so the hub never calls change_scene_to_* directly.
func activate_sneaker_citadel() -> void:
	var director: Node = _get_store_director()
	if director == null:
		push_error("[MallHub] StoreDirector unavailable; cannot enter %s"
			% SNEAKER_CITADEL_ID)
		return
	assert(director.has_method("enter_store"),
		"StoreDirector missing enter_store(store_id)")
	director.call("enter_store", SNEAKER_CITADEL_ID)


func _wire_sneaker_citadel_tile() -> void:
	if _sneaker_citadel_tile == null:
		return
	if not _sneaker_citadel_tile.pressed.is_connected(activate_sneaker_citadel):
		_sneaker_citadel_tile.pressed.connect(activate_sneaker_citadel)


func _push_mall_hub_input_focus() -> void:
	if InputFocus == null:
		return
	InputFocus.push_context(InputFocus.CTX_MALL_HUB)
	_input_focus_pushed = true


func _pop_mall_hub_input_focus() -> void:
	if not _input_focus_pushed:
		return
	if InputFocus == null:
		_input_focus_pushed = false
		return
	# Only pop if our context is still on top — modals or scene-pushers may
	# have stacked above us; popping their context here would corrupt the
	# stack invariant InputFocus enforces.
	if InputFocus.current() == InputFocus.CTX_MALL_HUB:
		InputFocus.pop_context()
	_input_focus_pushed = false


func _connect_store_director_failed() -> void:
	var director: Node = _get_store_director()
	if director == null or not director.has_signal("store_failed"):
		return
	if not director.store_failed.is_connected(_on_store_director_failed):
		director.store_failed.connect(_on_store_director_failed)


func _disconnect_store_director_failed() -> void:
	var director: Node = _get_store_director()
	if director == null or not director.has_signal("store_failed"):
		return
	if director.store_failed.is_connected(_on_store_director_failed):
		director.store_failed.disconnect(_on_store_director_failed)


func _on_store_director_failed(store_id: StringName, reason: String) -> void:
	if store_id != SNEAKER_CITADEL_ID:
		return
	# Surface the failure on the inline ErrorBanner (the Phase-1 fail card).
	# The dedicated ISSUE-018 fail_card will replace this when it lands.
	if ErrorBanner != null and ErrorBanner.has_method("show_failure"):
		ErrorBanner.show_failure(
			"Store entry failed",
			"%s: %s" % [store_id, reason]
		)
	# Hub stays in the scene tree and the tile remains focusable so the player
	# can retry — the ErrorBanner overlays without freeing the hub.


func _assert_mall_hub_camera() -> void:
	if CameraAuthority == null or not CameraAuthority.has_method("assert_single_active"):
		return
	if not CameraAuthority.assert_single_active():
		return
	if AuditLog != null:
		AuditLog.pass_check(_CHECKPOINT_HUB_CAMERA_OK,
			"source=mall_hub current=%s" % [CameraAuthority.current_source()])


func _get_store_director() -> Node:
	if _director_override != null:
		return _director_override
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("StoreDirector")

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

const _KPI_SCENE: PackedScene = preload("res://game/scenes/ui/kpi_strip.tscn")
const _SETTINGS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)

@onready var _storefront_row: Node2D = $HubLayer/ConcourseRoot/StorefrontRow
@onready var _ambient_layer: Node2D = $HubLayer/ConcourseRoot/AmbientCustomers
@onready var _ambience_player: AudioStreamPlayer = $HubAmbiencePlayer
@onready var _hub_layer: CanvasLayer = $HubLayer

var _duck_tween: Tween = null
var _normal_volume_db: float = -6.0
var _kpi_strip: Control = null
var _settings_panel: SettingsPanel = null


func _ready() -> void:
	EventBus.storefront_clicked.connect(_on_storefront_clicked)
	EventBus.drawer_opened.connect(_on_drawer_opened)
	EventBus.drawer_closed.connect(_on_drawer_closed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.objective_updated.connect(_on_objective_updated)
	_start_hub_ambience()
	_setup_kpi_strip()


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

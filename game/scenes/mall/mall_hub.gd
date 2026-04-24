## Persistent root gameplay scene: the mall hub.
## Hosts the game_world child that owns all runtime systems, plus the
## concourse backdrop, hub UI overlay, and ambience player. The five store
## cards live in `MallOverview` (instantiated by `game_world` into its UI
## layer, data-driven from `ContentRegistry`) — the hub does not carry its
## own hardcoded storefront row (per ADR 0007 and
## docs/audits/phase0-ui-integrity.md P1.2).
## Also hosts the KPI strip (instantiated at runtime) and routes objective
## store-routing signals to card highlight effects.
class_name MallHub
extends Node

const AMBIENCE_KEY: String = "food_court_murmur"
const DUCK_DB: float = -12.0
const DUCK_DURATION: float = 0.3

const _CHECKPOINT_HUB_CAMERA_OK: StringName = &"mall_hub_camera_ok"

var _input_focus_pushed: bool = false

const _KPI_SCENE: PackedScene = preload("res://game/scenes/ui/kpi_strip.tscn")
const _SETTINGS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)
const _META_NOTIFICATION_SCENE: PackedScene = preload(
	"res://game/scenes/ui/meta_notification_overlay.tscn"
)

var _duck_tween: Tween = null
var _normal_volume_db: float = -6.0
var _kpi_strip: Control = null
var _settings_panel: SettingsPanel = null
var _meta_notifications: MetaNotificationOverlay = null

@onready var _ambience_player: AudioStreamPlayer = $HubAmbiencePlayer
@onready var _hub_layer: CanvasLayer = $HubLayer
@onready var _hub_ui_overlay: Control = $HubLayer/HubUIOverlay


func _ready() -> void:
	EventBus.drawer_opened.connect(_on_drawer_opened)
	EventBus.drawer_closed.connect(_on_drawer_closed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	_start_hub_ambience()
	_setup_kpi_strip()
	_setup_meta_notifications()
	_push_mall_hub_input_focus()
	call_deferred("_assert_mall_hub_camera")
	if AuditLog != null:
		AuditLog.pass_check(&"mall_hub_ready", "from=mall_hub.gd")


func _exit_tree() -> void:
	_pop_mall_hub_input_focus()


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


## ISSUE-023: hub-level surface for ambient-moment and secret-thread signals.
## Lives under the hub layer so it inherently does not exist during boot
## (mall_hub is post-boot) and auto-hides when a store scene is active.
func _setup_meta_notifications() -> void:
	_meta_notifications = _META_NOTIFICATION_SCENE.instantiate() as MetaNotificationOverlay
	_hub_layer.add_child(_meta_notifications)


func _on_settings_pressed() -> void:
	if _settings_panel == null:
		_settings_panel = _SETTINGS_PANEL_SCENE.instantiate() as SettingsPanel
		add_child(_settings_panel)
	_settings_panel.open()


## ISSUE-022: Progress button routes to the Completion Tracker panel via
## EventBus so the hub stays decoupled from the panel instance (which lives
## under game_world's UI layer).
func _on_progress_pressed() -> void:
	EventBus.toggle_completion_tracker_panel.emit()


func _on_store_entered(_store_id: StringName) -> void:
	if _kpi_strip != null:
		_kpi_strip.hide()
	_set_hub_input_enabled(false)


func _on_store_exited(_store_id: StringName) -> void:
	if _kpi_strip != null:
		_kpi_strip.show()
	_set_hub_input_enabled(true)


## ISSUE-002: while a store scene is active, the mall hub shares the viewport.
## Hub Controls must not intercept clicks or a player-click inside the store
## would navigate away. Acceptance: hub Controls are IGNORE + DISABLED.
## The store-card UI (`MallOverview`) is owned by `game_world` and hides
## itself on `EventBus.store_entered` (see `mall_overview.gd`).
func _set_hub_input_enabled(enabled: bool) -> void:
	if _hub_ui_overlay != null:
		_hub_ui_overlay.visible = enabled
		# Overlay itself stays MOUSE_FILTER_IGNORE (its Button children are the
		# STOP targets); toggling visibility + process_mode is what blocks them.
		_hub_ui_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hub_ui_overlay.process_mode = (
			Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		)


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


func _assert_mall_hub_camera() -> void:
	# Camera authority only applies when the walkable 3D mall is active. In the
	# default click-to-enter hub mode (game_world.gd:212-217) the scene is a
	# pure 2D UI with no Camera3D, so the single-active-camera assert is
	# inapplicable and would always fail with zero cameras in the group.
	if not ProjectSettings.get_setting("debug/walkable_mall", false):
		return
	if CameraAuthority == null or not CameraAuthority.has_method("assert_single_active"):
		return
	if not CameraAuthority.assert_single_active():
		return
	if AuditLog != null:
		AuditLog.pass_check(_CHECKPOINT_HUB_CAMERA_OK,
			"source=mall_hub current=%s" % [CameraAuthority.current_source()])

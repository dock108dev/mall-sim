## Single slide-out drawer host for all five store mechanic UIs.
##
## Lives on a CanvasLayer over the mall hub. Opens and closes via Tween on the
## drawer panel's custom_minimum_size.x; no AnimationPlayer is involved.
##
## Mouse filtering contract:
##  - The drawer panel (self) uses MOUSE_FILTER_STOP so world clicks cannot pass
##    through while it is visible.
##  - The HUD root (the full-rect Control parent on the CanvasLayer) is kept at
##    MOUSE_FILTER_IGNORE whenever the drawer is closed so hub clicks reach the
##    StorefrontCard Area2D nodes beneath.
##
## Opening drawer A while drawer B is active first closes B (no overlapping
## drawers ever render). Emits EventBus.drawer_opened / drawer_closed with the
## store_id on each transition.
class_name DrawerHost
extends PanelContainer

const OPEN_WIDTH: float = 420.0
const CLOSED_WIDTH: float = 0.0
const TWEEN_DURATION: float = 0.25

var _active_store_id: StringName = &""
var _tween: Tween

@onready var _hud_root: Control = get_parent() as Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = CLOSED_WIDTH
	visible = false
	_set_hud_root_pass_through(true)
	EventBus.storefront_clicked.connect(_on_storefront_clicked)
	EventBus.exit_store_requested.connect(_on_exit_store_requested)


## Returns the currently open store id, or &"" if closed.
func get_active_store_id() -> StringName:
	return _active_store_id


## True while a store drawer is open (including its opening transition).
func is_open() -> bool:
	return _active_store_id != &""


## Opens the drawer for store_id. If another store's drawer is open, that one
## is closed first and drawer_closed is emitted before drawer_opened fires.
func open_drawer(store_id: StringName) -> void:
	if store_id == &"":
		push_warning("DrawerHost.open_drawer called with empty store_id")
		return
	if _active_store_id == store_id and is_open():
		return
	if _active_store_id != &"":
		_close_immediate(_active_store_id)
	_active_store_id = store_id
	visible = true
	_set_hud_root_pass_through(false)
	EventBus.drawer_opened.emit(store_id)
	_animate_width(OPEN_WIDTH)


## Closes the active drawer, if any. Emits drawer_closed for the store that
## was open.
func close_drawer() -> void:
	if _active_store_id == &"":
		return
	var closing_store: StringName = _active_store_id
	_active_store_id = &""
	EventBus.drawer_closed.emit(closing_store)
	_animate_width(CLOSED_WIDTH)
	_set_hud_root_pass_through(true)


func _close_immediate(store_id: StringName) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	custom_minimum_size.x = CLOSED_WIDTH
	_active_store_id = &""
	EventBus.drawer_closed.emit(store_id)


func _animate_width(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "custom_minimum_size:x", target, TWEEN_DURATION)
	if target == CLOSED_WIDTH:
		_tween.finished.connect(_on_close_tween_finished)


func _on_close_tween_finished() -> void:
	if _active_store_id == &"":
		visible = false


func _set_hud_root_pass_through(pass_through: bool) -> void:
	if _hud_root == null:
		return
	_hud_root.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if pass_through else Control.MOUSE_FILTER_STOP
	)


func _on_storefront_clicked(store_id: StringName) -> void:
	open_drawer(store_id)


func _on_exit_store_requested() -> void:
	close_drawer()

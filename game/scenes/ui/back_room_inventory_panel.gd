## Back-room inventory audit panel.
##
## Renders a two-column expected-vs-actual stock readout for the active store
## and exposes a per-row Flag Discrepancy button for any line where the counts
## diverge. Pressing Flag emits `EventBus.inventory_variance_noted` via the
## owning RetroGames controller, which dedupes per-SKU per-day so repeat
## presses are no-ops.
class_name BackRoomInventoryPanel
extends CanvasLayer

const PANEL_NAME: String = "back_room_inventory"

var _controller: Object = null
var _is_open: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: GridContainer = $PanelRoot/Margin/VBox/Grid
@onready var _close_button: Button = $PanelRoot/Margin/VBox/CloseButton
@onready var _empty_label: Label = $PanelRoot/Margin/VBox/EmptyLabel


func _ready() -> void:
	_panel.visible = true
	_is_open = true
	_close_button.pressed.connect(_on_close)
	EventBus.panel_opened.emit(PANEL_NAME)
	_refresh()


## Wire the panel to its owning store controller. Required before _ready
## reads rows.
func set_controller(controller: Object) -> void:
	_controller = controller
	if is_inside_tree():
		_refresh()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	EventBus.panel_closed.emit(PANEL_NAME)
	queue_free()


func is_open() -> bool:
	return _is_open


func _refresh() -> void:
	# §F-137 — UI-panel defensive guards. _grid is an @onready binding to a
	# scene node and can only be null pre-_ready; the controller absence
	# branch is hit when set_controller has not yet been called by RetroGames
	# (Tier-3 store init). A hardening push would fire on every test that
	# instantiates the panel headlessly without a paired RetroGames host.
	# Malformed row entries are filtered by RetroGames.get_inventory_audit_rows
	# before they reach this view; the row-shape guard here is a belt-and-
	# braces defensive filter, not a content-authoring failure surface.
	if _grid == null:
		return
	for child: Node in _grid.get_children():
		child.queue_free()
	var rows: Array = []
	if _controller != null and _controller.has_method("get_inventory_audit_rows"):
		rows = _controller.call("get_inventory_audit_rows")
	if rows.is_empty():
		_empty_label.visible = true
		return
	_empty_label.visible = false
	_add_header()
	for row_data: Variant in rows:
		if row_data is Dictionary:
			_add_row(row_data as Dictionary)


func _add_header() -> void:
	_grid.add_child(_make_header_label("Item"))
	_grid.add_child(_make_header_label("Expected"))
	_grid.add_child(_make_header_label("Actual"))
	_grid.add_child(_make_header_label("Action"))


func _add_row(row: Dictionary) -> void:
	var name_label := Label.new()
	name_label.text = String(row.get("item_name", row.get("item_id", "")))
	_grid.add_child(name_label)

	var expected_label := Label.new()
	expected_label.text = str(int(row.get("expected", 0)))
	expected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grid.add_child(expected_label)

	var actual_label := Label.new()
	actual_label.text = str(int(row.get("actual", 0)))
	actual_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grid.add_child(actual_label)

	var mismatched: bool = bool(row.get("mismatched", false))
	var flagged: bool = bool(row.get("flagged", false))
	if mismatched:
		var flag_button := Button.new()
		flag_button.text = "Flagged" if flagged else "Flag Discrepancy"
		flag_button.disabled = flagged
		var item_id: StringName = StringName(str(row.get("item_id", "")))
		var expected: int = int(row.get("expected", 0))
		var actual: int = int(row.get("actual", 0))
		flag_button.pressed.connect(
			func() -> void: _on_flag_pressed(item_id, expected, actual)
		)
		_grid.add_child(flag_button)
	else:
		var ok_label := Label.new()
		ok_label.text = "OK"
		_grid.add_child(ok_label)


func _make_header_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_flag_pressed(item_id: StringName, expected: int, actual: int) -> void:
	# §F-137 — same defensive controller-guard family as _refresh above.
	# The flag button is only built when set_controller has wired a non-null
	# controller; a button press without a controller is unreachable in the
	# production flow (panel + flag rows are constructed under a single
	# _refresh call after set_controller). flagged_now == false is a normal
	# de-dupe outcome from RetroGames.flag_discrepancy (already-flagged this
	# day for this item), not an error path.
	if _controller == null or not _controller.has_method("flag_discrepancy"):
		return
	var flagged_now: bool = bool(_controller.call(
		"flag_discrepancy", item_id, expected, actual,
	))
	if flagged_now:
		_refresh()


func _on_close() -> void:
	close()

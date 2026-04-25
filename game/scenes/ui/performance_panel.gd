## 7-day rolling performance history panel — accessible from the mall hub.
## Shows per-day revenue / customer count with delta coloring and a best-day stat.
## Follows the MomentsLogPanel slide-in pattern; mutual-exclusion via panel_opened.
class_name PerformancePanel
extends CanvasLayer


const PANEL_NAME: String = "performance"
const MAX_HISTORY_ROWS: int = 7
const POSITIVE_COLOR := Color(0.35, 0.85, 0.35)
const NEGATIVE_COLOR := Color(0.9, 0.45, 0.45)
const DIM_COLOR := Color(0.65, 0.65, 0.65)

var performance_report_system: PerformanceReportSystem = null
var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _best_day_label: Label = (
	$PanelRoot/Margin/VBox/BestDayLabel
)
@onready var _grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Scroll/Grid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.performance_report_ready.connect(_on_report_ready)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_refresh()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(_panel, _rest_x, false)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _refresh() -> void:
	_clear_grid()
	if not performance_report_system:
		_best_day_label.text = "Best Day: —"
		_add_empty_label()
		return
	var history: Array[PerformanceReport] = (
		performance_report_system.get_history()
	)
	_update_best_day_label(history)
	_populate_table(history)


func _update_best_day_label(
	history: Array[PerformanceReport]
) -> void:
	if history.is_empty():
		_best_day_label.text = "Best Day: —"
		return
	var best: PerformanceReport = null
	for r: PerformanceReport in history:
		if best == null or r.revenue > best.revenue:
			best = r
	_best_day_label.text = (
		"Best Day: Day %d — $%.2f (%d customers)"
		% [best.day, best.revenue, best.customers_served]
	)


func _populate_table(history: Array[PerformanceReport]) -> void:
	var recent: Array[PerformanceReport] = history
	if recent.size() > MAX_HISTORY_ROWS:
		recent = recent.slice(recent.size() - MAX_HISTORY_ROWS)
	if recent.is_empty():
		_add_empty_label()
		return
	_add_header_row()
	var prev_revenue: float = -1.0
	var prev_customers: int = -1
	for r: PerformanceReport in recent:
		_add_day_row(r, prev_revenue, prev_customers)
		for store_id: String in r.store_revenue:
			_add_store_row(store_id, r.store_revenue[store_id])
		_grid.add_child(HSeparator.new())
		prev_revenue = r.revenue
		prev_customers = r.customers_served


func _add_header_row() -> void:
	var row := HBoxContainer.new()
	var labels: Array[String] = ["Day", "Revenue", "Customers"]
	var widths: Array[int] = [55, 130, 110]
	for j: int in range(labels.size()):
		var lbl := Label.new()
		lbl.text = labels[j]
		lbl.custom_minimum_size.x = widths[j]
		lbl.add_theme_color_override("font_color", DIM_COLOR)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
	_grid.add_child(row)
	_grid.add_child(HSeparator.new())


func _add_day_row(
	r: PerformanceReport, prev_rev: float, prev_cust: int
) -> void:
	var row := HBoxContainer.new()

	var day_lbl := Label.new()
	day_lbl.text = "Day %d" % r.day
	day_lbl.custom_minimum_size.x = 55
	row.add_child(day_lbl)

	var rev_lbl := Label.new()
	rev_lbl.custom_minimum_size.x = 130
	if prev_rev < 0.0:
		rev_lbl.text = "$%.2f" % r.revenue
	else:
		var delta: float = r.revenue - prev_rev
		var pct: float = (
			(delta / max(prev_rev, 0.01)) * 100.0
		)
		var sign: String = "+" if delta >= 0.0 else ""
		rev_lbl.text = "$%.2f  (%s%.0f%%)" % [r.revenue, sign, pct]
		if delta > 0.0:
			rev_lbl.add_theme_color_override(
				"font_color", POSITIVE_COLOR
			)
		elif delta < 0.0:
			rev_lbl.add_theme_color_override(
				"font_color", NEGATIVE_COLOR
			)
	row.add_child(rev_lbl)

	var cust_lbl := Label.new()
	cust_lbl.custom_minimum_size.x = 110
	if prev_cust < 0:
		cust_lbl.text = "%d" % r.customers_served
	else:
		var delta: int = r.customers_served - prev_cust
		var sign: String = "+" if delta >= 0 else ""
		if delta != 0:
			cust_lbl.text = (
				"%d  (%s%d)" % [r.customers_served, sign, delta]
			)
		else:
			cust_lbl.text = "%d" % r.customers_served
		if delta > 0:
			cust_lbl.add_theme_color_override(
				"font_color", POSITIVE_COLOR
			)
		elif delta < 0:
			cust_lbl.add_theme_color_override(
				"font_color", NEGATIVE_COLOR
			)
	row.add_child(cust_lbl)

	_grid.add_child(row)


func _add_store_row(store_id: String, revenue: float) -> void:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "  %s" % store_id.capitalize()
	name_lbl.custom_minimum_size.x = 185
	name_lbl.add_theme_color_override("font_color", DIM_COLOR)
	name_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(name_lbl)
	var rev_lbl := Label.new()
	rev_lbl.text = "$%.2f" % revenue
	rev_lbl.add_theme_color_override("font_color", DIM_COLOR)
	rev_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(rev_lbl)
	_grid.add_child(row)


func _add_empty_label() -> void:
	var lbl := Label.new()
	lbl.text = "No performance data yet."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", DIM_COLOR)
	_grid.add_child(lbl)


func _clear_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_report_ready(_report: PerformanceReport) -> void:
	if _is_open:
		_refresh()

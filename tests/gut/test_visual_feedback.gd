## Tests for VisualFeedback floating text and expense notification animations.
extends GutTest


var _vf: VisualFeedback
const _VFScene: PackedScene = preload(
	"res://game/scenes/ui/visual_feedback.tscn"
)


func before_each() -> void:
	_vf = _VFScene.instantiate()
	add_child_autofree(_vf)


func test_item_sold_spawns_floating_label() -> void:
	var child_count_before: int = _vf.get_child_count()
	EventBus.item_sold.emit("test_item", 25.99, "electronics")
	assert_gt(
		_vf.get_child_count(), child_count_before,
		"Should spawn a floating label on item_sold"
	)


func test_floating_label_text_format() -> void:
	EventBus.item_sold.emit("test_item", 12.50, "games")
	var label: Label = _find_last_label()
	assert_not_null(label, "Should have spawned a label")
	if label:
		assert_eq(label.text, "+$12.50")


func test_floating_label_uses_positive_color() -> void:
	EventBus.item_sold.emit("test_item", 10.0, "cards")
	var label: Label = _find_last_label()
	assert_not_null(label, "Should have spawned a label")
	if label:
		var expected: Color = UIThemeConstants.get_positive_color()
		assert_eq(label.modulate, expected)


func test_floating_label_freed_after_animation() -> void:
	EventBus.item_sold.emit("test_item", 5.0, "sports")
	var label: Label = _find_last_label()
	assert_not_null(label, "Should have spawned a label")
	await get_tree().create_timer(1.2).timeout
	assert_false(
		is_instance_valid(label),
		"Label should be freed after float duration"
	)


func test_multiple_sales_spawn_multiple_labels() -> void:
	var before: int = _vf.get_child_count()
	EventBus.item_sold.emit("a", 10.0, "x")
	EventBus.item_sold.emit("b", 20.0, "y")
	assert_eq(
		_vf.get_child_count(), before + 2,
		"Each sale should spawn its own floating label"
	)


func test_expense_notification_shows_on_decrease() -> void:
	EventBus.money_changed.emit(500.0, 400.0)
	assert_true(
		_vf._expense_label.visible,
		"Expense label should show on money decrease"
	)
	assert_eq(_vf._expense_label.text, "-$100.00")


func test_no_expense_notification_on_increase() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	assert_false(
		_vf._expense_label.visible,
		"Expense label should not show on money increase"
	)


func test_float_distance_is_40px() -> void:
	assert_eq(
		VisualFeedback.FLOAT_DISTANCE, 40.0,
		"Float distance should be 40 pixels"
	)


func test_float_duration_matches_spec() -> void:
	assert_eq(
		VisualFeedback.FLOAT_DURATION, 0.8,
		"Float duration should be 0.8 seconds"
	)


func _find_last_label() -> Label:
	var children: Array[Node] = []
	for child: Node in _vf.get_children():
		if child is Label and child != _vf._expense_label:
			children.append(child)
	if children.is_empty():
		return null
	return children[children.size() - 1] as Label

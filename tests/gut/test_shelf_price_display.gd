## GUT tests for ISSUE-012: shelf display labels and audit checkpoint wiring.
## Tests verify that inventory_open / shelf_stock / price_set signals trigger the
## correct audit checkpoint, and that ShelfSlot.set_display_data / clear_display_data
## create and manage the Label3D info label correctly.
extends GutTest


# ── Audit checkpoint signal wiring ───────────────────────────────────────────

func test_inventory_open_checkpoint_fires_on_panel_opened_inventory() -> void:
	var triggered: bool = false
	var on_panel: Callable = func(panel_name: String) -> void:
		if panel_name == "inventory":
			triggered = true
	EventBus.panel_opened.connect(on_panel)
	EventBus.panel_opened.emit("inventory")
	EventBus.panel_opened.disconnect(on_panel)
	assert_true(triggered, "panel_opened('inventory') must trigger inventory_open checkpoint")


func test_other_panel_open_does_not_trigger_inventory_open() -> void:
	var triggered: bool = false
	var on_panel: Callable = func(panel_name: String) -> void:
		if panel_name == "inventory":
			triggered = true
	EventBus.panel_opened.connect(on_panel)
	EventBus.panel_opened.emit("pricing")
	EventBus.panel_opened.disconnect(on_panel)
	assert_false(triggered, "panel_opened('pricing') must not trigger inventory_open checkpoint")


func test_shelf_stock_checkpoint_fires_on_item_stocked() -> void:
	var triggered: bool = false
	var on_stocked: Callable = func(_iid: String, _sid: String) -> void:
		triggered = true
	EventBus.item_stocked.connect(on_stocked)
	EventBus.item_stocked.emit("test_item_001", "cart_left_1")
	EventBus.item_stocked.disconnect(on_stocked)
	assert_true(triggered, "item_stocked must trigger shelf_stock checkpoint")


func test_price_set_checkpoint_fires_on_price_set() -> void:
	var triggered: bool = false
	var on_price: Callable = func(_iid: String, _price: float) -> void:
		triggered = true
	EventBus.price_set.connect(on_price)
	EventBus.price_set.emit("test_item_001", 42.0)
	EventBus.price_set.disconnect(on_price)
	assert_true(triggered, "price_set signal must trigger price_set checkpoint")


# ── ShelfSlot.set_display_data / clear_display_data ──────────────────────────

func _make_slot() -> ShelfSlot:
	var slot := ShelfSlot.new()
	slot.slot_id = "test_slot_1"
	add_child_autofree(slot)
	return slot


func test_set_display_data_creates_label3d_child() -> void:
	var slot := _make_slot()
	slot.set_display_data("Orbital Smash Arena", "good", 35.0)
	var label: Label3D = _find_label3d(slot)
	assert_not_null(label, "set_display_data must add a Label3D child")


func test_set_display_data_label_is_visible() -> void:
	var slot := _make_slot()
	slot.set_display_data("Orbital Smash Arena", "good", 35.0)
	var label: Label3D = _find_label3d(slot)
	assert_not_null(label, "Label3D child must exist")
	assert_true(label.visible, "Label3D must be visible after set_display_data")


func test_set_display_data_text_contains_item_name() -> void:
	var slot := _make_slot()
	slot.set_display_data("Canopy 64 Legends", "near_mint", 88.0)
	var label: Label3D = _find_label3d(slot)
	assert_not_null(label, "Label3D must exist")
	assert_true(
		label.text.contains("Canopy 64 Legends"),
		"Label3D text must contain the item name"
	)


func test_set_display_data_text_contains_price() -> void:
	var slot := _make_slot()
	slot.set_display_data("Neo Spark Racer", "fair", 22.50)
	var label: Label3D = _find_label3d(slot)
	assert_not_null(label, "Label3D must exist")
	assert_true(
		label.text.contains("22.50"),
		"Label3D text must contain the formatted price"
	)


func test_set_display_data_second_call_updates_text() -> void:
	var slot := _make_slot()
	slot.set_display_data("Old Name", "poor", 5.0)
	slot.set_display_data("New Name", "mint", 120.0)
	var labels: Array[Label3D] = _find_all_label3d(slot)
	assert_eq(labels.size(), 1, "second call must reuse the existing Label3D, not add another")
	assert_true(labels[0].text.contains("New Name"), "updated text must show new item name")


func test_clear_display_data_hides_label() -> void:
	var slot := _make_slot()
	slot.set_display_data("Test Cart", "mint", 20.0)
	slot.clear_display_data()
	var label: Label3D = _find_label3d(slot)
	if label:
		assert_false(label.visible, "Label3D must be hidden after clear_display_data")


func test_remove_item_clears_display() -> void:
	var slot := _make_slot()
	slot.place_item("fake_instance_id")
	slot.set_display_data("Some Game", "good", 30.0)
	slot.remove_item()
	var label: Label3D = _find_label3d(slot)
	if label:
		assert_false(label.visible, "Label3D must be hidden after remove_item")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _find_label3d(node: Node) -> Label3D:
	for child: Node in node.get_children():
		if child is Label3D:
			return child as Label3D
	return null


func _find_all_label3d(node: Node) -> Array[Label3D]:
	var result: Array[Label3D] = []
	for child: Node in node.get_children():
		if child is Label3D:
			result.append(child as Label3D)
	return result

## Tests for SaveLoadPanel Assisted badge display in slot rows.
extends GutTest


const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/save_load_panel.tscn"
)

const _TEST_SLOT: int = 3
const _SAVE_DIR: String = "user://saves/"

var _panel: SaveLoadPanel
var _save_manager: SaveManager


func before_each() -> void:
	_panel = _SCENE.instantiate() as SaveLoadPanel
	add_child_autofree(_panel)

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)

	_panel.save_manager = _save_manager


func after_each() -> void:
	var path: String = _SAVE_DIR + "slot_%d.json" % _TEST_SLOT
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_mock_save(used_downgrade: bool) -> void:
	DirAccess.make_dir_recursive_absolute(_SAVE_DIR)
	var path: String = _SAVE_DIR + "slot_%d.json" % _TEST_SLOT
	var mock_data: Dictionary = {
		"save_version": SaveManager.CURRENT_SAVE_VERSION,
		"save_metadata": {
			"day": 7,
			"cash": 3000.0,
			"owned_stores": ["retro_games"],
			"saved_at": "2026-01-01T00:00:00",
		},
		"difficulty": {
			"current_tier": "easy",
			"used_difficulty_downgrade": used_downgrade,
		},
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(mock_data))
		file.close()


func _find_assisted_label_in_slot_row(row: Node) -> Label:
	for child: Node in row.get_children():
		var assisted: Label = _find_assisted_label_recursive(child)
		if assisted:
			return assisted
	return null


func _find_assisted_label_recursive(node: Node) -> Label:
	for child: Node in node.get_children():
		if child is Label and (child as Label).text == "Assisted":
			return child as Label
		var found: Label = _find_assisted_label_recursive(child)
		if found:
			return found
	return null


## Assisted badge appears in the slot row when used_difficulty_downgrade is true.
func test_assisted_badge_shown_when_flag_is_true() -> void:
	_write_mock_save(true)
	_panel.open_load()

	var slot_container: VBoxContainer = _panel._slot_container
	var assisted_found: Array = [false]
	for row: Node in slot_container.get_children():
		var label: Label = _find_assisted_label_in_slot_row(row)
		if label:
			assisted_found[0] = true
			break

	assert_true(
		assisted_found[0],
		"Assisted badge should appear in slot row when used_difficulty_downgrade is true"
	)


## No Assisted badge when used_difficulty_downgrade is false.
func test_assisted_badge_absent_when_flag_is_false() -> void:
	_write_mock_save(false)
	_panel.open_load()

	var slot_container: VBoxContainer = _panel._slot_container
	var assisted_found: Array = [false]
	for row: Node in slot_container.get_children():
		var label: Label = _find_assisted_label_in_slot_row(row)
		if label:
			assisted_found[0] = true
			break

	assert_false(
		assisted_found[0],
		"Assisted badge should not appear when used_difficulty_downgrade is false"
	)


## Assisted badge has a non-empty tooltip text.
func test_assisted_badge_has_tooltip() -> void:
	_write_mock_save(true)
	_panel.open_load()

	var slot_container: VBoxContainer = _panel._slot_container
	var assisted_label: Label = null
	for row: Node in slot_container.get_children():
		var label: Label = _find_assisted_label_in_slot_row(row)
		if label:
			assisted_label = label
			break

	assert_not_null(
		assisted_label,
		"Assisted label must exist to check tooltip"
	)
	if assisted_label:
		assert_true(
			assisted_label.tooltip_text.length() > 0,
			"Assisted badge must have a non-empty tooltip"
		)


## Assisted badge uses MOUSE_FILTER_PASS to receive hover events for tooltip.
func test_assisted_badge_mouse_filter_pass() -> void:
	_write_mock_save(true)
	_panel.open_load()

	var slot_container: VBoxContainer = _panel._slot_container
	var assisted_label: Label = null
	for row: Node in slot_container.get_children():
		var label: Label = _find_assisted_label_in_slot_row(row)
		if label:
			assisted_label = label
			break

	assert_not_null(
		assisted_label,
		"Assisted label must exist to check mouse_filter"
	)
	if assisted_label:
		assert_eq(
			assisted_label.mouse_filter,
			Control.MOUSE_FILTER_PASS,
			"Assisted badge must use MOUSE_FILTER_PASS to show tooltip on hover"
		)

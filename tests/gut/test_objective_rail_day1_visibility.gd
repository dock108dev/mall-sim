## Verifies the Day 1 ObjectiveRail surfaces the canonical "Stock your first
## item and make a sale" guidance with the "Press I to open inventory" action
## and an "I" key badge, that the rail occupies a different screen zone than
## the InteractionPrompt, and that the Day1ReadinessAudit objective check
## passes once the day starts and the player enters the store.
extends GutTest


const _OBJECTIVE_TEXT: String = "Stock your first item and make a sale"
const _ACTION_TEXT: String = "Press I to open inventory"
const _KEY_TEXT: String = "I"

const _RAIL_SCENE: String = "res://game/scenes/ui/objective_rail.tscn"
const _PROMPT_SCENE: String = "res://game/scenes/ui/interaction_prompt.tscn"

var _saved_state: GameManager.State
var _saved_show_rail: bool
var _saved_director_day: int
var _saved_director_stocked: bool
var _saved_director_sold: bool
var _saved_director_loop: bool
var _saved_first_sale_flag: bool


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_show_rail = Settings.show_objective_rail
	_saved_director_day = ObjectiveDirector._current_day
	_saved_director_stocked = ObjectiveDirector._stocked
	_saved_director_sold = ObjectiveDirector._sold
	_saved_director_loop = ObjectiveDirector._loop_completed
	_saved_first_sale_flag = bool(GameState.get_flag(&"first_sale_complete"))
	GameManager.current_state = GameManager.State.STORE_VIEW
	Settings.show_objective_rail = true
	ObjectiveDirector._current_day = 0
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed = false
	GameState.set_flag(&"first_sale_complete", false)


func after_each() -> void:
	GameManager.current_state = _saved_state
	Settings.show_objective_rail = _saved_show_rail
	ObjectiveDirector._current_day = _saved_director_day
	ObjectiveDirector._stocked = _saved_director_stocked
	ObjectiveDirector._sold = _saved_director_sold
	ObjectiveDirector._loop_completed = _saved_director_loop
	GameState.set_flag(&"first_sale_complete", _saved_first_sale_flag)
	if InputFocus != null:
		InputFocus._reset_for_tests()


func _make_rail() -> CanvasLayer:
	var rail: CanvasLayer = preload(
		"res://game/scenes/ui/objective_rail.tscn"
	).instantiate() as CanvasLayer
	add_child_autofree(rail)
	return rail


# ── Day 1 content surfacing ────────────────────────────────────────────────────

func test_rail_visible_on_day1_after_day_started_and_store_entered() -> void:
	var rail := _make_rail()
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(&"retro_games")
	assert_true(
		rail.visible,
		"ObjectiveRail must be visible in STORE_VIEW with Day 1 payload and no modal"
	)


func test_objective_label_shows_stock_first_item_text_on_day1() -> void:
	var rail := _make_rail()
	EventBus.day_started.emit(1)
	assert_eq(rail._objective_label.text, _OBJECTIVE_TEXT)


func test_action_label_shows_press_i_on_day1() -> void:
	var rail := _make_rail()
	EventBus.day_started.emit(1)
	assert_eq(rail._action_label.text, _ACTION_TEXT)


func test_hint_badge_shows_letter_i_on_day1() -> void:
	var rail := _make_rail()
	EventBus.day_started.emit(1)
	assert_eq(rail._hint_label.text, _KEY_TEXT)
	assert_true(
		rail._hint_label.visible,
		"Day 1 key badge 'I' must be visible alongside the action hint"
	)


# ── Legibility at 1920x1080 ────────────────────────────────────────────────────

func test_project_theme_label_font_size_meets_legibility_floor() -> void:
	# Visual grammar (docs/style/visual-grammar.md) treats <18pt body text as a
	# merge-blocker. The rail's Labels carry no font_size override, so they
	# resolve through the project theme. Verify the project theme keeps Label
	# at the 18pt floor that gives the Day 1 guidance legibility at 1920x1080.
	var theme_src: String = FileAccess.get_file_as_string(
		"res://game/themes/mallcore_theme.tres"
	)
	assert_ne(theme_src, "", "mallcore_theme.tres must be readable")
	assert_true(
		theme_src.contains("Label/font_sizes/font_size = 18"),
		"Project theme must keep Label font_size >= 18 for 1080p legibility"
	)


func test_rail_labels_have_no_smaller_font_override() -> void:
	# Defensive: if the rail later adds a theme_override_font_sizes/font_size,
	# it must not push body text below the 18pt grammar floor.
	var rail_src: String = FileAccess.get_file_as_string(_RAIL_SCENE)
	assert_ne(rail_src, "", "objective_rail.tscn must be readable")
	var idx: int = rail_src.find("theme_override_font_sizes/font_size = ")
	while idx != -1:
		var rest: String = rail_src.substr(
			idx + "theme_override_font_sizes/font_size = ".length()
		)
		var line_end: int = rest.find("\n")
		if line_end == -1:
			line_end = rest.length()
		var value: int = int(rest.substr(0, line_end))
		assert_true(
			value >= 18,
			"objective_rail.tscn font_size override %d must be >= 18" % value
		)
		idx = rail_src.find(
			"theme_override_font_sizes/font_size = ", idx + 1
		)


# ── Zone separation: rail vs InteractionPrompt ─────────────────────────────────

func _y_range_from_scene(scene_path: String, node_marker: String) -> Vector2:
	# Parses the offset_top / offset_bottom of the first node block matching
	# `node_marker` in the .tscn source. Returns Vector2(top, bottom) in pixels
	# from the bottom of the screen (positive = pixels above bottom).
	var src: String = FileAccess.get_file_as_string(scene_path)
	assert_ne(src, "", "scene must be readable: %s" % scene_path)
	var marker_idx: int = src.find(node_marker)
	assert_gt(marker_idx, -1, "scene %s must contain node block %s"
		% [scene_path, node_marker])
	var block: String = src.substr(marker_idx)
	var next_block: int = block.find("\n\n[")
	if next_block != -1:
		block = block.substr(0, next_block)
	var top: float = _extract_offset(block, "offset_top")
	var bottom: float = _extract_offset(block, "offset_bottom")
	# Anchored to bottom (anchor_bottom=1.0): positive distance = -offset.
	return Vector2(-top, -bottom)


func _extract_offset(block: String, key: String) -> float:
	var needle: String = "%s = " % key
	var idx: int = block.find(needle)
	if idx == -1:
		return 0.0
	var rest: String = block.substr(idx + needle.length())
	var end: int = rest.find("\n")
	if end == -1:
		end = rest.length()
	return float(rest.substr(0, end))


func test_interaction_prompt_zone_does_not_overlap_objective_rail_zone() -> void:
	var rail_range: Vector2 = _y_range_from_scene(
		_RAIL_SCENE, '[node name="MarginContainer" type="MarginContainer" parent="."]'
	)
	var band_range: Vector2 = _y_range_from_scene(
		_RAIL_SCENE, '[node name="AccentBand" type="ColorRect" parent="."]'
	)
	var prompt_range: Vector2 = _y_range_from_scene(
		_PROMPT_SCENE, '[node name="PanelContainer" type="PanelContainer" parent="."]'
	)
	# rail occupies [rail_range.y .. rail_range.x] px from bottom (margin
	# container) plus the 4px accent band [band_range.y .. band_range.x].
	# Combined upper edge = max(rail_range.x, band_range.x).
	var rail_top: float = max(rail_range.x, band_range.x)
	var rail_bottom: float = min(rail_range.y, band_range.y)
	var prompt_top: float = prompt_range.x
	var prompt_bottom: float = prompt_range.y
	# Prompt must sit fully above rail: prompt_bottom >= rail_top.
	assert_true(
		prompt_bottom >= rail_top,
		(
			"InteractionPrompt bottom edge (%.0fpx from bottom) must clear "
			+ "ObjectiveRail top edge (%.0fpx from bottom). Rail [%.0f..%.0f], "
			+ "prompt [%.0f..%.0f]."
		) % [
			prompt_bottom, rail_top,
			rail_bottom, rail_top, prompt_bottom, prompt_top
		]
	)


# ── Stocked flag triggers ObjectiveDirector update ────────────────────────────

func test_item_stocked_triggers_rail_update_after_day_started() -> void:
	var rail := _make_rail()
	EventBus.day_started.emit(1)
	# Mutate label texts so we can detect the re-emission.
	rail._objective_label.text = ""
	rail._action_label.text = ""
	EventBus.item_stocked.emit("item_001", "shelf_a")
	assert_eq(
		rail._objective_label.text, _OBJECTIVE_TEXT,
		"item_stocked must re-emit the Day 1 objective payload to the rail"
	)
	assert_eq(rail._action_label.text, _ACTION_TEXT)


# ── Day1ReadinessAudit objective check ────────────────────────────────────────

func test_day1_readiness_objective_check_passes_after_day1_payload() -> void:
	# ObjectiveRail is the production autoload; the rail consumes payload in
	# _ready, so emitting day_started after the autoload is alive populates
	# _current_payload before Day1ReadinessAudit reads it.
	EventBus.day_started.emit(1)
	EventBus.store_entered.emit(&"retro_games")
	assert_true(
		ObjectiveRail.has_active_objective(),
		"Day1ReadinessAudit check 8 (has_active_objective) must be true on Day 1"
	)

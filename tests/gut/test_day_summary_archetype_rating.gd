## Coverage for the archetype/floor-awareness/attention-notes block on the
## DaySummary panel. Verifies the inspection-count thresholds drive the
## right archetype label, the per-archetype subtext copy, the 1..5 star
## floor-awareness rendering, and the attention-notes visibility gate.
extends GutTest


const ARCHETYPE_MARK := "The Mark"
const ARCHETYPE_WARM_BODY := "The Warm Body"
const ARCHETYPE_FLOOR_WALKER := "The Floor Walker"
const ARCHETYPE_PAPER_TRAIL := "The Paper Trail"
const ARCHETYPE_COMPANY_PERSON := "The Company Person"

const PATH_FALL_GUY := "Fall Guy"
const PATH_SALES_FLOOR := "Sales Floor"
const PATH_FLOOR_LEAD := "Floor Lead"
const PATH_ASSISTANT_MANAGER := "Assistant Manager"
const PATH_REGIONAL_LIAISON := "Regional Liaison"

var _day_summary: DaySummary
var _focus: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	if _focus != null:
		_focus._reset_for_tests()
	var panel_scene: PackedScene = load(
		"res://game/scenes/ui/day_summary.tscn"
	)
	_day_summary = panel_scene.instantiate() as DaySummary
	add_child_autofree(_day_summary)


func after_each() -> void:
	if is_instance_valid(_day_summary):
		_day_summary._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _archetype_for(count: int) -> String:
	return DayCycleController._compute_day_archetype(
		{"hidden_thread_interactions": count}
	)


func _stars_for(count: int) -> int:
	return DayCycleController._compute_floor_awareness_stars(
		{"hidden_thread_interactions": count}
	)


func test_zero_interactions_yields_the_mark() -> void:
	assert_eq(
		_archetype_for(0), ARCHETYPE_MARK,
		"0 hidden interactions must resolve to 'The Mark'"
	)


func test_one_interaction_yields_warm_body() -> void:
	assert_eq(_archetype_for(1), ARCHETYPE_WARM_BODY)


func test_two_interactions_yields_floor_walker() -> void:
	assert_eq(_archetype_for(2), ARCHETYPE_FLOOR_WALKER)


func test_three_interactions_yields_paper_trail() -> void:
	assert_eq(_archetype_for(3), ARCHETYPE_PAPER_TRAIL)


func test_four_interactions_yields_paper_trail() -> void:
	assert_eq(_archetype_for(4), ARCHETYPE_PAPER_TRAIL)


func test_five_interactions_yields_company_person() -> void:
	assert_eq(_archetype_for(5), ARCHETYPE_COMPANY_PERSON)


func test_ten_interactions_still_company_person() -> void:
	assert_eq(_archetype_for(10), ARCHETYPE_COMPANY_PERSON)


func test_floor_stars_minimum_is_one() -> void:
	assert_eq(
		_stars_for(0), 1,
		"0 interactions must yield 1 star — there is no 0-star result"
	)


func test_floor_stars_thresholds() -> void:
	assert_eq(_stars_for(1), 2)
	assert_eq(_stars_for(2), 3)
	assert_eq(_stars_for(3), 4)
	assert_eq(_stars_for(4), 4)
	assert_eq(_stars_for(5), 5)
	assert_eq(_stars_for(99), 5)


func test_archetype_label_renders_when_archetype_passed() -> void:
	_day_summary.show_summary(
		1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_WARM_BODY, 2, [],
	)
	assert_true(_day_summary._archetype_label.visible)
	assert_eq(_day_summary._archetype_label.text, ARCHETYPE_WARM_BODY)


func test_archetype_label_hidden_when_archetype_empty() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_false(_day_summary._archetype_label.visible)
	assert_false(_day_summary._archetype_subtext_label.visible)


func test_archetype_subtext_carries_path_line() -> void:
	_day_summary.show_summary(
		1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_FLOOR_WALKER, 3, [],
	)
	assert_string_contains(
		_day_summary._archetype_subtext_label.text, PATH_FLOOR_LEAD,
		"Floor Walker subtext must mention the Floor Lead path"
	)
	assert_string_contains(
		_day_summary._archetype_subtext_label.text, "full Mallcore",
		"Path framing must mention 'full Mallcore' as natural expansion"
	)


func test_subtext_path_per_archetype() -> void:
	var pairs: Array = [
		[ARCHETYPE_MARK, PATH_FALL_GUY],
		[ARCHETYPE_WARM_BODY, PATH_SALES_FLOOR],
		[ARCHETYPE_FLOOR_WALKER, PATH_FLOOR_LEAD],
		[ARCHETYPE_PAPER_TRAIL, PATH_ASSISTANT_MANAGER],
		[ARCHETYPE_COMPANY_PERSON, PATH_REGIONAL_LIAISON],
	]
	for pair in pairs:
		_day_summary.show_summary(
			1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
			pair[0], 1, [],
		)
		assert_string_contains(
			_day_summary._archetype_subtext_label.text, pair[1],
			"%s subtext must mention path %s" % [pair[0], pair[1]]
		)


func test_the_mark_carries_framed_fired_copy() -> void:
	_day_summary.show_summary(
		1, 0.0, 25.0, -25.0, 0, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_MARK, 1, [],
	)
	assert_string_contains(
		_day_summary._archetype_subtext_label.text,
		"Vic says not to come in tomorrow",
		"The Mark must show the framed/fired Vic line"
	)
	assert_string_contains(
		_day_summary._archetype_subtext_label.text,
		"harmless, unlucky, or useful to blame",
		"The Mark must show the framed/fired body"
	)


func test_floor_stars_render_with_unicode_chars() -> void:
	_day_summary.show_summary(
		1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_WARM_BODY, 1, [],
	)
	assert_eq(
		_day_summary._floor_stars_label.text, "★☆☆☆☆",
		"1 star must render as ★☆☆☆☆"
	)
	_day_summary.show_summary(
		1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_COMPANY_PERSON, 5, [],
	)
	assert_eq(
		_day_summary._floor_stars_label.text, "★★★★★",
		"5 stars must render as ★★★★★"
	)


func test_attention_notes_hidden_when_empty() -> void:
	_day_summary.show_summary(
		1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_WARM_BODY, 2, [],
	)
	assert_false(_day_summary._attention_notes_label.visible)
	assert_false(_day_summary._attention_separator.visible)


func test_attention_notes_visible_when_populated() -> void:
	var notes: Array = [
		"2 customer(s) left empty-handed — shelf ran dry.",
		"Inventory variance at 8% — check backroom counts.",
	]
	_day_summary.show_summary(
		1, 100.0, 25.0, 75.0, 4, 0.0, 0.0, 0.0, "", 0.0, 0.0,
		ARCHETYPE_WARM_BODY, 2, notes,
	)
	assert_true(_day_summary._attention_notes_label.visible)
	assert_true(_day_summary._attention_separator.visible)
	assert_string_contains(
		_day_summary._attention_notes_label.text, "shelf ran dry"
	)


func test_replay_button_present_in_button_row() -> void:
	assert_true(
		is_instance_valid(_day_summary._replay_button),
		"Replay button must be wired in ButtonRow"
	)
	assert_true(_day_summary._replay_button.visible)
	assert_string_contains(
		_day_summary._replay_button.text, "Replay Day 1",
		"Replay button text must mention 'Replay Day 1'"
	)


func test_continue_button_hidden_in_beta() -> void:
	assert_false(
		_day_summary._continue_button.visible,
		"Next Day button must be hidden in single-day beta"
	)


func test_existing_call_signature_still_works() -> void:
	# The 5-arg call form used by every legacy test must still render without
	# raising — defaults preserve backward compat.
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_true(_day_summary.visible)


func test_attention_notes_capped_at_four() -> void:
	var payload: Dictionary = {
		"items_sold": 0,
		"shelf_inventory_remaining": 0,
		"backroom_inventory_remaining": 10,
		"inventory_remaining": 10,
		"discrepancy": 0.10,
		"shift_summary": {
			"customers_happy": 0,
			"customers_no_stock": 5,
			"customers_timeout": 4,
			"customers_price": 5,
		},
	}
	var notes: Array[String] = (
		DayCycleController._build_attention_notes(payload)
	)
	assert_lte(notes.size(), 4, "Attention notes must cap at 4")

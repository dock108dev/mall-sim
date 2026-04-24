## Phase 0.1 P1.3 regression test: tutorial step text is sourced from the
## localization CSV via `tr()` and rendered by `TutorialOverlay` only.
## `ObjectiveDirector` no longer carries a tutorial branch and
## `game/content/tutorial_steps.json` is deleted (the duplicate source).
extends GutTest


func test_tutorial_steps_json_is_deleted() -> void:
	assert_false(
		FileAccess.file_exists("res://game/content/tutorial_steps.json"),
		"tutorial_steps.json must be deleted (SSOT is translations.en.csv)"
	)


func test_objective_director_has_no_tutorial_branch() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/autoload/objective_director.gd"
	)
	assert_false(
		src.contains("_load_tutorial_steps"),
		"ObjectiveDirector must not load tutorial_steps.json"
	)
	assert_false(
		src.contains("tutorial_step_changed"),
		"ObjectiveDirector must not subscribe to tutorial_step_changed"
	)
	assert_false(
		src.contains("_tutorial_active"),
		"ObjectiveDirector must not carry tutorial state"
	)


func test_tutorial_keys_resolve_to_non_raw_strings() -> void:
	var keys: Array[String] = [
		"TUTORIAL_WELCOME",
		"TUTORIAL_WALK_TO_STORE",
		"TUTORIAL_ENTER_STORE",
		"TUTORIAL_OPEN_INVENTORY",
		"TUTORIAL_PLACE_ITEM",
		"TUTORIAL_OPEN_PRICING",
		"TUTORIAL_SET_PRICE",
		"TUTORIAL_WAIT_CUSTOMER",
		"TUTORIAL_SALE_COMPLETED",
		"TUTORIAL_END_OF_DAY",
	]
	for key: String in keys:
		var translated: String = tr(key)
		assert_ne(
			translated,
			key,
			"tr('%s') must not return the raw key — localization is the SSOT"
			% key
		)
		assert_false(
			translated.is_empty(),
			"tr('%s') must not return an empty string" % key
		)


func test_hud_does_not_ship_walkable_mall_hint() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/hud.tscn"
	)
	assert_false(
		src.contains("WASD Move"),
		"hud.tscn must not show 'WASD Move' — there is no walkable mall"
	)
	assert_false(
		src.contains("ControlHintLabel"),
		"ControlHintLabel node must be removed from hud.tscn"
	)

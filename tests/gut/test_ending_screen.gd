## Tests for EndingScreen UI — signal wiring, stats display, tone, and input blocking.
extends GutTest


var _screen: EndingScreen


func before_each() -> void:
	_screen = preload(
		"res://game/scenes/ui/ending_screen.tscn"
	).instantiate() as EndingScreen
	add_child_autofree(_screen)


func _make_test_stats() -> Dictionary:
	return {
		"days_survived": 30.0,
		"cumulative_revenue": 5000.0,
		"final_cash": 1234.56,
		"owned_store_count_final": 3.0,
		"satisfied_customer_count": 50.0,
		"max_reputation_tier": 2.0,
		"rare_items_sold": 7.0,
		"secret_threads_completed": 1.0,
	}


func _trigger_ending(
	id: StringName, stats: Dictionary
) -> void:
	EventBus.ending_triggered.emit(id, stats)


func _register_test_ending(
	id: String, category: String
) -> void:
	var entry: Dictionary = {
		"id": id,
		"name": "Test Ending",
		"title": "Test Title",
		"ending_category": category,
		"body": "Test body text.",
		"flavor_text": "Test flavor text.",
		"background_color": "#1a3a5c",
		"accent_color": "#f5c842",
	}
	ContentRegistry.register_entry(entry, "ending")


func test_screen_starts_hidden() -> void:
	assert_false(
		_screen.visible,
		"EndingScreen should be hidden on ready"
	)


func test_screen_connects_to_ending_triggered() -> void:
	assert_true(
		EventBus.ending_triggered.is_connected(
			_screen._on_ending_triggered
		),
		"EndingScreen should connect to ending_triggered"
	)


func test_initialize_makes_visible() -> void:
	_register_test_ending("test_ending_visible", "success")
	_trigger_ending(
		&"test_ending_visible", _make_test_stats()
	)
	assert_true(
		_screen.visible,
		"EndingScreen should be visible after initialize"
	)


func test_title_from_content_registry() -> void:
	_register_test_ending("test_ending_title", "success")
	_trigger_ending(
		&"test_ending_title", _make_test_stats()
	)
	assert_eq(
		_screen._title_label.text, "Test Title",
		"Title should match ContentRegistry entry"
	)


func test_category_label_maps_correctly() -> void:
	_register_test_ending("test_ending_cat", "bankruptcy")
	_trigger_ending(
		&"test_ending_cat", _make_test_stats()
	)
	assert_eq(
		_screen._category_label.text, "Bankruptcy",
		"Category label should show mapped category name"
	)


func test_body_text_from_content_registry() -> void:
	_register_test_ending("test_ending_body", "survival")
	_trigger_ending(
		&"test_ending_body", _make_test_stats()
	)
	assert_eq(
		_screen._body_label.text, "Test body text.",
		"Body should match ContentRegistry entry"
	)


func test_flavor_text_from_content_registry() -> void:
	_register_test_ending("test_ending_flavor", "success")
	_trigger_ending(
		&"test_ending_flavor", _make_test_stats()
	)
	assert_eq(
		_screen._flavor_label.text, "Test flavor text.",
		"Flavor label should match ContentRegistry entry"
	)
	assert_true(
		_screen._flavor_label.visible,
		"Flavor label should be visible when text exists"
	)


func test_flavor_text_hidden_when_empty() -> void:
	var entry: Dictionary = {
		"id": "test_no_flavor",
		"name": "No Flavor",
		"title": "No Flavor Title",
		"ending_category": "survival",
		"body": "Body only.",
		"flavor_text": "",
		"background_color": "#1a1a1a",
		"accent_color": "#888888",
	}
	ContentRegistry.register_entry(entry, "ending")
	_trigger_ending(
		&"test_no_flavor", _make_test_stats()
	)
	assert_false(
		_screen._flavor_label.visible,
		"Flavor label should be hidden when text is empty"
	)


func test_fallback_on_missing_ending_id() -> void:
	_trigger_ending(
		&"nonexistent_ending_xyz", _make_test_stats()
	)
	assert_eq(
		_screen._title_label.text, "Unknown Ending",
		"Missing ending should show fallback title"
	)
	assert_true(
		_screen.visible,
		"Screen should still display on fallback"
	)


func test_stats_display_days() -> void:
	_register_test_ending("test_stats_days", "success")
	_trigger_ending(
		&"test_stats_days", _make_test_stats()
	)
	assert_eq(
		_screen._days_label.text, "Days Survived: 30",
		"Days label should show days_survived"
	)


func test_stats_display_revenue() -> void:
	_register_test_ending("test_stats_rev", "success")
	_trigger_ending(
		&"test_stats_rev", _make_test_stats()
	)
	assert_eq(
		_screen._revenue_label.text,
		"Total Revenue: $5000.00",
		"Revenue label should show formatted revenue"
	)


func test_stats_display_final_cash() -> void:
	_register_test_ending("test_stats_cash", "success")
	_trigger_ending(
		&"test_stats_cash", _make_test_stats()
	)
	assert_eq(
		_screen._cash_label.text,
		"Final Cash: $1234.56",
		"Cash label should show final_cash"
	)


func test_stats_display_stores() -> void:
	_register_test_ending("test_stats_stores", "success")
	_trigger_ending(
		&"test_stats_stores", _make_test_stats()
	)
	assert_eq(
		_screen._stores_label.text, "Stores Owned: 3",
		"Stores label should show owned_store_count_final"
	)


func test_stats_display_customers() -> void:
	_register_test_ending("test_stats_cust", "success")
	_trigger_ending(
		&"test_stats_cust", _make_test_stats()
	)
	assert_eq(
		_screen._customers_label.text,
		"Satisfied Customers: 50",
		"Customers label should show satisfied count"
	)


func test_stats_display_reputation() -> void:
	_register_test_ending("test_stats_rep", "success")
	_trigger_ending(
		&"test_stats_rep", _make_test_stats()
	)
	assert_eq(
		_screen._reputation_label.text,
		"Peak Reputation: Reputable",
		"Reputation label should show tier name"
	)


func test_stats_display_rare_items() -> void:
	_register_test_ending("test_stats_rare", "success")
	_trigger_ending(
		&"test_stats_rare", _make_test_stats()
	)
	assert_eq(
		_screen._rare_items_label.text,
		"Rare Items Sold: 7",
		"Rare items label should show count"
	)


func test_stats_display_threads() -> void:
	_register_test_ending("test_stats_threads", "success")
	_trigger_ending(
		&"test_stats_threads", _make_test_stats()
	)
	assert_eq(
		_screen._threads_label.text,
		"Secret Threads Completed: 1",
		"Threads label should show completed count"
	)


func test_assisted_label_hidden_by_default() -> void:
	_register_test_ending("test_no_assist", "success")
	_trigger_ending(
		&"test_no_assist", _make_test_stats()
	)
	assert_false(
		_screen._assisted_label.visible,
		"Assisted label should be hidden when not assisted"
	)


func test_assisted_label_shown_when_flagged() -> void:
	_register_test_ending("test_assist", "success")
	var stats: Dictionary = _make_test_stats()
	stats["used_difficulty_downgrade"] = true
	_trigger_ending(&"test_assist", stats)
	assert_true(
		_screen._assisted_label.visible,
		"Assisted label should be visible when flagged"
	)


func test_trophy_hidden_when_no_path() -> void:
	_register_test_ending("test_no_trophy", "success")
	_trigger_ending(
		&"test_no_trophy", _make_test_stats()
	)
	assert_false(
		_screen._trophy_texture.visible,
		"Trophy should be hidden when no trophy_path in entry"
	)


func test_all_13_ending_ids_render() -> void:
	var ending_ids: Array[String] = [
		"the_ghost_between_the_walls",
		"the_mall_legend_redux",
		"lights_out",
		"foreclosure",
		"going_going_gone",
		"the_local_legend",
		"the_mini_empire",
		"the_mall_tycoon",
		"the_fair_dealer",
		"the_collector",
		"broke_even",
		"the_comfortable_middle",
		"crisis_operator",
	]
	for eid: String in ending_ids:
		_register_test_ending(eid, "success")
	for eid: String in ending_ids:
		_trigger_ending(
			StringName(eid), _make_test_stats()
		)
		assert_true(
			_screen.visible,
			"EndingScreen should render '%s'" % eid
		)
		_screen.visible = false


func test_positive_tone_warm_palette() -> void:
	_register_test_ending("test_positive", "success")
	_trigger_ending(
		&"test_positive", _make_test_stats()
	)
	var cat_color: Color = _screen._category_label.get_theme_color(
		"font_color"
	)
	assert_gt(
		cat_color.r, 0.8,
		"Positive ending category should have warm red channel"
	)


func test_negative_tone_cool_palette() -> void:
	_register_test_ending("test_negative", "bankruptcy")
	_trigger_ending(
		&"test_negative", _make_test_stats()
	)
	var cat_color: Color = _screen._category_label.get_theme_color(
		"font_color"
	)
	assert_lt(
		cat_color.r, 0.7,
		"Negative ending category should have cool/muted tones"
	)


func test_initialize_direct_call() -> void:
	_register_test_ending("test_direct_init", "success")
	_screen._cached_stats = _make_test_stats()
	_screen.initialize(&"test_direct_init")
	assert_true(
		_screen.visible,
		"initialize() should work when called directly"
	)
	assert_eq(
		_screen._title_label.text, "Test Title",
		"Direct initialize should populate title"
	)

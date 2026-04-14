## Integration test: MilestoneSystem revenue chain — cumulative revenue
## crosses threshold → milestone_unlocked → reward applied.
extends GutTest

var _milestone: MilestoneSystem
var _economy: EconomySystem
var _data_loader: DataLoader

var _first_sale_def: MilestoneDefinition
var _mall_mogul_def: MilestoneDefinition


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_build_milestone_defs()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = &"test_store"

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0.0)

	_milestone = MilestoneSystem.new()
	add_child_autofree(_milestone)
	_milestone.initialize()


func after_each() -> void:
	GameManager.current_store_id = &""


func test_first_sale_emits_milestone_unlocked() -> void:
	watch_signals(EventBus)

	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 25.0, &"cust_001"
	)

	assert_signal_emitted(
		EventBus, "milestone_unlocked",
		"milestone_unlocked should fire after first customer purchase"
	)
	var params: Array = get_signal_parameters(
		EventBus, "milestone_unlocked"
	)
	assert_eq(
		params[0] as StringName, &"first_sale",
		"milestone_id should be first_sale"
	)


func test_first_sale_reward_payload_matches_json() -> void:
	watch_signals(EventBus)

	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 25.0, &"cust_001"
	)

	var params: Array = get_signal_parameters(
		EventBus, "milestone_unlocked"
	)
	var reward: Dictionary = params[1] as Dictionary
	assert_eq(
		reward["reward_type"], _first_sale_def.reward_type,
		"reward_type should match milestone definition"
	)
	assert_almost_eq(
		reward["reward_value"] as float,
		_first_sale_def.reward_value,
		0.01,
		"reward_value should match milestone definition"
	)


func test_first_sale_reward_increases_cumulative_revenue() -> void:
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 25.0, &"cust_001"
	)

	var sale_amount: float = 25.0
	var reward_amount: float = _first_sale_def.reward_value
	assert_almost_eq(
		_economy.get_cash(), sale_amount + reward_amount, 0.01,
		"Economy cash should reflect the sale amount plus the milestone cash reward"
	)
	assert_true(
		_milestone.is_complete(&"first_sale"),
		"first_sale milestone should be marked complete"
	)
	assert_almost_eq(
		_milestone._counters["cumulative_revenue"] as float,
		sale_amount + reward_amount,
		0.01,
		"Cumulative revenue should include sale plus milestone cash reward"
	)


func test_revenue_milestone_fires_once_at_threshold() -> void:
	var threshold: float = _mall_mogul_def.trigger_threshold
	var step: float = 500.0
	var emitted_count: Array = [0]
	var _on_unlock := func(
		mid: StringName, _reward: Dictionary
	) -> void:
		if mid == &"mall_mogul":
			emitted_count[0] += 1
	EventBus.milestone_unlocked.connect(_on_unlock)

	var total: Array = [0.0]
	while total[0] < threshold + step:
		EventBus.transaction_completed.emit(step, true, "sale")
		total[0] += step

	assert_eq(
		emitted_count[0], 1,
		"mall_mogul should fire exactly once when crossing threshold"
	)
	EventBus.milestone_unlocked.disconnect(_on_unlock)


func test_no_duplicate_milestone_after_crossing_threshold() -> void:
	var threshold: float = _mall_mogul_def.trigger_threshold

	EventBus.transaction_completed.emit(
		threshold + 100.0, true, "bulk_sale"
	)

	assert_true(
		_milestone.is_complete(&"mall_mogul"),
		"mall_mogul should be complete after crossing threshold"
	)

	var duplicate_count: Array = [0]
	var _on_unlock := func(
		mid: StringName, _reward: Dictionary
	) -> void:
		if mid == &"mall_mogul":
			duplicate_count[0] += 1
	EventBus.milestone_unlocked.connect(_on_unlock)

	EventBus.transaction_completed.emit(1000.0, true, "extra_sale")

	assert_eq(
		duplicate_count[0], 0,
		"mall_mogul should not emit a second time after already completed"
	)
	EventBus.milestone_unlocked.disconnect(_on_unlock)


func _build_milestone_defs() -> void:
	var json_path := "res://game/content/milestones/milestone_definitions.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	assert_not_null(file, "milestone_definitions.json must be readable")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary, "JSON root must be a Dictionary")

	var entries: Array = (parsed as Dictionary).get("milestones", [])
	for entry: Variant in entries:
		var d: Dictionary = entry as Dictionary
		var def := MilestoneDefinition.new()
		def.id = d.get("id", "")
		def.display_name = d.get("display_name", "")
		def.description = d.get("description", "")
		def.trigger_stat_key = d.get("trigger_stat_key", "")
		def.trigger_threshold = float(d.get("trigger_threshold", 0.0))
		def.reward_type = d.get("reward_type", "")
		def.reward_value = float(d.get("reward_value", 0.0))
		def.unlock_id = d.get("unlock_id", "")
		def.is_visible = d.get("is_visible", true)
		def.tier = d.get("tier", "")
		def.trigger_type = d.get("trigger_type", "")
		_data_loader._milestones[def.id] = def

		if def.id == "first_sale":
			_first_sale_def = def
		elif def.id == "mall_mogul":
			_mall_mogul_def = def

	assert_not_null(
		_first_sale_def,
		"first_sale milestone must exist in JSON"
	)
	assert_not_null(
		_mall_mogul_def,
		"mall_mogul milestone must exist in JSON"
	)

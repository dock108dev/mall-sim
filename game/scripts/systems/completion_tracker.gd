## Tracks completion criteria for 100% game completion.
class_name CompletionTracker
extends Node


const TOTAL_CRITERIA: int = 10
const TOTAL_STORES: int = 5
const REP_DESTINATION: float = 50.0
const REP_LEGENDARY: float = 80.0
const UNIVERSAL_UPGRADE_COUNT: int = 6
const STORE_SPECIFIC_UPGRADE_COUNT: int = 2
const REVENUE_MILESTONE_COUNT: int = 5
const STORE_MILESTONE_COUNT: int = 5
const COLLECTION_MILESTONE_REQUIRED: int = 3
const COLLECTION_MILESTONE_TOTAL: int = 5
const TOTAL_CASH_REQUIRED: float = 100000.0
const REFURBISHMENTS_REQUIRED: int = 5

const REVENUE_MILESTONE_IDS: Array[String] = [
	"first_hundred", "hundred_club", "big_earner",
	"five_grand", "mall_mogul",
]

const STORE_MILESTONE_PREFIX: String = "store_"
const COLLECTION_MILESTONE_PREFIX: String = "collection_"

var _opened_stores: Dictionary = {}
var _store_reputations: Dictionary = {}
var _universal_upgrades_per_store: Dictionary = {}
var _store_specific_upgrades_per_store: Dictionary = {}
var _completed_revenue_milestones: Dictionary = {}
var _completed_store_milestones: int = 0
var _completed_collection_milestones: int = 0
var _total_cash_earned: float = 0.0
var _refurbishments_completed: int = 0
var _completion_emitted: bool = false

var _data_loader: DataLoader


func initialize(data_loader: DataLoader) -> void:
	_data_loader = data_loader
	_connect_signals()


func get_completion_percentage() -> float:
	var completed: int = _count_completed()
	return float(completed) / float(TOTAL_CRITERIA) * 100.0


func get_completion_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	data.append(_make_criterion(
		&"all_5_stores_opened", "All 5 Stores Opened",
		float(_opened_stores.size()), float(TOTAL_STORES)
	))
	data.append(_make_criterion(
		&"all_stores_rep_50", "All Stores at 50+ Reputation",
		float(_count_stores_at_rep(REP_DESTINATION)),
		float(TOTAL_STORES)
	))
	data.append(_make_criterion(
		&"legendary_store", "Legendary Store (80+ Rep)",
		float(_count_stores_at_rep(REP_LEGENDARY)), 1.0
	))
	data.append(_make_criterion(
		&"all_universal_upgrades",
		"All Universal Upgrades (1 Store)",
		float(_best_universal_upgrade_count()),
		float(UNIVERSAL_UPGRADE_COUNT)
	))
	data.append(_make_criterion(
		&"all_store_upgrades",
		"All Store-Specific Upgrades (1 Store)",
		float(_best_store_specific_upgrade_count()),
		float(STORE_SPECIFIC_UPGRADE_COUNT)
	))
	data.append(_make_criterion(
		&"all_revenue_milestones", "All Revenue Milestones",
		float(_completed_revenue_milestones.size()),
		float(REVENUE_MILESTONE_COUNT)
	))
	data.append(_make_criterion(
		&"all_store_milestones", "All Store Milestones",
		float(_completed_store_milestones),
		float(STORE_MILESTONE_COUNT)
	))
	data.append(_make_criterion(
		&"collection_milestones",
		"Collection Milestones (3 of 5)",
		float(_completed_collection_milestones),
		float(COLLECTION_MILESTONE_REQUIRED)
	))
	data.append(_make_criterion(
		&"total_cash_earned", "Earn $100,000 Total",
		_total_cash_earned, TOTAL_CASH_REQUIRED
	))
	data.append(_make_criterion(
		&"refurbishments_completed", "Refurbish 5 Items",
		float(_refurbishments_completed),
		float(REFURBISHMENTS_REQUIRED)
	))
	return data


func get_save_data() -> Dictionary:
	var opened_list: Array[String] = []
	for key: String in _opened_stores:
		opened_list.append(key)

	var rep_dict: Dictionary = {}
	for key: String in _store_reputations:
		rep_dict[key] = _store_reputations[key]

	var universal_dict: Dictionary = {}
	for key: String in _universal_upgrades_per_store:
		var ids: Array = _universal_upgrades_per_store[key]
		var serialized: Array[String] = []
		for uid: Variant in ids:
			serialized.append(str(uid))
		universal_dict[key] = serialized

	var specific_dict: Dictionary = {}
	for key: String in _store_specific_upgrades_per_store:
		var ids: Array = _store_specific_upgrades_per_store[key]
		var serialized: Array[String] = []
		for uid: Variant in ids:
			serialized.append(str(uid))
		specific_dict[key] = serialized

	var rev_list: Array[String] = []
	for key: String in _completed_revenue_milestones:
		rev_list.append(key)

	return {
		"opened_stores": opened_list,
		"store_reputations": rep_dict,
		"universal_upgrades": universal_dict,
		"store_specific_upgrades": specific_dict,
		"completed_revenue_milestones": rev_list,
		"completed_store_milestones": _completed_store_milestones,
		"completed_collection_milestones": _completed_collection_milestones,
		"total_cash_earned": _total_cash_earned,
		"refurbishments_completed": _refurbishments_completed,
		"completion_emitted": _completion_emitted,
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_opened_stores = {}
	var saved_opened: Variant = data.get("opened_stores", [])
	if saved_opened is Array:
		for entry: Variant in saved_opened:
			_opened_stores[str(entry)] = true

	_store_reputations = {}
	var saved_reps: Variant = data.get("store_reputations", {})
	if saved_reps is Dictionary:
		for key: String in saved_reps:
			_store_reputations[key] = float(saved_reps[key])

	_universal_upgrades_per_store = {}
	var saved_universal: Variant = data.get("universal_upgrades", {})
	if saved_universal is Dictionary:
		for key: String in saved_universal:
			var ids: Variant = saved_universal[key]
			if ids is Array:
				var restored: Array = []
				for uid: Variant in ids:
					restored.append(str(uid))
				_universal_upgrades_per_store[key] = restored

	_store_specific_upgrades_per_store = {}
	var saved_specific: Variant = data.get(
		"store_specific_upgrades", {}
	)
	if saved_specific is Dictionary:
		for key: String in saved_specific:
			var ids: Variant = saved_specific[key]
			if ids is Array:
				var restored: Array = []
				for uid: Variant in ids:
					restored.append(str(uid))
				_store_specific_upgrades_per_store[key] = restored

	_completed_revenue_milestones = {}
	var saved_rev: Variant = data.get(
		"completed_revenue_milestones", []
	)
	if saved_rev is Array:
		for entry: Variant in saved_rev:
			_completed_revenue_milestones[str(entry)] = true

	_completed_store_milestones = int(
		data.get("completed_store_milestones", 0)
	)
	_completed_collection_milestones = int(
		data.get("completed_collection_milestones", 0)
	)
	_total_cash_earned = float(data.get("total_cash_earned", 0.0))
	_refurbishments_completed = int(
		data.get("refurbishments_completed", 0)
	)
	_completion_emitted = bool(
		data.get("completion_emitted", false)
	)


func _connect_signals() -> void:
	EventBus.store_leased.connect(_on_store_leased)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.active_store_changed.connect(
		_on_active_store_changed
	)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.milestone_completed.connect(_on_milestone_completed)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.refurbishment_completed.connect(
		_on_refurbishment_completed
	)


func _on_store_leased(
	_slot_index: int, store_type: String
) -> void:
	_opened_stores[store_type] = true
	_check_completion()


func _on_reputation_changed(
	store_id: String, _old_score: float, new_value: float
) -> void:
	if store_id.is_empty():
		return
	_store_reputations[store_id] = new_value
	_check_completion()


func _on_active_store_changed(store_id: StringName) -> void:
	var sid: String = String(store_id)
	if sid.is_empty():
		return
	if not _store_reputations.has(sid):
		_store_reputations[sid] = 0.0


func _on_upgrade_purchased(
	store_id: StringName, upgrade_id: String
) -> void:
	var sid: String = String(store_id)
	if not _data_loader:
		return
	var upgrade: UpgradeDefinition = _data_loader.get_upgrade(
		upgrade_id
	)
	if not upgrade:
		return

	if upgrade.is_universal():
		if not _universal_upgrades_per_store.has(sid):
			_universal_upgrades_per_store[sid] = []
		var list: Array = _universal_upgrades_per_store[sid]
		if upgrade_id not in list:
			list.append(upgrade_id)
	else:
		if not _store_specific_upgrades_per_store.has(sid):
			_store_specific_upgrades_per_store[sid] = []
		var list: Array = _store_specific_upgrades_per_store[sid]
		if upgrade_id not in list:
			list.append(upgrade_id)
	_check_completion()


func _on_milestone_completed(
	milestone_id: String,
	_milestone_name: String,
	_reward_description: String
) -> void:
	if milestone_id in REVENUE_MILESTONE_IDS:
		_completed_revenue_milestones[milestone_id] = true
	if milestone_id.begins_with(STORE_MILESTONE_PREFIX):
		_completed_store_milestones = mini(
			_completed_store_milestones + 1,
			STORE_MILESTONE_COUNT
		)
	if milestone_id.begins_with(COLLECTION_MILESTONE_PREFIX):
		_completed_collection_milestones = mini(
			_completed_collection_milestones + 1,
			COLLECTION_MILESTONE_TOTAL
		)
	_check_completion()


func _on_item_sold(
	_item_id: String, price: float, _category: String
) -> void:
	_total_cash_earned += price
	_check_completion()


func _on_refurbishment_completed(
	_item_id: String, success: bool, _new_condition: String
) -> void:
	if success:
		_refurbishments_completed += 1
		_check_completion()


func _make_criterion(
	id: StringName, label: String,
	current: float, required: float
) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"current": current,
		"required": required,
		"complete": current >= required,
	}


func _count_completed() -> int:
	var count: int = 0
	for criterion: Dictionary in get_completion_data():
		if criterion.get("complete", false):
			count += 1
	return count


func _count_stores_at_rep(threshold: float) -> int:
	var count: int = 0
	for store_id: String in _store_reputations:
		if float(_store_reputations[store_id]) >= threshold:
			count += 1
	return count


func _best_universal_upgrade_count() -> int:
	var best: int = 0
	for store_id: String in _universal_upgrades_per_store:
		var list: Array = _universal_upgrades_per_store[store_id]
		best = maxi(best, list.size())
	return best


func _best_store_specific_upgrade_count() -> int:
	var best: int = 0
	for store_id: String in _store_specific_upgrades_per_store:
		var list: Array = (
			_store_specific_upgrades_per_store[store_id]
		)
		best = maxi(best, list.size())
	return best


func _check_completion() -> void:
	if _completion_emitted:
		return
	if _count_completed() >= TOTAL_CRITERIA:
		_completion_emitted = true
		EventBus.completion_reached.emit("all_criteria")

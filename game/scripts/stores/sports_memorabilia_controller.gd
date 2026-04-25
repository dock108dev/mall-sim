# gdlint:disable=max-file-lines
## Controller for the sports memorabilia store. Manages season cycle,
## card condition grading, and ACC numeric grading via PriceResolver.
class_name SportsMemorabiliaController
extends StoreController

## Grade states for the CARB (Certified Artifact Rating Bureau) authentication flow.
## Grade 6 is intentionally absent — parodies the gap-skipping quirks of real-world
## third-party grading scales.
enum AuthGrade {
	COUNTERFEIT = 0,
	AUTHENTIC_RAW = 1,
	POOR = 2,
	GOOD = 3,
	VERY_GOOD = 4,
	EXCELLENT = 5,
	NEAR_MINT = 7,
	MINT = 8,
	GEM_MINT = 9,
	PRISTINE = 10,
}

## Service tier chosen at CARB submission time.
enum AuthTier { ECONOMY = 0, EXPRESS = 1, PREMIUM = 2 }

const STORE_ID: StringName = &"sports"
const STORE_TYPE: StringName = &"sports_memorabilia"
const BOOSTED_CATEGORIES: PackedStringArray = ["memorabilia", "autograph"]
const DEFAULT_SEASON_BOOST: float = 1.5
## Minimum provenance_score for a card to pass the authentication check.
const AUTH_THRESHOLD: float = 0.5
## Flat cost of a single probabilistic grading hint (ISSUE-018).
const GRADING_HINT_FEE: float = 10.0
## Probability that a grading hint reports the true authenticity. The remaining
## probability is split between the two adjacent states, giving the player
## partial but not certain information.
const GRADING_HINT_ACCURACY: float = 0.7
## Reputation magnitude deducted when a fake is sold as authentic.
const FAKE_SALE_REPUTATION_PENALTY: float = -5.0

## Value multiplier applied to base_price after CARB authentication resolves.
const CARB_GRADE_MULTIPLIERS: Dictionary = {
	0: 0.0,    # COUNTERFEIT
	1: 0.6,    # AUTHENTIC_RAW
	2: 0.8,    # POOR
	3: 1.0,    # GOOD
	4: 1.35,   # VERY_GOOD
	5: 1.75,   # EXCELLENT
	7: 2.8,    # NEAR_MINT
	8: 4.5,    # MINT
	9: 9.0,    # GEM_MINT
	10: 22.0,  # PRISTINE
}

## Authentication fee rate as fraction of base_value per AuthTier int key.
const AUTH_TIER_RATES: Dictionary = {0: 0.08, 1: 0.18, 2: 0.35}
const AUTH_MIN_FEE: float = 50.0
const AUTH_MAX_FEE: float = 2000.0

## Maps item.condition to CARB condition_tier for grade probability lookup.
const _CONDITION_TO_CARB_TIER: Dictionary = {
	"mint": "mint_plus", "near_mint": "near_mint",
	"good": "lightly_played", "fair": "played", "poor": "damaged",
}

## Grade probability tables by condition_tier; each entry is [grade_value, weight].
## Weights sum to 100. Provenance halves the COUNTERFEIT (grade 0) weight at roll time.
const _CARB_GRADE_TABLES: Dictionary = {
	"damaged":       [[0,20],[1,15],[2,20],[3,20],[4,10],[5,10],[7,5],[8,0],[9,0],[10,0]],
	"played":        [[0,8],[1,10],[2,15],[3,15],[4,18],[5,17],[7,15],[8,2],[9,0],[10,0]],
	"lightly_played":[[0,3],[1,5],[2,5],[3,5],[4,15],[5,15],[7,35],[8,15],[9,2],[10,0]],
	"near_mint":     [[0,1],[1,3],[2,2],[3,3],[4,5],[5,5],[7,25],[8,35],[9,18],[10,3]],
	"mint_plus":     [[0,0],[1,1],[2,1],[3,1],[4,2],[5,3],[7,10],[8,20],[9,45],[10,17]],
}

## Grade ranges per condition for the ACC numeric grading RNG.
## Format: [min_grade, max_grade] (inclusive, 1–10 scale).
const _CONDITION_GRADE_RANGES: Dictionary = {
	"mint":      [7, 10],
	"near_mint": [6,  9],
	"good":      [4,  7],
	"fair":      [2,  5],
	"poor":      [1,  3],
}

var _season_cycle: SeasonCycleSystem = SeasonCycleSystem.new()
var _season_boost_active: bool = false
var _season_boost_value: float = DEFAULT_SEASON_BOOST
var _market_event_connected: bool = false
var _economy_system: EconomySystem = null

## Maps instance_id → day_submitted for cards pending ACC grading.
var _pending_grades: Dictionary = {}
## Accumulates grades returned on the current day for the grading_day_summary emit.
var _today_returned: Array = []
## Tracks in-progress CARB authentication submissions. Key: item_id String.
var _pending_carb_auths: Dictionary = {}
## Local cache of ItemInstance references for items in the sports store.
## Kept alive so _check_fake_sold_as_authentic can resolve an item even after
## InventorySystem.remove_item has erased it from _items on the same signal.
var _item_state_cache: Dictionary = {}


## Injects the EconomySystem reference so grading-hint fees can be deducted.
func set_economy_system(economy: EconomySystem) -> void:
	_economy_system = economy


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	_load_season_boost()
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.market_event_triggered.connect(_on_market_event)
	EventBus.provenance_accepted.connect(_on_provenance_accepted)
	EventBus.provenance_rejected.connect(_on_provenance_rejected)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.card_condition_selected.connect(_on_card_condition_selected)


## Initializes the season cycle system.
func initialize(starting_day: int) -> void:
	_season_cycle.initialize(starting_day)


## Returns the SeasonCycleSystem for external wiring (EconomySystem, etc.).
func get_season_cycle() -> SeasonCycleSystem:
	return _season_cycle


## Returns the demand multiplier for the given category.
func get_demand_multiplier(category: StringName) -> float:
	if not _season_boost_active:
		return 1.0
	if String(category) in BOOSTED_CATEGORIES:
		return _season_boost_value
	return 1.0


## Returns the current sale price for an inventory item, resolved via
## PriceResolver with condition and season-demand multipliers in the audit chain.
func get_item_price(item_id: StringName) -> float:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem is required for pricing"
		)
		return 0.0
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for pricing"
			% item_id
		)
		return 0.0
	var multipliers: Array = []
	if item.authentication_status == "carb_graded":
		var grade_factor: float = float(CARB_GRADE_MULTIPLIERS.get(item.numeric_grade, 0.0))
		var grade_label: String = _carb_grade_label(item.numeric_grade)
		multipliers.append({
			"slot": "carb_grade",
			"label": "CARB Grade",
			"factor": grade_factor,
			"detail": "CARB %s" % grade_label,
		})
	elif item.numeric_grade >= 1:
		# ACC numeric grade supersedes all other condition/grade multipliers.
		var grade_factor: float = PriceResolver.NUMERIC_GRADE_MULTIPLIERS.get(
			item.numeric_grade, 1.0
		)
		var grade_label: String = PriceResolver.NUMERIC_GRADE_LABELS.get(
			item.numeric_grade, "Grade %d" % item.numeric_grade
		)
		multipliers.append({
			"slot": "numeric_grade",
			"label": "ACC Grade",
			"factor": grade_factor,
			"detail": "ACC %d — %s" % [item.numeric_grade, grade_label],
		})
	elif item.is_graded and not item.card_grade.is_empty():
		# Letter grade (authentication mechanic) supersedes condition.
		var grade_factor: float = PriceResolver.GRADE_MULTIPLIERS.get(
			item.card_grade, 1.0
		)
		multipliers.append({
			"slot": "grade",
			"label": "Grade",
			"factor": grade_factor,
			"detail": "Certified Grade: %s" % item.card_grade,
		})
	else:
		var condition_factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(
			item.condition, 1.0
		)
		multipliers.append({
			"label": "Condition",
			"factor": condition_factor,
			"detail": item.condition.capitalize().replace("_", " "),
		})
	var demand_factor: float = get_demand_multiplier(item.definition.category)
	if demand_factor != 1.0:
		multipliers.append({
			"slot": "seasonal",
			"label": "Season Demand",
			"factor": demand_factor,
			"detail": "Active season boost",
		})
	var vintage_trend: float = MarketTrendSystemSingleton.get_trend_modifier(&"vintage")
	if vintage_trend != 1.0:
		multipliers.append({
			"slot": "trend",
			"label": "Vintage Trend",
			"factor": vintage_trend,
			"detail": "Vintage shelf trend: %.2f" % vintage_trend,
		})
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item_id), item.definition.base_price, multipliers
	)
	return result.final_price


## Serializes sports-memorabilia-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"season_cycle": _season_cycle.get_save_data(),
		"season_boost_active": _season_boost_active,
		"pending_grades": _pending_grades.duplicate(),
		"pending_carb_auths": _pending_carb_auths.duplicate(true),
	}


## Restores sports-memorabilia-specific state from saved data.
## The legacy "authentication" key is silently ignored for forward compatibility.
func load_save_data(data: Dictionary) -> void:
	var cycle_data: Variant = data.get("season_cycle", {})
	if cycle_data is Dictionary:
		_season_cycle.load_save_data(cycle_data as Dictionary)
	_season_boost_active = bool(data.get("season_boost_active", false))
	var saved_pending: Variant = data.get("pending_grades", {})
	if saved_pending is Dictionary:
		_pending_grades = (saved_pending as Dictionary).duplicate()
		_restore_pending_grade_locks()
	var saved_carb: Variant = data.get("pending_carb_auths", {})
	if saved_carb is Dictionary:
		_pending_carb_auths = (saved_carb as Dictionary).duplicate(true)


func _defer_store_entered(store_id: StringName) -> void:
	_on_store_entered(store_id)
	if StringName(store_type) == store_id:
		emit_actions_registered()


func get_store_actions() -> Array:
	var actions: Array = super()
	actions.append({"id": &"authenticate", "label": "Authenticate", "icon": ""})
	actions.append({"id": &"grade", "label": "Grade", "icon": ""})
	actions.append({
		"id": &"send_for_grading",
		"label": "Send for Grading (ACC)",
		"icon": "",
	})
	actions.append({
		"id": &"grading_hint",
		"label": "Buy Grading Hint ($%d)" % int(GRADING_HINT_FEE),
		"icon": "",
	})
	return actions


## Returns the flat cost of a probabilistic grading hint.
func get_grading_hint_fee() -> float:
	return GRADING_HINT_FEE


## Pays GRADING_HINT_FEE and stamps item.revealed_authenticity with a
## probabilistic hint that matches true_authenticity GRADING_HINT_ACCURACY of
## the time and otherwise reports an adjacent state. Emits
## grading_hint_revealed on success.
func request_grading_hint(item_id: StringName) -> bool:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem required for hint"
		)
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for hint" % item_id
		)
		return false
	if item.true_authenticity.is_empty():
		item.true_authenticity = ItemInstance.derive_true_authenticity(item.definition)
	if item.true_authenticity.is_empty():
		push_warning(
			"SportsMemorabiliaController: item '%s' has no provenance to grade"
			% item_id
		)
		return false
	var economy: EconomySystem = _economy_system
	if economy and not economy.deduct_cash(
		GRADING_HINT_FEE, "Grading hint: %s" % item.definition.item_name
	):
		EventBus.notification_requested.emit(
			"Insufficient funds for grading hint ($%.2f)" % GRADING_HINT_FEE
		)
		return false
	var hint: String = _roll_authenticity_hint(item)
	item.revealed_authenticity = hint
	EventBus.grading_hint_revealed.emit(item_id, hint, GRADING_HINT_FEE)
	EventBus.notification_requested.emit(
		"Grading hint: %s looks %s" % [item.definition.item_name, hint]
	)
	return true


## Returns a probabilistic authenticity hint for an item. Uses a per-call RNG
## seeded from instance_id + current day so repeated hints on the same day
## return a stable answer (player can't spam-reroll for certainty).
func _roll_authenticity_hint(item: ItemInstance) -> String:
	var states: PackedStringArray = ["authentic", "questionable", "fake"]
	var truth: String = item.true_authenticity
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		"hint:" + String(item.instance_id) + ":"
		+ str(GameManager.get_current_day())
	)
	if rng.randf() < GRADING_HINT_ACCURACY:
		return truth
	var truth_idx: int = states.find(truth)
	if truth_idx < 0:
		return truth
	if truth_idx == 0:
		return states[1]
	if truth_idx == states.size() - 1:
		return states[states.size() - 2]
	# Middle state ("questionable") has two neighbours — pick one.
	return states[0] if rng.randf() < 0.5 else states[states.size() - 1]


func _on_day_started(day: int) -> void:
	_season_cycle.process_day(day)
	_deliver_pending_grades(day)
	_process_carb_reveals(day)


func _on_day_ended(_day: int) -> void:
	EventBus.grading_day_summary.emit(
		_pending_grades.size(), _today_returned.duplicate()
	)


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_connect_market_event_signals()
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_disconnect_market_event_signals()
	EventBus.store_closed.emit(String(STORE_ID))


func _on_inventory_updated(store_id: StringName) -> void:
	if store_id != STORE_ID or not _inventory_system:
		return
	for item: ItemInstance in _inventory_system.get_items_for_store(String(STORE_ID)):
		_item_state_cache[String(item.instance_id)] = item


## Updates item condition and recalculates price via PriceResolver.
func _on_card_condition_selected(
	item_id: StringName, condition: String
) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return
	if condition not in ItemInstance.CONDITION_MULTIPLIERS:
		push_warning(
			"SportsMemorabiliaController: unknown condition '%s'" % condition
		)
		return
	item.condition = condition
	var price: float = get_item_price(item_id)
	EventBus.price_set.emit(String(item_id), price)


## Returns a season-based demand modifier for the given category.
## Non-boosted categories always return 1.0; boosted categories follow a
## sports-calendar curve derived from the current in-game month (30 days/month).
func _get_season_modifier(category: StringName) -> float:
	if String(category) not in BOOSTED_CATEGORIES:
		return 1.0
	var day: int = GameManager.get_current_day()
	var month: int = ((day - 1) / 30) % 12 + 1
	const MONTH_MODIFIERS: Dictionary = {
		1: 1.40, 2: 1.10, 3: 0.85, 4: 0.80, 5: 0.80, 6: 0.85,
		7: 0.90, 8: 0.95, 9: 1.25, 10: 1.25, 11: 1.35, 12: 1.65,
	}
	return MONTH_MODIFIERS.get(month, 1.0)


func _on_customer_purchased(
	store_id: StringName, item_id: StringName,
	price: float, _customer_id: StringName
) -> void:
	if store_id != STORE_ID:
		return
	_check_fake_sold_as_authentic(item_id, price)


## Triggers a reputation penalty when the sold item's true authenticity is
## "fake" but the player declared it authentic (is_authenticated). Emits
## fake_sold_as_authentic so UI/audit can surface the incident.
func _check_fake_sold_as_authentic(
	item_id: StringName, price: float
) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		item = _item_state_cache.get(String(item_id), null) as ItemInstance
	if not item:
		return
	if item.true_authenticity.is_empty():
		item.true_authenticity = ItemInstance.derive_true_authenticity(item.definition)
	if item.true_authenticity != "fake":
		return
	if not item.is_authenticated:
		return
	ReputationSystemSingleton.add_reputation(
		String(STORE_ID), FAKE_SALE_REPUTATION_PENALTY
	)
	EventBus.fake_sold_as_authentic.emit(
		item_id, STORE_ID, price, FAKE_SALE_REPUTATION_PENALTY
	)
	var item_label: String = (
		item.definition.item_name if item.definition else String(item_id)
	)
	EventBus.notification_requested.emit(
		"Customer exposed fake: %s (-%.1f reputation)"
		% [item_label, absf(FAKE_SALE_REPUTATION_PENALTY)]
	)


func _on_market_event(
	_event_id: StringName,
	store_id: StringName,
	_effect: Dictionary,
) -> void:
	if store_id != STORE_ID:
		return


func _on_market_event_started(event_id: String) -> void:
	if not _is_event_sports_win(event_id):
		return
	_season_boost_active = true


func _on_market_event_ended(event_id: String) -> void:
	if not _is_event_sports_win(event_id):
		return
	_season_boost_active = false


func _is_event_sports_win(event_id: String) -> bool:
	if not GameManager.data_loader:
		return false
	var def: MarketEventDefinition = (
		GameManager.data_loader.get_market_event(event_id)
	)
	if not def:
		return false
	return def.event_type == "sports_win"


func _connect_market_event_signals() -> void:
	if _market_event_connected:
		return
	EventBus.market_event_started.connect(_on_market_event_started)
	EventBus.market_event_ended.connect(_on_market_event_ended)
	_market_event_connected = true


func _disconnect_market_event_signals() -> void:
	if not _market_event_connected:
		return
	EventBus.market_event_started.disconnect(_on_market_event_started)
	EventBus.market_event_ended.disconnect(_on_market_event_ended)
	_market_event_connected = false


func _load_season_boost() -> void:
	if not ContentRegistry.exists(String(STORE_ID)):
		return
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		return
	_season_boost_value = float(
		entry.get("season_boost", DEFAULT_SEASON_BOOST)
	)


## Runs the authentication check for a sports card in inventory.
## Emits card_authenticated or card_rejected, then card_graded on success.
func authenticate_card(item_id: StringName) -> void:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem required for authentication"
		)
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for authentication"
			% item_id
		)
		return
	var score: float = item.definition.provenance_score
	if score < AUTH_THRESHOLD:
		item.authentication_status = "rejected"
		EventBus.card_rejected.emit(item_id)
		return
	item.authentication_status = "authenticated"
	item.is_authenticated = true
	EventBus.card_authenticated.emit(item_id)
	var grade: String = _compute_grade(score)
	item.card_grade = grade
	item.is_graded = true
	item.grade_value = PriceResolver.GRADE_ORDER.find(grade)
	EventBus.card_graded.emit(item_id, grade)


## Maps a provenance_score (must be >= AUTH_THRESHOLD) to a letter grade.
func _compute_grade(provenance_score: float) -> String:
	if provenance_score >= 0.95:
		return "S"
	if provenance_score >= 0.85:
		return "A"
	if provenance_score >= 0.75:
		return "B"
	if provenance_score >= 0.65:
		return "C"
	if provenance_score >= 0.55:
		return "D"
	return "F"


## Triggers the provenance verification flow for a customer offer.
func request_provenance_check(
	item_id: String, customer: Node
) -> void:
	EventBus.provenance_requested.emit(item_id, customer)


func _on_provenance_accepted(item_id: String) -> void:
	if not _inventory_system:
		EventBus.provenance_completed.emit(
			item_id, false, "System not ready"
		)
		return
	var item: ItemInstance = _inventory_system.get_item(item_id)
	if not item:
		item = _resolve_offered_item(item_id)
	if not item:
		EventBus.provenance_completed.emit(
			item_id, false, "Item not found"
		)
		return
	item.authentication_status = "authenticated"
	_inventory_system.add_item(STORE_ID, item)
	EventBus.provenance_completed.emit(item_id, true, "")
	EventBus.notification_requested.emit(
		"Accepted: %s" % item.definition.item_name
	)


func _on_provenance_rejected(item_id: String) -> void:
	EventBus.notification_requested.emit(
		"Rejected item: %s" % item_id
	)


func _on_haggle_completed(
	store_id: StringName,
	item_id: StringName,
	final_price: float,
	_asking_price: float,
	accepted: bool,
	_offer_count: int,
) -> void:
	if store_id != STORE_ID:
		return
	if not accepted or not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return
	var condition_factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		item.condition, 1.0
	)
	if condition_factor <= 1.0:
		return
	var bonus: float = final_price * (condition_factor - 1.0)
	if bonus <= 0.0:
		return
	EventBus.bonus_sale_completed.emit(item_id, bonus)


## Submits card to the Apex Card Certification service for numeric grading.
## Card is locked from sale until grade_returned fires on day_started of day N+1.
func send_for_grading(item_id: StringName) -> void:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem required for grading"
		)
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for grading" % item_id
		)
		return
	if item.is_grading_pending:
		push_warning(
			"SportsMemorabiliaController: item '%s' already pending grading" % item_id
		)
		return
	if item.numeric_grade >= 1:
		push_warning(
			"SportsMemorabiliaController: item '%s' already has ACC grade %d"
			% [item_id, item.numeric_grade]
		)
		return
	var current_day: int = GameManager.get_current_day()
	item.is_grading_pending = true
	_pending_grades[String(item_id)] = current_day
	EventBus.grade_submitted.emit(item_id, current_day)


## Delivers any grades that were submitted on day N when day N+1 starts.
func _deliver_pending_grades(current_day: int) -> void:
	_today_returned.clear()
	var to_deliver: Array[String] = []
	for card_id: String in _pending_grades:
		if _pending_grades[card_id] < current_day:
			to_deliver.append(card_id)
	for card_id: String in to_deliver:
		_deliver_single_grade(card_id, current_day)
		_pending_grades.erase(card_id)


func _deliver_single_grade(card_id: String, current_day: int) -> void:
	var item: ItemInstance = (
		_inventory_system.get_item(card_id) if _inventory_system else null
	)
	if not item:
		push_warning(
			"SportsMemorabiliaController: graded item '%s' not found in inventory"
			% card_id
		)
		return
	var grade: int = _roll_numeric_grade(item, current_day)
	item.numeric_grade = grade
	item.is_graded = true
	item.is_grading_pending = false
	var grade_label: String = PriceResolver.NUMERIC_GRADE_LABELS.get(
		grade, "Grade %d" % grade
	)
	_today_returned.append({
		"card_id": card_id,
		"card_name": item.definition.item_name if item.definition else card_id,
		"grade": grade,
		"grade_label": grade_label,
	})
	EventBus.grade_returned.emit(StringName(card_id), grade)
	EventBus.toast_requested.emit(
		"ACC Grade Returned: %s — %d (%s)" % [
			item.definition.item_name if item.definition else card_id,
			grade, grade_label,
		],
		&"sports",
		4.0,
	)


## Seeded RNG using hash(item_id + day) for deterministic results.
func _roll_numeric_grade(item: ItemInstance, day: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(item.instance_id) + str(day))
	var condition: String = item.condition if not item.condition.is_empty() else "good"
	var range_arr: Variant = _CONDITION_GRADE_RANGES.get(condition, [4, 7])
	var min_g: int = int((range_arr as Array)[0])
	var max_g: int = int((range_arr as Array)[1])
	return rng.randi_range(min_g, max_g)


## Restores is_grading_pending on items after a save/load cycle.
func _restore_pending_grade_locks() -> void:
	if not _inventory_system:
		return
	for card_id: String in _pending_grades:
		var item: ItemInstance = _inventory_system.get_item(card_id)
		if item:
			item.is_grading_pending = true


func _resolve_offered_item(item_id: String) -> ItemInstance:
	var base_id: String = item_id
	var underscore_idx: int = item_id.rfind("_")
	if underscore_idx > 0 and item_id.substr(underscore_idx + 1).is_valid_int():
		base_id = item_id.substr(0, underscore_idx)
	var canonical: StringName = ContentRegistry.resolve(base_id)
	if canonical.is_empty():
		return null
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return null
	var def: ItemDefinition = _build_definition_from_entry(
		canonical, entry
	)
	var inst: ItemInstance = (
		ItemInstance.create_from_definition(def)
	)
	inst.instance_id = item_id
	return inst


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var existing: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(STORE_ID))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		push_error(
			"SportsMemorabilia: no ContentRegistry entry for %s"
			% STORE_ID
		)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if starter_items is Array:
		for item_data: Variant in starter_items:
			if item_data is Dictionary:
				_add_starter_item(item_data as Dictionary)


func _add_starter_item(item_data: Dictionary) -> void:
	var raw_id: Variant = item_data.get("item_id", "")
	if not raw_id is String or (raw_id as String).is_empty():
		return
	var canonical: StringName = ContentRegistry.resolve(
		raw_id as String
	)
	if canonical.is_empty():
		push_error(
			"SportsMemorabilia: unknown item_id '%s'" % raw_id
		)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var def: ItemDefinition = _build_definition_from_entry(
		canonical, entry
	)
	var quantity: int = int(item_data.get("quantity", 1))
	var condition: String = str(item_data.get("condition", ""))
	for i: int in range(quantity):
		var instance: ItemInstance = (
			ItemInstance.create_from_definition(def, condition)
		)
		_inventory_system.add_item(STORE_ID, instance)


## Returns the CARB display label for an AuthGrade int value.
func _carb_grade_label(grade: int) -> String:
	const LABELS: Dictionary = {
		0: "COUNTERFEIT", 1: "Authentic (Ungraded)",
		2: "CARB 2 — Poor", 3: "CARB 3 — Good",
		4: "CARB 4 — Very Good", 5: "CARB 5 — Excellent",
		7: "CARB 7 — Near Mint", 8: "CARB 8 — Mint",
		9: "CARB 9 — Gem Mint", 10: "CARB 10 — Pristine",
	}
	return LABELS.get(grade, "Grade %d" % grade)


## Returns the bracket hint text shown to the player on PREMIUM submissions.
func _bracket_display_text(bracket: String) -> String:
	match bracket:
		"BRACKET_LOW":
			return "Our experts note significant concerns."
		"BRACKET_MID":
			return "Solid specimen. Moderate condition."
		"BRACKET_HIGH":
			return "Strong condition. Collectors will notice."
		"BRACKET_ELITE":
			return "Exceptional. One of the finest examples seen."
	return "Review in progress."


## Computes the CARB authentication fee for an item at the chosen tier.
func _compute_auth_cost(tier: int, base_value: float) -> float:
	var rate: float = float(AUTH_TIER_RATES.get(tier, 0.08))
	return clampf(base_value * rate, AUTH_MIN_FEE, AUTH_MAX_FEE)


## Submits an item to CARB for multi-state authentication grading.
## Deducts the authentication fee via EconomySystem (if set) before accepting.
## Emits EventBus.store_auth_started on success; returns false on any failure.
func submit_for_carb_authentication(item_id: StringName, tier: int) -> bool:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem required for CARB auth"
		)
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for CARB auth" % item_id
		)
		return false
	if item.authentication_status == "carb_graded":
		push_warning(
			"SportsMemorabiliaController: item '%s' already CARB-graded" % item_id
		)
		return false
	if _pending_carb_auths.has(String(item_id)):
		push_warning(
			"SportsMemorabiliaController: item '%s' already pending CARB auth" % item_id
		)
		return false
	var cost: float = _compute_auth_cost(tier, item.definition.base_price)
	if _economy_system and not _economy_system.deduct_cash(
		cost, "CARB auth: %s" % item.definition.item_name
	):
		EventBus.notification_requested.emit(
			"Insufficient funds for CARB authentication ($%.2f)" % cost
		)
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		"carb_roll:" + String(item_id) + ":" + str(GameManager.get_current_day())
	)
	var final_grade: int = _roll_carb_grade(item, rng)
	var bracket: String = _classify_carb_bracket(final_grade)
	var reveal_schedule: Array = _build_carb_reveal_schedule(tier, bracket)
	_pending_carb_auths[String(item_id)] = {
		"item_id": String(item_id),
		"tier": tier,
		"cost_paid": cost,
		"submission_day": GameManager.get_current_day(),
		"final_grade": final_grade,
		"bracket": bracket,
		"reveal_schedule": reveal_schedule,
		"revealed_indices": [],
	}
	EventBus.store_auth_started.emit(item_id, tier, cost)
	EventBus.notification_requested.emit(
		"CARB submission accepted: %s ($%.2f)" % [item.definition.item_name, cost]
	)
	return true


## Rolls the final CARB grade from the condition-tier probability table.
## Uses a seeded RNG so the result is deterministic per item+day; rolled at
## submission time and hidden until reveals fire.
func _roll_carb_grade(item: ItemInstance, rng: RandomNumberGenerator) -> int:
	var tier: String = _CONDITION_TO_CARB_TIER.get(item.condition, "lightly_played")
	var base_table: Variant = (
		_CARB_GRADE_TABLES.get(tier, _CARB_GRADE_TABLES["lightly_played"])
	)
	var has_provenance: bool = (
		item.definition != null and item.definition.provenance_score >= 0.7
	)
	var grades: Array[int] = []
	var weights: Array[int] = []
	var total_weight: int = 0
	for entry: Variant in (base_table as Array):
		var pair: Array = entry as Array
		var grade: int = int(pair[0])
		var weight: int = int(pair[1])
		if grade == AuthGrade.COUNTERFEIT and has_provenance:
			weight = maxi(weight / 2, 0)
		grades.append(grade)
		weights.append(weight)
		total_weight += weight
	if total_weight == 0:
		return AuthGrade.GOOD
	var roll: int = rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for i: int in range(weights.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return grades[i]
	return grades[-1]


## Maps a CARB grade int to its bracket label for the partial-information reveal.
func _classify_carb_bracket(grade: int) -> String:
	if grade <= 3:
		return "BRACKET_LOW"
	if grade <= 5:
		return "BRACKET_MID"
	if grade <= 8:
		return "BRACKET_HIGH"
	return "BRACKET_ELITE"


## Builds the reveal schedule for a CARB submission based on the chosen tier.
## Economy: binary reveal at day 3, final at day 5.
## Express: binary at day 1, final at day 2.
## Premium: bracket+binary at day 1, final at day 2.
func _build_carb_reveal_schedule(tier: int, bracket: String) -> Array:
	match tier:
		AuthTier.EXPRESS:
			return [
				{"day_offset": 1, "reveal_type": "binary"},
				{"day_offset": 2, "reveal_type": "final_grade"},
			]
		AuthTier.PREMIUM:
			return [
				{"day_offset": 1, "reveal_type": "bracket", "bracket": bracket},
				{"day_offset": 1, "reveal_type": "binary"},
				{"day_offset": 2, "reveal_type": "final_grade"},
			]
		_:  # ECONOMY default
			return [
				{"day_offset": 3, "reveal_type": "binary"},
				{"day_offset": 5, "reveal_type": "final_grade"},
			]


## Processes pending CARB reveals for the current day.
## Called from _on_day_started so reveals fire at the top of each new day.
func _process_carb_reveals(day: int) -> void:
	var to_finalize: Array[String] = []
	for item_id: String in _pending_carb_auths:
		var auth: Dictionary = _pending_carb_auths[item_id]
		var elapsed: int = day - int(auth.get("submission_day", day))
		var schedule: Array = auth.get("reveal_schedule", [])
		var revealed: Array = auth.get("revealed_indices", [])
		for i: int in range(schedule.size()):
			if i in revealed:
				continue
			var event: Dictionary = schedule[i] as Dictionary
			if elapsed >= int(event.get("day_offset", 999)):
				revealed.append(i)
				auth["revealed_indices"] = revealed
				_emit_carb_reveal(item_id, auth, event)
				if event.get("reveal_type", "") == "final_grade":
					to_finalize.append(item_id)
	for item_id: String in to_finalize:
		_finalize_carb_authentication(item_id)


## Emits the appropriate notification for a single CARB reveal event.
func _emit_carb_reveal(
	item_id: String, auth: Dictionary, event: Dictionary
) -> void:
	var final_grade: int = int(auth.get("final_grade", AuthGrade.GOOD))
	var reveal_type: String = event.get("reveal_type", "")
	var item: ItemInstance = (
		_inventory_system.get_item(item_id) if _inventory_system else null
	)
	var name_str: String = (
		item.definition.item_name if item and item.definition else item_id
	)
	match reveal_type:
		"binary":
			var authentic: bool = final_grade != AuthGrade.COUNTERFEIT
			EventBus.notification_requested.emit(
				"CARB update for %s: %s" % [
					name_str,
					"AUTHENTIC — awaiting final grade." if authentic
					else "WARNING: COUNTERFEIT detected.",
				]
			)
		"bracket":
			var bracket: String = event.get("bracket", auth.get("bracket", ""))
			EventBus.notification_requested.emit(
				"CARB assessment for %s: %s" % [name_str, _bracket_display_text(bracket)]
			)


## Applies the final CARB grade to the item and emits store_auth_resolved.
func _finalize_carb_authentication(item_id: String) -> void:
	var auth: Dictionary = _pending_carb_auths.get(item_id, {})
	if auth.is_empty():
		return
	var grade: int = int(auth.get("final_grade", AuthGrade.GOOD))
	if _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(item_id)
		if item:
			item.authentication_status = "carb_graded"
			item.numeric_grade = grade
			item.is_graded = true
			var base_val: float = item.definition.base_price if item.definition else 0.0
			var final_val: float = (
				base_val * float(CARB_GRADE_MULTIPLIERS.get(grade, 0.0))
			)
			EventBus.store_auth_resolved.emit(StringName(item_id), grade, final_val)
			EventBus.toast_requested.emit(
				"CARB Final Grade: %s — %s" % [
					item.definition.item_name if item.definition else item_id,
					_carb_grade_label(grade),
				],
				&"sports",
				4.0,
			)
	_pending_carb_auths.erase(item_id)


func _build_definition_from_entry(
	canonical_id: StringName, data: Dictionary
) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = String(canonical_id)
	if data.has("item_name"):
		def.item_name = str(data["item_name"])
	if data.has("base_price"):
		def.base_price = float(data["base_price"])
	if data.has("category"):
		def.category = str(data["category"])
	if data.has("rarity"):
		def.rarity = str(data["rarity"])
	if data.has("store_type"):
		def.store_type = str(data["store_type"])
	if data.has("suspicious_chance"):
		def.suspicious_chance = float(data["suspicious_chance"])
	if data.has("era"):
		def.era = str(data["era"])
	if data.has("provenance_score"):
		def.provenance_score = float(data["provenance_score"])
	return def

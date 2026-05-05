## Tests for TradeInSystem: valuation formula, state machine transitions,
## unlock gating, and signal emissions.
##
## Covers ISSUE-012 acceptance criteria:
## - Valuation formula uses trust >= 40 (not > 40) as the boundary.
## - State machine walks ITEM_INSPECT → CONDITION_CHECK → VALUE_OFFER →
##   AWAITING_PLAYER_DECISION → ACCEPT_PATH/RECEIPT_SHOWN → IDLE.
## - Decline path emits trade_in_rejected and returns to IDLE.
## - Silent cancel emits trade_in_rejected with no inventory / cash side-effect.
## - Receipt auto-dismisses to IDLE on complete_receipt().
## - Panel-side LOCKED gating reflects UnlockSystem.is_unlocked.
## - All five EventBus trade_in_* signals fire at the correct transitions.
extends GutTest


const _STORE_ID: StringName = &"retro_games"


class _StubInventorySystem:
	extends Node
	var created_items: Array[Dictionary] = []
	var return_null: bool = false

	func create_item(
		definition_id: String, condition: String, acquired_price: float
	) -> ItemInstance:
		created_items.append({
			"definition_id": definition_id,
			"condition": condition,
			"acquired_price": acquired_price,
		})
		if return_null:
			return null
		var def: ItemDefinition = ItemDefinition.new()
		def.id = definition_id
		def.item_name = "Stub Item"
		def.base_price = 10.0
		var instance: ItemInstance = ItemInstance.create(
			def, condition, 0, acquired_price
		)
		return instance


class _StubEconomySystem:
	extends Node
	var deductions: Array[Dictionary] = []

	func deduct_cash(amount: float, reason: String) -> bool:
		deductions.append({"amount": amount, "reason": reason})
		return true


class _StubReputationSystem:
	extends Node
	var score: float = 0.0

	func get_reputation(_store_id: String = "") -> float:
		return score


var _system: TradeInSystem
var _inventory: _StubInventorySystem
var _economy: _StubEconomySystem
var _reputation: _StubReputationSystem
var _definition: ItemDefinition


func before_each() -> void:
	_system = TradeInSystem.new()
	_inventory = _StubInventorySystem.new()
	_economy = _StubEconomySystem.new()
	_reputation = _StubReputationSystem.new()
	add_child_autofree(_inventory)
	add_child_autofree(_economy)
	add_child_autofree(_reputation)
	add_child_autofree(_system)
	_system.inventory_system = _inventory
	_system.economy_system = _economy
	_system.reputation_system = _reputation
	# Bypass the unlock gate for tests not covering the locked path.
	_system.current_state = TradeInSystem.State.IDLE

	_definition = ItemDefinition.new()
	_definition.id = "cart_master_64_nes"
	_definition.item_name = "CartMaster 64"
	_definition.base_price = 12.0
	_definition.platform = "NES"


# ── Trust-bonus boundary ─────────────────────────────────────────────────────


func test_trust_bonus_below_40_is_zero() -> void:
	assert_eq(TradeInSystem.get_trust_bonus(0.0), 0.0)
	assert_eq(TradeInSystem.get_trust_bonus(39.99), 0.0)


func test_trust_bonus_at_exactly_40_is_first_tier() -> void:
	# Acceptance criterion: boundary uses >= (not >) so trust = 40 unlocks the
	# first bonus tier. This is the canonical regression target.
	assert_eq(
		TradeInSystem.get_trust_bonus(40.0), 0.03,
		"trust=40 must enter the first bonus tier (>= boundary)"
	)


func test_trust_bonus_60_tier() -> void:
	assert_eq(TradeInSystem.get_trust_bonus(59.99), 0.03)
	assert_eq(TradeInSystem.get_trust_bonus(60.0), 0.06)


func test_trust_bonus_80_tier() -> void:
	assert_eq(TradeInSystem.get_trust_bonus(79.99), 0.06)
	assert_eq(TradeInSystem.get_trust_bonus(80.0), 0.10)


func test_trust_bonus_100_caps_at_top_tier() -> void:
	assert_eq(TradeInSystem.get_trust_bonus(100.0), 0.10)
	assert_eq(TradeInSystem.get_trust_bonus(150.0), 0.10)


# ── Valuation per condition ──────────────────────────────────────────────────


func test_compute_offer_mint_no_trust() -> void:
	# 12.00 * 0.55 * 1.0 = 6.60 → snap to 6.50
	assert_eq(TradeInSystem.compute_offer(12.0, "mint", 0.0), 6.50)


func test_compute_offer_good_no_trust() -> void:
	# 12.00 * 0.40 * 1.0 = 4.80 → snap to 4.75
	assert_eq(TradeInSystem.compute_offer(12.0, "good", 0.0), 4.75)


func test_compute_offer_fair_no_trust() -> void:
	# 12.00 * 0.25 * 1.0 = 3.00 → snap to 3.00
	assert_eq(TradeInSystem.compute_offer(12.0, "fair", 0.0), 3.00)


func test_compute_offer_poor_no_trust() -> void:
	# 12.00 * 0.12 * 1.0 = 1.44 → snap to 1.50
	assert_eq(TradeInSystem.compute_offer(12.0, "poor", 0.0), 1.50)


func test_compute_offer_damaged_no_trust() -> void:
	# 12.00 * 0.05 * 1.0 = 0.60 → snap to 0.50
	assert_eq(TradeInSystem.compute_offer(12.0, "damaged", 0.0), 0.50)


func test_compute_offer_floor_at_quarter() -> void:
	# Tiny base × damaged would be < 0.25; floor protects the minimum.
	assert_eq(TradeInSystem.compute_offer(0.10, "damaged", 0.0), 0.25)


func test_compute_offer_at_trust_40_boundary() -> void:
	# 12.00 * (0.40 + 0.03) * 1.0 = 5.16 → snap to 5.25
	assert_eq(
		TradeInSystem.compute_offer(12.0, "good", 40.0), 5.25,
		"trust=40 must apply the +0.03 first-tier bonus"
	)


func test_compute_offer_unknown_condition_treated_as_zero_mult() -> void:
	# Unknown condition string falls back to 0.0 multiplier; floor wins.
	assert_eq(TradeInSystem.compute_offer(12.0, "wrecked", 0.0), 0.25)


# ── State machine: accept path ────────────────────────────────────────────────


func test_begin_interaction_advances_to_item_inspect() -> void:
	_system.begin_interaction("cust_1", _definition.id, _definition)
	assert_eq(
		_system.current_state, TradeInSystem.State.ITEM_INSPECT,
		"begin_interaction must walk through CUSTOMER_APPROACHES to ITEM_INSPECT"
	)


func test_begin_interaction_emits_trade_in_initiated() -> void:
	watch_signals(EventBus)
	_system.begin_interaction("cust_1", _definition.id, _definition)
	assert_signal_emitted_with_parameters(
		EventBus, "trade_in_initiated", ["cust_1"]
	)


func test_full_accept_path_ends_in_receipt_shown() -> void:
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	assert_eq(_system.current_state, TradeInSystem.State.CONDITION_CHECK)
	_system.select_condition("good")
	_system.appraise()
	assert_eq(
		_system.current_state, TradeInSystem.State.AWAITING_PLAYER_DECISION,
		"appraise must advance through VALUE_OFFER into AWAITING_PLAYER_DECISION"
	)
	var iid: String = _system.make_offer()
	assert_false(iid.is_empty(), "make_offer should return a non-empty id")
	assert_eq(_system.current_state, TradeInSystem.State.RECEIPT_SHOWN)


func test_make_offer_calls_inventory_create_item() -> void:
	_reputation.score = 0.0
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("good")
	_system.appraise()
	_system.make_offer()
	assert_eq(_inventory.created_items.size(), 1)
	var record: Dictionary = _inventory.created_items[0]
	assert_eq(record["definition_id"], _definition.id)
	assert_eq(record["condition"], "good")
	assert_eq(float(record["acquired_price"]), 4.75)


func test_make_offer_deducts_cash() -> void:
	_reputation.score = 0.0
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("good")
	_system.appraise()
	_system.make_offer()
	assert_eq(_economy.deductions.size(), 1)
	assert_eq(float(_economy.deductions[0]["amount"]), 4.75)


func test_offer_made_signal_carries_condition_and_value() -> void:
	watch_signals(EventBus)
	_reputation.score = 40.0
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("good")
	_system.appraise()
	# 12 * (0.40 + 0.03) * 1.0 = 5.16 → 5.25
	assert_signal_emitted_with_parameters(
		EventBus, "trade_in_offer_made",
		["cust_1", _definition.id, "good", 5.25]
	)


func test_accept_emits_trade_in_accepted_and_completed() -> void:
	watch_signals(EventBus)
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("mint")
	_system.appraise()
	_system.make_offer()
	assert_signal_emitted(EventBus, "trade_in_accepted")
	assert_signal_emitted(EventBus, "trade_in_completed")


func test_complete_receipt_returns_to_idle() -> void:
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("mint")
	_system.appraise()
	_system.make_offer()
	_system.complete_receipt()
	assert_eq(_system.current_state, TradeInSystem.State.IDLE)
	assert_eq(_system.current_customer_id, "")


# ── State machine: reject path ────────────────────────────────────────────────


func test_decline_emits_trade_in_rejected_and_returns_idle() -> void:
	watch_signals(EventBus)
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("good")
	_system.appraise()
	_system.decline()
	assert_signal_emitted_with_parameters(
		EventBus, "trade_in_rejected", ["cust_1"]
	)
	assert_eq(_system.current_state, TradeInSystem.State.IDLE)


func test_decline_does_not_create_item_or_deduct_cash() -> void:
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("good")
	_system.appraise()
	_system.decline()
	assert_eq(_inventory.created_items.size(), 0)
	assert_eq(_economy.deductions.size(), 0)


# ── Silent cancel ─────────────────────────────────────────────────────────────


func test_silent_cancel_during_awaiting_emits_rejected_no_side_effects() -> void:
	watch_signals(EventBus)
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("good")
	_system.appraise()
	_system.silent_cancel()
	assert_eq(_system.current_state, TradeInSystem.State.IDLE)
	assert_signal_emitted(EventBus, "trade_in_rejected")
	assert_eq(_inventory.created_items.size(), 0)
	assert_eq(_economy.deductions.size(), 0)


func test_silent_cancel_in_idle_is_noop() -> void:
	watch_signals(EventBus)
	# starts in IDLE per before_each
	_system.silent_cancel()
	assert_eq(_system.current_state, TradeInSystem.State.IDLE)
	assert_signal_not_emitted(EventBus, "trade_in_rejected")


# ── Backroom-full failure path ────────────────────────────────────────────────


func test_make_offer_handles_backroom_full() -> void:
	_inventory.return_null = true
	_system.begin_interaction("cust_1", _definition.id, _definition)
	_system.confirm_platform()
	_system.select_condition("mint")
	_system.appraise()
	var iid: String = _system.make_offer()
	assert_eq(iid, "", "make_offer should return empty id when create_item fails")
	assert_eq(
		_system.current_state, TradeInSystem.State.AWAITING_PLAYER_DECISION,
		"failure should leave the panel in AWAITING so the player can retry"
	)
	assert_eq(_economy.deductions.size(), 0, "no cash deduction on failure")


# ── Locked gating ─────────────────────────────────────────────────────────────


func test_locked_state_blocks_begin_interaction() -> void:
	_system.current_state = TradeInSystem.State.LOCKED
	_system.begin_interaction("cust_1", _definition.id, _definition)
	assert_eq(
		_system.current_state, TradeInSystem.State.LOCKED,
		"begin_interaction must be a no-op while LOCKED"
	)

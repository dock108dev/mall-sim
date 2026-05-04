## Verifies the mall hub overlay (KPIStrip + MallOverview store cards) and the
## in-store HUD read the same cash, inventory, and sold-count state from the
## same EconomySystem / InventorySystem / EventBus sources, with no scene
## reload required between updates.
extends GutTest


const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")
const _KpiScene: PackedScene = preload("res://game/scenes/ui/kpi_strip.tscn")
const _MallOverviewScene: PackedScene = preload(
	"res://game/scenes/mall/mall_overview.tscn"
)
const _StoreSlotCardScene: PackedScene = preload(
	"res://game/scenes/mall/store_slot_card.tscn"
)
const _CASH_TWEEN_SETTLE: float = 0.45


var _hud: CanvasLayer
var _kpi: PanelContainer
var _overview: MallOverview
var _economy: EconomySystem
var _inventory: InventorySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	_economy.name = "EconomySystem"
	add_child_autofree(_economy)
	_inventory = InventorySystem.new()
	_inventory.name = "InventorySystem"
	add_child_autofree(_inventory)


func after_each() -> void:
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
		_hud = null
	if _kpi and is_instance_valid(_kpi):
		_kpi.queue_free()
		_kpi = null
	if _overview and is_instance_valid(_overview):
		_overview.queue_free()
		_overview = null


func _make_def(id: String) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = id
	def.item_name = id.capitalize()
	def.category = "cartridges"
	def.base_price = 10.0
	def.store_type = "retro_games"
	return def


# ── KPIStrip cash seed parity with HUD ────────────────────────────────────────

func test_kpi_strip_seeds_cash_from_economy_on_ready() -> void:
	# EconomySystem.initialize() writes player_cash via _apply_state and does
	# NOT emit money_changed. The KPIStrip must seed from EconomySystem.get_cash()
	# at _ready so it does not show $0 until the first transaction.
	_economy.initialize(750.0)
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	var label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	assert_string_contains(
		label.text, "750",
		"KPIStrip must seed cash from EconomySystem.get_cash() at _ready"
	)


func test_kpi_strip_seeds_cash_on_day_started() -> void:
	# day_started arrives after EconomySystem.initialize() in the boot path
	# (apply_pending_session_state). Seeding here covers test orderings where
	# the strip was constructed before initialize() ran.
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	_economy.initialize(500.0)
	EventBus.day_started.emit(1)
	var label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	assert_string_contains(
		label.text, "500",
		"KPIStrip CashLabel must reflect EconomySystem.get_cash() after day_started"
	)


func test_kpi_strip_seeds_cash_on_gameplay_ready() -> void:
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	_economy.initialize(1234.0)
	EventBus.gameplay_ready.emit()
	var label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	assert_string_contains(
		label.text, "1234",
		"KPIStrip CashLabel must reflect EconomySystem.get_cash() after gameplay_ready"
	)


func test_kpi_strip_seed_silent_when_economy_missing() -> void:
	# Drop the EconomySystem child so GameManager.get_economy_system() returns null.
	_economy.queue_free()
	_economy = null
	await get_tree().process_frame
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	# No crash; label stays at the default.
	var label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	assert_eq(label.text, "$0", "KPIStrip must default to $0 when no economy autoload")


func test_kpi_strip_and_hud_show_same_cash_after_money_changed() -> void:
	_economy.initialize(500.0)
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	_hud = _HudScene.instantiate() as CanvasLayer
	add_child_autofree(_hud)
	# Drive a credit through EconomySystem so both surfaces process the same
	# money_changed payload — no manual emits.
	_economy.credit(125.50, &"sale")
	await get_tree().create_timer(_CASH_TWEEN_SETTLE).timeout
	var kpi_label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	var hud_label: Label = _hud.get_node("TopBar/CashLabel")
	# KPIStrip rounds to whole dollars; HUD shows .cents. Both must reflect $625(.50).
	assert_string_contains(
		kpi_label.text, "625",
		"KPIStrip must show updated cash after EconomySystem.credit"
	)
	assert_string_contains(
		hud_label.text, "625",
		"HUD must show updated cash after EconomySystem.credit"
	)


# ── MallOverview reads same InventorySystem state ─────────────────────────────

func test_mall_overview_inventory_count_matches_inventory_system() -> void:
	_overview = _MallOverviewScene.instantiate() as MallOverview
	add_child_autofree(_overview)
	# Manually wire a card without invoking setup() (which iterates the registry
	# and would require the full content tree). The signal handler reads from
	# the same InventorySystem GameManager exposes globally.
	var card: StoreSlotCard = _StoreSlotCardScene.instantiate() as StoreSlotCard
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	_overview._cards[&"retro_games"] = card
	_overview._inventory_system = _inventory
	# Add three items: two assigned to shelf, one in backroom. The card's
	# Inventory readout uses get_stock(store_id) — backroom + shelf together.
	for i: int in range(3):
		var def: ItemDefinition = _make_def("item_%d" % i)
		var inst: ItemInstance = ItemInstance.create(def, "good", 0, def.base_price)
		inst.current_location = "backroom"
		_inventory.add_item(&"retro_games", inst)
	assert_eq(
		card._stock_count, 3,
		"StoreSlotCard inventory must count backroom + shelf items"
	)


func test_mall_overview_card_updates_on_inventory_changed_no_reload() -> void:
	_overview = _MallOverviewScene.instantiate() as MallOverview
	add_child_autofree(_overview)
	var card: StoreSlotCard = _StoreSlotCardScene.instantiate() as StoreSlotCard
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	_overview._cards[&"retro_games"] = card
	_overview._inventory_system = _inventory
	var def: ItemDefinition = _make_def("removable")
	var inst: ItemInstance = ItemInstance.create(def, "good", 0, def.base_price)
	inst.current_location = "backroom"
	_inventory.add_item(&"retro_games", inst)
	assert_eq(card._stock_count, 1)
	# Sale path: CheckoutSystem._execute_sale → InventorySystem.remove_item.
	# Card must reflect the drop without re-instancing the overview scene.
	_inventory.remove_item(inst.instance_id)
	assert_eq(
		card._stock_count, 0,
		"StoreSlotCard must decrement stock count on inventory_updated"
	)


# ── Sale parity: cash and sold count on both surfaces, no scene reload ────────

func test_sale_updates_kpi_cash_and_overview_sold_count_no_reload() -> void:
	_economy.initialize(500.0)
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	_overview = _MallOverviewScene.instantiate() as MallOverview
	add_child_autofree(_overview)
	var card: StoreSlotCard = _StoreSlotCardScene.instantiate() as StoreSlotCard
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	_overview._cards[&"retro_games"] = card
	_overview._economy_system = _economy
	# customer_purchased is the production sale path: EconomySystem._on_customer_purchased
	# credits cash and records store revenue, MallOverview increments per-store
	# sold count, and KPIStrip listens on money_changed. No scene reload between.
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_x", 25.0, &"customer_a"
	)
	var kpi_label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	assert_string_contains(
		kpi_label.text, "525",
		"KPIStrip cash must reflect the sale credit without scene reload"
	)
	assert_eq(
		card._sold_label.text, "Today: 1 sold",
		"StoreSlotCard must increment today-sold on customer_purchased"
	)


# ── No stale state from a prior session ───────────────────────────────────────

func test_kpi_strip_resets_cash_on_new_economy_initialize() -> void:
	# Simulates main-menu → new game: a stale strip is replaced and the new
	# instance must re-seed from the freshly initialized EconomySystem rather
	# than carry the prior session's cash forward.
	_economy.initialize(750.0)
	_kpi = _KpiScene.instantiate() as PanelContainer
	add_child_autofree(_kpi)
	_economy.initialize(200.0)
	EventBus.gameplay_ready.emit()
	var label: Label = _kpi.get_node("MarginContainer/Row/CashLabel")
	assert_string_contains(
		label.text, "200",
		"KPIStrip must re-seed from the new EconomySystem.get_cash() value"
	)


func test_overview_today_sold_resets_to_zero_on_day_started() -> void:
	_overview = _MallOverviewScene.instantiate() as MallOverview
	add_child_autofree(_overview)
	var card: StoreSlotCard = _StoreSlotCardScene.instantiate() as StoreSlotCard
	add_child_autofree(card)
	card.setup(&"retro_games", "Retro Games")
	_overview._cards[&"retro_games"] = card
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_a", 10.0, &"customer_a"
	)
	assert_eq(card._sold_label.text, "Today: 1 sold")
	EventBus.day_started.emit(2)
	assert_eq(
		card._sold_label.text, "Today: 0 sold",
		"Day rollover must clear stale per-store sold counts"
	)

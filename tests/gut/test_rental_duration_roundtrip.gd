## Covers ISSUE-014 acceptance: rent_item returns a structured record,
## duration options expose >= 2 tiers with prices, the rent → advance day →
## return round-trip emits rental_returned, and active rentals persist across
## save/load.
extends GutTest

var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader

const CHECKOUT_DAY: int = 5


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader

	_controller = VideoRentalStoreController.new()
	_inventory = InventorySystem.new()
	_economy = EconomySystem.new()
	add_child_autofree(_controller)
	add_child_autofree(_inventory)
	add_child_autofree(_economy)
	_inventory.initialize(_data_loader)
	_economy.initialize(500.0)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader


func test_get_rental_duration_options_exposes_two_or_more_priced_tiers() -> void:
	var item: ItemInstance = _register_item("tape_opts", "good")

	var options: Array[Dictionary] = _controller.get_rental_duration_options(
		item, CHECKOUT_DAY
	)

	assert_gte(
		options.size(),
		2,
		"Duration options must expose at least two tier choices for the UI"
	)
	for opt: Dictionary in options:
		assert_true(
			opt.has("tier") and opt.has("days") and opt.has("price"),
			"Each option must carry tier, days, and price for the UI"
		)
		assert_gt(
			float(opt.get("price", 0.0)),
			0.0,
			"Every duration option must have a positive price"
		)


func test_rent_item_returns_structured_record_and_decrements_available_stock() -> void:
	var item: ItemInstance = _register_item("tape_rent", "good")
	var available_before: int = _controller.get_available_count()

	var result: Dictionary = _controller.rent_item(
		item.instance_id, "three_day", CHECKOUT_DAY, "cust_1"
	)

	assert_eq(
		String(result.get("tape_id", "")),
		item.instance_id,
		"rent_item result must carry the rented tape_id"
	)
	assert_eq(
		int(result.get("due_day", -1)),
		CHECKOUT_DAY + int(VideoRentalStoreController.RENTAL_DURATIONS["three_day"]),
		"rent_item result must expose the computed due_day"
	)
	assert_gt(
		float(result.get("price", 0.0)),
		0.0,
		"rent_item result must expose the charged price"
	)
	assert_eq(
		_controller.get_available_count(),
		maxi(available_before - 1, 0),
		"Renting a tape should decrement available stock"
	)


func test_rent_advance_day_return_round_trip_restocks_and_emits_signal() -> void:
	var item: ItemInstance = _register_item("tape_round", "good")
	var returned_ids: Array[String] = []
	var on_returned: Callable = func(iid: String, _worn: bool) -> void:
		returned_ids.append(iid)
	EventBus.rental_returned.connect(on_returned)

	var result: Dictionary = _controller.rent_item(
		item.instance_id, "overnight", CHECKOUT_DAY
	)
	assert_eq(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Rented tape leaves the shelf"
	)

	_controller._on_day_started(int(result["due_day"]))

	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Rental record should clear after the round-trip return"
	)
	assert_eq(
		item.current_location,
		VideoRentalStoreController.RETURNS_BIN_LOCATION,
		"Returned tape should restock into the returns bin"
	)
	assert_true(
		item.instance_id in returned_ids,
		"rental_returned signal should fire on the round-trip return"
	)

	EventBus.rental_returned.disconnect(on_returned)


func test_active_rentals_persist_across_save_and_load() -> void:
	var item: ItemInstance = _register_item("tape_save", "good")
	var rental: Dictionary = _controller.rent_item(
		item.instance_id, "weekly", CHECKOUT_DAY, "cust_7"
	)
	var due_day: int = int(rental["due_day"])
	var save_data: Dictionary = _controller.get_save_data()

	var reloaded := VideoRentalStoreController.new()
	add_child_autofree(reloaded)
	reloaded.set_inventory_system(_inventory)
	reloaded.set_economy_system(_economy)
	reloaded.load_save_data(save_data)

	var active: Array[Dictionary] = reloaded.get_active_rentals()
	assert_eq(
		active.size(),
		1,
		"Active rentals count should survive save/load"
	)
	assert_eq(
		String(active[0].get("instance_id", "")),
		item.instance_id,
		"Persisted rental should name the same tape"
	)
	assert_eq(
		int(active[0].get("return_day", -1)),
		due_day,
		"Persisted due day must match the pre-save value"
	)


func test_rental_checkout_dialog_shows_priced_options() -> void:
	var item: ItemInstance = _register_item("tape_ui", "good")
	var options: Array[Dictionary] = _controller.get_rental_duration_options(
		item, CHECKOUT_DAY
	)
	var dialog := RentalCheckoutDialog.new()
	add_child_autofree(dialog)

	dialog.open_for_item(item, options)

	assert_true(
		dialog.is_open(),
		"Dialog should open when given a valid item and option list"
	)
	assert_gte(
		dialog.get_option_count(),
		2,
		"Dialog must surface at least two duration options before confirm"
	)

	var confirmed_tiers: Array[String] = []
	dialog.rental_confirmed.connect(
		func(tier: String) -> void: confirmed_tiers.append(tier)
	)
	var chosen: String = dialog.get_selected_tier()
	dialog._on_confirm()

	assert_eq(
		confirmed_tiers.size(),
		1,
		"Confirming should emit rental_confirmed exactly once"
	)
	assert_eq(
		confirmed_tiers[0],
		chosen,
		"Emitted tier should match the currently selected option"
	)


func _register_item(instance_id: String, condition: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "%s_def" % instance_id
	def.item_name = "Test Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 12.0
	def.rental_fee = 3.0
	def.rental_period_days = 3
	def.rental_tier = "three_day"

	var item := ItemInstance.new()
	item.definition = def
	item.instance_id = instance_id
	item.condition = condition
	item.current_location = "shelf:slot_1"
	_inventory.register_item(item)
	return item

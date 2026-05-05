## Right-dock slide-in panel for completing sales with item list and receipt.
class_name CheckoutPanel
extends CanvasLayer

# Localization marker for static validation: tr("CHECKOUT_CONDITION")

signal sale_accepted
signal sale_declined
signal bundle_suggested

const PANEL_NAME: String = "checkout"
const RECEIPT_DISPLAY_DURATION: float = 2.0
const RESULT_DISPLAY_DURATION: float = 3.0

const _ARCHETYPE_REASONING: Dictionary = {
	&"confused_parent": (
		"Easily steered — explain the value and they'll trust you."
	),
	&"casual_shopper": (
		"No strong preference. Mention condition and they'll likely take it."
	),
	&"hype_teen": (
		"Riding a trend; talk it up and they'll bite. Push back hard and they walk."
	),
	&"sports_regular": (
		"Crossover browser — fair price keeps them, lecture and they're gone."
	),
	&"collector": (
		"Knows the market. Price honestly or they'll quietly pass."
	),
	&"bargain_hunter": (
		"Will haggle hard. Drop a few dollars and they'll close — or they'll keep poking."
	),
	&"angry_return_customer": (
		"Already irritated; don't give them ammunition. Resolve quickly."
	),
	&"shady_regular": (
		"Watch the rare items. They'll lowball; firm pricing keeps things honest."
	),
	&"reseller": (
		"Calculating margins. They'll only buy if your ask leaves room to flip."
	),
	&"enthusiast": (
		"Knows what they want. A genuine recommendation seals the deal."
	),
}

var _is_open: bool = false
var _is_pending: bool = false
var _showing_receipt: bool = false
var _showing_result: bool = false
var _items: Array[Dictionary] = []
var _haggle_discount: float = 0.0
var _subtotal: float = 0.0
var _total: float = 0.0
var _anim_tween: Tween
var _rest_x: float = 0.0
var _receipt_timer: Timer
var _result_timer: Timer
var _card_populated: bool = false
var _bundle_data: Dictionary = {}
## Tracks whether this panel pushed CTX_MODAL on InputFocus so the cursor is
## released for FP play; mirrors InventoryPanel's contract so the StorePlayerBody
## context_changed listener flips MOUSE_MODE_CAPTURED → MOUSE_MODE_VISIBLE while
## a sale is being rung up. Push/pop must stay balanced.
var _focus_pushed: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _header_row: HBoxContainer = (
	$PanelRoot/Margin/VBox/HeaderRow
)
@onready var _archetype_badge: PanelContainer = (
	$PanelRoot/Margin/VBox/HeaderRow/ArchetypeBadge
)
@onready var _archetype_label: Label = (
	$PanelRoot/Margin/VBox/HeaderRow/ArchetypeBadge/ArchetypeLabel
)
@onready var _customer_card: VBoxContainer = (
	$PanelRoot/Margin/VBox/CustomerCard
)
@onready var _want_label: Label = (
	$PanelRoot/Margin/VBox/CustomerCard/WantLabel
)
@onready var _context_label: Label = (
	$PanelRoot/Margin/VBox/CustomerCard/ContextLabel
)
@onready var _reasoning_label: RichTextLabel = (
	$PanelRoot/Margin/VBox/ReasoningLabel
)
@onready var _reasoning_spacer: Control = (
	$PanelRoot/Margin/VBox/ReasoningSpacer
)
@onready var _item_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/ItemScroll/ItemList
)
@onready var _subtotal_value: Label = (
	$PanelRoot/Margin/VBox/TotalsSection/SubtotalRow/SubtotalValue
)
@onready var _discount_row: HBoxContainer = (
	$PanelRoot/Margin/VBox/TotalsSection/DiscountRow
)
@onready var _discount_value: Label = (
	$PanelRoot/Margin/VBox/TotalsSection/DiscountRow/DiscountValue
)
@onready var _total_value: Label = (
	$PanelRoot/Margin/VBox/TotalsSection/TotalRow/TotalValue
)
@onready var _error_label: Label = (
	$PanelRoot/Margin/VBox/ErrorLabel
)
@onready var _confirm_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ConfirmButton
)
@onready var _bundle_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/BundleButton
)
@onready var _cancel_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/CancelButton
)
@onready var _result_label: Label = (
	$PanelRoot/Margin/VBox/ResultLabel
)
@onready var _receipt_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/ReceiptSection
)
@onready var _receipt_item_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptItemList
)
@onready var _receipt_total_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptTotalLabel
)
@onready var _receipt_timestamp_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptTimestampLabel
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_apply_card_style()
	DecisionCardStyle.apply_reasoning_style(_reasoning_label)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_bundle_button.pressed.connect(_on_bundle_pressed)
	_receipt_timer = Timer.new()
	_receipt_timer.one_shot = true
	_receipt_timer.wait_time = RECEIPT_DISPLAY_DURATION
	_receipt_timer.timeout.connect(_on_receipt_timer_timeout)
	add_child(_receipt_timer)
	_result_timer = Timer.new()
	_result_timer.one_shot = true
	_result_timer.wait_time = RESULT_DISPLAY_DURATION
	_result_timer.timeout.connect(_on_result_timer_timeout)
	add_child(_result_timer)
	EventBus.checkout_started.connect(_on_checkout_started)
	EventBus.transaction_completed.connect(
		_on_transaction_completed
	)
	EventBus.panel_opened.connect(_on_panel_opened)
	SceneRouter.scene_ready.connect(_on_scene_ready)


## §F-82 — Defensive cleanup so a modal removed mid-display (scene swap, run
## reset, panel queue_free) does not strand a CTX_MODAL frame on InputFocus.
## `_pop_modal_focus` itself escalates with `push_error` if the topmost frame
## is not CTX_MODAL (§F-74 contract), so a corrupted stack is still surfaced
## loudly — the silent skip here is only the well-behaved no-op path.
func _exit_tree() -> void:
	if _focus_pushed:
		_pop_modal_focus()


## Opens the panel with a list of items for sale.
func show_checkout(
	items: Array[Dictionary],
	haggle_discount: float = 0.0,
) -> void:
	_items = items
	_haggle_discount = haggle_discount
	_is_pending = false
	_showing_receipt = false
	_showing_result = false
	_card_populated = false
	_bundle_data = {}
	_error_label.visible = false
	_receipt_section.visible = false
	_result_label.visible = false
	_archetype_badge.visible = false
	_customer_card.visible = false
	_reasoning_label.visible = false
	_reasoning_spacer.visible = false
	_bundle_button.visible = false
	_confirm_button.visible = true
	_cancel_button.visible = true
	_confirm_button.disabled = false
	_cancel_button.disabled = false
	_bundle_button.disabled = false
	_confirm_button.text = "Confirm Sale"
	_cancel_button.text = "Cancel"
	_clear_button_extras(_confirm_button)
	_clear_button_extras(_cancel_button)
	_clear_button_extras(_bundle_button)
	_set_panel_active_palette()
	_populate_item_list()
	_update_totals()
	PanelAnimator.kill_tween(_anim_tween)
	_is_open = true
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, false
	)
	# Emit FIRST so any sibling panels' mutual-exclusion handlers run their
	# hide and pop their own frames, THEN claim modal focus on top of whatever
	# world context was current. Mirrors InventoryPanel.open().
	EventBus.panel_opened.emit(PANEL_NAME)
	_push_modal_focus()


## Closes the checkout panel with optional immediate hide.
func hide_checkout(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	_is_pending = false
	_showing_receipt = false
	_showing_result = false
	_card_populated = false
	_receipt_timer.stop()
	_result_timer.stop()
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	# Pop FIRST while CTX_MODAL is still on top, THEN broadcast close. Mirrors
	# InventoryPanel.close().
	_pop_modal_focus()
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func is_showing_receipt() -> bool:
	return _showing_receipt


func is_showing_result() -> bool:
	return _showing_result


func is_card_populated() -> bool:
	return _card_populated


## Returns false — warranty is handled by WarrantyDialog.
func is_warranty_offered() -> bool:
	return false


## Returns 0 — warranty is handled by WarrantyDialog.
func get_warranty_fee() -> float:
	return 0.0


## Populates the decision-card surface from a customer-data dictionary.
##
## Expected keys (all optional — missing keys produce safe empty fallbacks):
##   archetype_id    : StringName — drives badge color and reasoning lookup
##   archetype_label : String     — display name for the badge
##   want            : String     — 1-sentence "what they want"
##   context         : String     — 1-sentence mood / situation
##   reasoning       : String     — 1-sentence italic hint above choices
##   offer_price     : float      — final price to display on Confirm button
##   sticker_price   : float      — used to compute delta from ask
##   rep_delta       : String     — preformatted rep change ("+1 Rep")
##   decline_label   : String     — secondary line on Cancel button
##   bundle          : Dictionary — { "label": String, "consequence": String,
##                                    "id": String } when bundle is offered
func populate_customer_card(customer_data: Dictionary) -> void:
	_card_populated = true
	var archetype_id: StringName = StringName(
		str(customer_data.get("archetype_id", ""))
	)
	var archetype_label: String = str(
		customer_data.get("archetype_label", "")
	)
	var want_text: String = str(customer_data.get("want", ""))
	var context_text: String = str(customer_data.get("context", ""))
	var reasoning_text: String = str(customer_data.get("reasoning", ""))
	if reasoning_text.is_empty():
		reasoning_text = String(_ARCHETYPE_REASONING.get(archetype_id, ""))
	var offer_price: float = float(customer_data.get("offer_price", 0.0))
	var sticker_price: float = float(customer_data.get("sticker_price", offer_price))
	var rep_delta_str: String = str(customer_data.get("rep_delta", "+1 Rep"))
	var decline_label: String = str(customer_data.get("decline_label", ""))

	if not archetype_label.is_empty():
		_archetype_label.text = archetype_label.to_upper()
		_archetype_badge.visible = true
		DecisionCardStyle.apply_archetype_badge_style(
			_archetype_badge, _archetype_label, archetype_id
		)
	else:
		_archetype_badge.visible = false

	if want_text.is_empty() and context_text.is_empty():
		_customer_card.visible = false
	else:
		_customer_card.visible = true
		_want_label.text = want_text
		_want_label.visible = not want_text.is_empty()
		_context_label.text = context_text
		_context_label.visible = not context_text.is_empty()

	if reasoning_text.is_empty():
		_reasoning_label.visible = false
		_reasoning_spacer.visible = false
	else:
		_set_reasoning_text(reasoning_text)
		_reasoning_label.visible = true
		_reasoning_spacer.visible = true

	_set_two_line_button(
		_confirm_button,
		"Sell at $%.2f" % offer_price,
		_format_consequence_preview(offer_price, sticker_price, rep_delta_str),
	)
	if decline_label.is_empty():
		decline_label = "Customer leaves, −Rep"
	_set_two_line_button(_cancel_button, "Pass", decline_label)

	var bundle: Variant = customer_data.get("bundle", null)
	if bundle is Dictionary and not (bundle as Dictionary).is_empty():
		_bundle_data = (bundle as Dictionary).duplicate()
		_bundle_button.visible = true
		_set_two_line_button(
			_bundle_button,
			str(_bundle_data.get("label", "Suggest Bundle")),
			str(_bundle_data.get("consequence", "")),
		)
	else:
		_bundle_data = {}
		_bundle_button.visible = false


## Transitions the panel into Result state showing a 1-2 sentence consequence
## summary. Auto-dismisses after RESULT_DISPLAY_DURATION or on any button press.
func show_result(resolution_text: String) -> void:
	if resolution_text.is_empty():
		return
	_showing_result = true
	_set_pending(false)
	_confirm_button.visible = false
	_cancel_button.visible = false
	_bundle_button.visible = false
	_reasoning_label.visible = false
	_reasoning_spacer.visible = false
	_result_label.text = resolution_text
	_result_label.visible = true
	_set_panel_result_palette()
	_result_timer.stop()
	_result_timer.start()


## Returns the bundle suggestion data after a bundle press, or empty dict.
func get_active_bundle() -> Dictionary:
	return _bundle_data.duplicate()


## Static archetype label derivation from a CustomerTypeDefinition profile.
## Returns a Dictionary with keys "archetype_id", "label", "conflict" (int).
static func derive_archetype_label(
	profile: CustomerTypeDefinition
) -> Dictionary:
	if profile == null:
		return {
			"archetype_id": &"",
			"label": "",
			"conflict": DecisionCardStyle.ConflictLevel.NEUTRAL,
		}
	var archetype_id: StringName = profile.archetype_id
	var label: String = ""
	if not archetype_id.is_empty():
		label = String(archetype_id).capitalize().replace("_", " ")
	else:
		var derived: StringName = _derive_archetype_from_traits(
			profile.price_sensitivity, profile.patience
		)
		archetype_id = derived
		label = String(derived).capitalize().replace("_", " ")
	return {
		"archetype_id": archetype_id,
		"label": label,
		"conflict": DecisionCardStyle.archetype_conflict_level(archetype_id),
	}


## Pure-function archetype derivation from price_sensitivity + patience floats.
## Used when profile.archetype_id is empty.
static func _derive_archetype_from_traits(
	price_sensitivity: float, patience: float
) -> StringName:
	if price_sensitivity >= 0.85:
		return &"bargain_hunter"
	if price_sensitivity <= 0.25 and patience >= 0.6:
		return &"collector"
	if patience <= 0.35 and price_sensitivity >= 0.5:
		return &"haggler"
	if patience >= 0.8:
		return &"casual_shopper"
	return &"enthusiast"


func _on_checkout_started(
	items: Array, customer_node: Node
) -> void:
	if items.is_empty():
		push_error(
			"CheckoutPanel: checkout_started with empty items"
		)
		return
	if not customer_node:
		push_error(
			"CheckoutPanel: checkout_started with null customer"
		)
		return
	# §F-66 — `checkout_started` is emitted by `CheckoutSystem._show_checkout_panel`
	# with `Array[Dictionary]` cast to `Array` for the variadic signal; any
	# non-Dictionary entry reaching this loop is a caller bug that would
	# silently drop items from the player's checkout (data integrity:
	# missing line-item revenue). `push_warning` surfaces the offending type
	# while keeping the well-formed remainder of the cart intact so the sale
	# isn't blocked outright.
	var item_dicts: Array[Dictionary] = []
	for item: Variant in items:
		if item is Dictionary:
			item_dicts.append(item as Dictionary)
		else:
			push_warning(
				"CheckoutPanel: dropping non-Dictionary item in checkout_started — got %s"
				% type_string(typeof(item))
			)
	show_checkout(item_dicts)


func _on_confirm_pressed() -> void:
	if _showing_result:
		_dismiss_result()
		return
	if _is_pending:
		return
	_set_pending(true)
	sale_accepted.emit()


func _on_cancel_pressed() -> void:
	if _showing_result:
		_dismiss_result()
		return
	if _is_pending:
		return
	sale_declined.emit()
	if _card_populated:
		show_result("You let them walk. They left frustrated.")


func _on_bundle_pressed() -> void:
	if _showing_result:
		_dismiss_result()
		return
	if _is_pending:
		return
	_bundle_button.disabled = true
	bundle_suggested.emit()


func _on_transaction_completed(
	amount: float, success: bool, message: String
) -> void:
	if not _is_open or not _is_pending:
		return
	_set_pending(false)
	if success:
		if _card_populated:
			show_result(
				"Sold for %s. The customer leaves satisfied." % _format_price(amount)
			)
		else:
			_show_receipt(amount)
	else:
		_show_error(message)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		hide_checkout(true)
		if _is_pending:
			sale_declined.emit()


func _on_receipt_timer_timeout() -> void:
	hide_checkout()


func _on_result_timer_timeout() -> void:
	hide_checkout()


func _dismiss_result() -> void:
	_result_timer.stop()
	hide_checkout()


func _set_pending(pending: bool) -> void:
	_is_pending = pending
	_confirm_button.disabled = pending
	_cancel_button.disabled = pending
	_bundle_button.disabled = pending


func _populate_item_list() -> void:
	_clear_container(_item_list)
	for item: Dictionary in _items:
		var row: HBoxContainer = _create_item_row(item)
		_item_list.add_child(row)


func _create_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = item.get("item_name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var condition_label := Label.new()
	condition_label.text = str(item.get("condition", ""))
	condition_label.custom_minimum_size = Vector2(80, 0)
	condition_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	row.add_child(condition_label)

	var price_label := Label.new()
	var price: float = item.get("price", 0.0)
	price_label.text = _format_price(price)
	price_label.custom_minimum_size = Vector2(70, 0)
	price_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	row.add_child(price_label)
	return row


func _update_totals() -> void:
	_subtotal = 0.0
	for item: Dictionary in _items:
		_subtotal += item.get("price", 0.0)

	_total = _subtotal - _haggle_discount
	if _total < 0.0:
		_total = 0.0

	_subtotal_value.text = _format_price(_subtotal)

	if _haggle_discount > 0.0:
		_discount_row.visible = true
		_discount_value.text = (
			"-%s" % _format_price(_haggle_discount)
		)
		_discount_value.add_theme_color_override(
			"font_color",
			UIThemeConstants.get_positive_color(),
		)
	else:
		_discount_row.visible = false

	_total_value.text = _format_price(_total)


func _show_receipt(amount: float) -> void:
	_showing_receipt = true
	_confirm_button.visible = false
	_cancel_button.visible = false
	_bundle_button.visible = false
	_receipt_section.visible = true
	_clear_container(_receipt_item_list)
	for item: Dictionary in _items:
		var lbl := Label.new()
		lbl.text = "%s — %s" % [
			item.get("item_name", "Unknown"),
			_format_price(item.get("price", 0.0)),
		]
		_receipt_item_list.add_child(lbl)
	_receipt_total_label.text = "Total: %s" % _format_price(
		amount
	)
	var time_dict: Dictionary = (
		Time.get_datetime_dict_from_system()
	)
	_receipt_timestamp_label.text = "%04d-%02d-%02d %02d:%02d" % [
		time_dict.get("year", 0),
		time_dict.get("month", 0),
		time_dict.get("day", 0),
		time_dict.get("hour", 0),
		time_dict.get("minute", 0),
	]
	_receipt_timer.start()


func _show_error(message: String) -> void:
	_error_label.text = (
		message if not message.is_empty() else "Sale failed"
	)
	_error_label.visible = true
	_error_label.add_theme_color_override(
		"font_color", UIThemeConstants.get_negative_color()
	)
	_cancel_button.disabled = false


func _clear_container(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


static func _format_price(amount: float) -> String:
	return "%s%.2f" % [
		UIThemeConstants.CURRENCY_SYMBOL, amount,
	]


func _format_consequence_preview(
	offer: float, sticker: float, rep_delta_str: String
) -> String:
	var delta: float = offer - sticker
	var delta_str: String
	if delta >= 0.0:
		delta_str = "+%s" % _format_price(delta)
	else:
		delta_str = "−%s" % _format_price(absf(delta))
	if absf(delta) < 0.005:
		return "Full price | %s" % rep_delta_str
	return "%s vs ask | %s" % [delta_str, rep_delta_str]


## Sets a button's text to a single label and attaches a small consequence-
## preview Label as a child below it. Both lines are clipped within the button
## footprint so the choice is readable at a glance.
func _set_two_line_button(
	button: Button, primary: String, consequence: String
) -> void:
	button.text = primary
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(0, 56)
	_clear_button_extras(button)
	if consequence.is_empty():
		return
	var consequence_label: Label = Label.new()
	consequence_label.name = "ConsequenceLabel"
	consequence_label.text = consequence
	consequence_label.add_theme_font_size_override(
		"font_size", DecisionCardStyle.FONT_SIZE_CHOICE_CONSEQUENCE
	)
	consequence_label.add_theme_color_override(
		"font_color", DecisionCardStyle.CHOICE_CONSEQUENCE_COLOR
	)
	consequence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	consequence_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	consequence_label.offset_top = -16
	consequence_label.offset_bottom = -2
	consequence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(consequence_label)


func _clear_button_extras(button: Button) -> void:
	var existing: Node = button.get_node_or_null("ConsequenceLabel")
	if existing:
		existing.queue_free()


func _apply_card_style() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = DecisionCardStyle.CARD_ACTIVE_BG_COLOR
	box.border_width_left = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_width_top = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_width_right = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_width_bottom = DecisionCardStyle.CARD_BORDER_WIDTH
	box.border_color = DecisionCardStyle.CARD_BORDER_COLOR
	box.corner_radius_top_left = DecisionCardStyle.CARD_CORNER_RADIUS
	box.corner_radius_top_right = DecisionCardStyle.CARD_CORNER_RADIUS
	box.corner_radius_bottom_left = DecisionCardStyle.CARD_CORNER_RADIUS
	box.corner_radius_bottom_right = DecisionCardStyle.CARD_CORNER_RADIUS
	_panel.add_theme_stylebox_override("panel", box)


func _set_reasoning_text(text: String) -> void:
	# BBCode `[i]` produces italic when an italic font variation is wired into
	# the theme; on the default font, the engine falls back to a synthetic
	# slant. Either way, the hierarchy spec (italic + muted + smaller) is met.
	#
	# §F-129 — `_reasoning_label` has `bbcode_enabled = true`. Today's only
	# callers feed either a constant `_ARCHETYPE_REASONING` lookup or a packed
	# JSON string from the customer-archetype catalog (developer-controlled),
	# so the substituted text is not user-editable. We still escape `[` →
	# `[lb]` so a future caller that wires save-derived or runtime-typed text
	# through this surface cannot inject BBCode tags ([url=...], [color], …)
	# into the rendered label. Round-trip is render-equivalent for the
	# current safe inputs (no `[` characters in any catalog string).
	_reasoning_label.text = "[i]%s[/i]" % text.replace("[", "[lb]")


func _set_panel_active_palette() -> void:
	var sb: StyleBox = _panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = DecisionCardStyle.CARD_ACTIVE_BG_COLOR


func _set_panel_result_palette() -> void:
	var sb: StyleBox = _panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = DecisionCardStyle.CARD_RESULT_BG_COLOR


func _push_modal_focus() -> void:
	if _focus_pushed:
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true


func _pop_modal_focus() -> void:
	if not _focus_pushed:
		return
	# Defensive: if the topmost frame is no longer CTX_MODAL, a sibling pushed
	# without going through this contract. Surface it via push_error AND skip
	# the pop so we don't corrupt someone else's frame.
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"CheckoutPanel.hide_checkout: expected CTX_MODAL on top, "
				+ "got %s — leaving stack untouched to avoid corrupting "
				+ "sibling frame"
			)
			% String(InputFocus.current())
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false


func _on_scene_ready(_target: StringName, _payload: Dictionary) -> void:
	# Modals never survive a scene change. Force-close (popping our frame)
	# before the new scene's gameplay context becomes the audited top of stack.
	if _is_open:
		hide_checkout(true)
		return
	if _focus_pushed:
		_pop_modal_focus()


## Test seam — clears _focus_pushed without calling pop_context. Pair with
## InputFocus._reset_for_tests() so test harnesses that wipe the focus stack
## don't leave the panel believing it still owns a frame.
func _reset_for_tests() -> void:
	_focus_pushed = false

# Issue 008: Implement price setting UI

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-005, issue-006, issue-010

## Why This Matters

Pricing is the core strategic decision (Pillar 2: Player-Driven Business). Every sale's profit margin depends on the price the player sets. The UI must make market value transparent, show the trade-offs (margin vs. turnover vs. reputation), and make adjustment feel satisfying.

## Current State

- `ItemInstance` (issue-005) has a `player_set_price: float` field (default 0.0)
- `pricing_config.json` defines `condition_multipliers`, `rarity_multipliers`, and `markup_ranges`
- Issue-006 emits `EventBus.price_panel_requested(instance_id)` when player clicks "Set Price" on a stocked item
- EconomySystem (issue-010) provides market value calculation

## Design

### Market Value Calculation

The "market value" shown in the price panel uses the **canonical formula from issue-010**:

```
market_value = base_price × condition_multiplier
```

Where `condition_multiplier` comes from `pricing_config.json` (poor=0.25, fair=0.5, good=1.0, near_mint=1.5, mint=2.0).

> **IMPORTANT**: `base_price` in item JSON already encodes the item's rarity-appropriate value. A common card has base_price=$2.50, a rare rookie has base_price=$45, a legendary jersey has base_price=$1,200. The `rarity_multipliers` table in pricing_config.json is used for content generation tooling and future wholesale pricing (issue-025, issue-040) — it is NOT applied to market_value. See issue-010 for the full rationale.

Examples:
- Griffey Jr. Rookie Card: base_price=$45.00, condition=near_mint (1.5×) → market_value = $67.50
- Common Pippen card: base_price=$2.50, condition=good (1.0×) → market_value = $2.50
- Jordan Fleer Rookie: base_price=$450.00, condition=mint (2.0×) → market_value = $900.00

The EconomySystem (issue-010) provides `get_market_value(item_instance) -> float`.

### Price Range

The player can set prices within a bounded range derived from `pricing_config.json` `markup_ranges`:

```json
"markup_ranges": {
  "minimum": 0.25,
  "maximum": 3.0
}
```

- **Minimum price**: `market_value × 0.25` (fire sale, 75% loss)
- **Maximum price**: `market_value × 3.0` (gouging, will hurt reputation)
- **Default price**: `market_value × 1.0` (at market)

This gives the player a meaningful range. A $67.50 market-value item can be priced from $16.88 to $202.50.

### Price Panel UI

Centered modal popup that overlays the game view:

```
PricePanel (PanelContainer, centered, ~400x350px)
  +- VBoxContainer
       +- Header (HBoxContainer)
       |    +- TitleLabel (Label) — "Set Price"
       |    +- CloseButton (TextureButton) — X
       +- ItemInfo (HBoxContainer)
       |    +- RarityDot (ColorRect, rarity color)
       |    +- ItemName (Label) — "Griffey Jr. Rookie Card"
       |    +- ConditionBadge (Label) — "Near Mint"
       +- Separator (HSeparator)
       +- ValueSection (GridContainer, 2 columns)
       |    +- Label "Base Price:"       +- ValueLabel "$45.00"
       |    +- Label "Condition (×1.5):"  +- ValueLabel "$67.50"
       |    +- Label "Market Value:"      +- MarketValueLabel "$67.50" (bold)
       +- Separator (HSeparator)
       +- PriceSlider (HSlider, range: min_price to max_price)
       +- PriceRow (HBoxContainer)
       |    +- Label "Your Price:"
       |    +- PriceInput (SpinBox) — editable, synced with slider
       |    +- MarginLabel (Label) — "+12%" or "-30%" (margin vs market)
       +- FeedbackSection (HBoxContainer)
       |    +- FeedbackIcon (TextureRect) — smiley/neutral/frown
       |    +- FeedbackLabel (Label) — see below
       +- Separator (HSeparator)
       +- ButtonRow (HBoxContainer)
            +- ConfirmButton (Button) — "Set Price"
            +- MarketButton (Button) — "Use Market Price"
            +- CancelButton (Button) — "Cancel"
```

The value breakdown shows two lines (base → condition-adjusted), not three. Rarity is communicated via the RarityDot color indicator and the item's inherently higher base_price, not as a separate multiplier line.

### Pricing Feedback

As the player adjusts the slider, real-time feedback shows the expected customer reaction (based on reputation delta table from issue-018):

| Price Ratio | Feedback Text | Icon |
|---|---|---|
| < 0.70 | "Great deal! Sells fast, builds reputation" | green smiley |
| 0.70–0.90 | "Fair price. Steady sales" | light green |
| 0.90–1.20 | "Market rate. Standard turnover" | neutral |
| 1.20–1.50 | "Above market. Slower sales" | yellow |
| 1.50–2.00 | "Overpriced. May hurt reputation" | orange |
| > 2.00 | "Gouging! Reputation will suffer" | red |

The margin label shows the percentage above/below market (e.g., "+15%" or "-20%").

### Slider Behavior

- `HSlider` with `min_value = market_value * 0.25`, `max_value = market_value * 3.0`
- `step` = 0.25 (quarter-dollar increments) for items under $20, 1.00 for items $20-$100, 5.00 for items over $100
- Slider and SpinBox are bidirectionally synced — changing one updates the other
- A notch/marker on the slider at 1.0× (market value) for visual reference

### Script: `game/scripts/ui/price_panel.gd`

```gdscript
extends PanelContainer

var _current_instance: ItemInstance = null
var _market_value: float = 0.0

func _ready() -> void:
    visible = false
    EventBus.price_panel_requested.connect(_on_price_requested)

func _on_price_requested(instance_id: String) -> void:
    _current_instance = InventorySystem.get_instance(instance_id)
    if _current_instance == null:
        return
    _market_value = EconomySystem.get_market_value(_current_instance)
    _populate()
    visible = true

func _populate() -> void:
    # Set item info labels
    %ItemName.text = _current_instance.definition.item_name
    %ConditionBadge.text = _current_instance.condition.capitalize()
    %MarketValueLabel.text = "$%.2f" % _market_value
    
    # Configure slider
    var min_price = _market_value * 0.25
    var max_price = _market_value * 3.0
    %PriceSlider.min_value = min_price
    %PriceSlider.max_value = max_price
    %PriceSlider.step = _calculate_step(_market_value)
    
    # Set initial value
    var current = _current_instance.player_set_price
    if current <= 0.0:
        current = _market_value  # default to market price
    %PriceSlider.value = clampf(current, min_price, max_price)
    _update_feedback(%PriceSlider.value)

func _on_slider_changed(value: float) -> void:
    %PriceInput.value = value
    _update_feedback(value)

func _on_input_changed(value: float) -> void:
    %PriceSlider.value = value
    _update_feedback(value)

func _update_feedback(price: float) -> void:
    var ratio = price / _market_value if _market_value > 0 else 1.0
    var margin_pct = (ratio - 1.0) * 100.0
    %MarginLabel.text = "%+.0f%%" % margin_pct
    # Update feedback text based on ratio brackets
    # (see feedback table above)

func _on_confirm() -> void:
    _current_instance.player_set_price = %PriceSlider.value
    EventBus.price_set.emit(_current_instance.instance_id, %PriceSlider.value)
    close()

func _on_market_price() -> void:
    %PriceSlider.value = _market_value
    _update_feedback(_market_value)

func close() -> void:
    _current_instance = null
    visible = false
```

### EventBus Signals

Add to `game/autoload/event_bus.gd`:
```gdscript
signal price_set(instance_id: String, price: float)
```

`price_panel_requested` is already specified by issue-006.

### Price Display on Shelf

When `price_set` fires, the ShelfSlot (issue-006) updates its `Label3D` price tag to show the new price. If `player_set_price` is 0.0 (unset), the price tag shows "No Price" and customers skip the item.

### Integration with Customer AI

The customer purchase decision (issue-011) compares `player_set_price` against the customer's willingness-to-pay (derived from market value and price sensitivity). Items with `player_set_price == 0.0` are unsellable — the player must set a price before customers will consider buying.

## Deliverables

- `game/scenes/ui/price_panel.tscn` — Price setting popup scene
- `game/scripts/ui/price_panel.gd` — Price panel script
- Market value breakdown display (base × condition)
- Price slider with SpinBox sync and step scaling
- Real-time feedback text and icon based on price ratio
- Margin percentage display
- "Use Market Price" quick-set button
- EventBus signal: `price_set(instance_id, price)`
- Input map: panel closes on Escape

## Acceptance Criteria

- Interact with stocked item → click "Set Price" → price panel opens
- Panel shows correct market value breakdown (base × condition)
- Griffey Jr. at near_mint shows: Base $45.00 → Condition ×1.5 → Market Value $67.50
- Slider range covers 0.25× to 3.0× market value
- Slider and SpinBox stay in sync bidirectionally
- Feedback text updates in real-time as price changes
- At market price: feedback shows "Market rate. Standard turnover"
- At 2.5× market: feedback shows "Gouging! Reputation will suffer"
- At 0.5× market: feedback shows "Great deal! Sells fast, builds reputation"
- Confirm button saves price to `ItemInstance.player_set_price`
- "Use Market Price" button sets slider to 1.0× market value
- Price tag on shelf (Label3D) updates after confirm
- Cancel or Escape closes panel without saving
- Items without a set price show "No Price" on shelf and are not purchasable
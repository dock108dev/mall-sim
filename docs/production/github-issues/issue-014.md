# Issue 014: Implement end-of-day summary screen

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-009, issue-010, issue-012

## Why This Matters

The day summary is the natural session boundary and the player's scorecard. It's the "one more day" hook — seeing your numbers and knowing tomorrow's shipment is coming. Per PLAYER_EXPERIENCE.md, a satisfying session is 1-3 in-game days, and the summary screen is the designed exit point.

## Current State

No summary screen exists. EconomySystem (issue-010) tracks a daily transaction log with revenue, expenses, and item sales. TimeSystem (issue-009) emits `day_ended(day_number)`. The data sources are ready; this issue builds the display.

## Design

### Data Sources

The summary screen reads from EconomySystem's daily log (populated throughout the day):

| Metric | Source | Format |
|---|---|---|
| Total Revenue | Sum of all sale prices from `item_sold` events | $X,XXX.XX |
| Total Expenses | Rent + any other costs from `expense_deducted` events | $X,XXX.XX |
| Net Profit/Loss | Revenue - Expenses | +$XXX.XX or -$XXX.XX |
| Items Sold | Count of `item_sold` events | N items |
| Customers Served | Count of `customer_left` events where purchased=true | N customers |
| Customers Lost | Count of `customer_left` events where purchased=false | N left empty-handed |
| Best Sale | Highest single sale price | Item name — $XXX.XX |
| Reputation Change | Net reputation delta for the day | +X.X or -X.X |
| Current Reputation | ReputationSystem.get_score() | Tier name (XX.X/100) |

For M1, the EconomySystem daily log structure should provide:
```gdscript
func get_daily_summary() -> Dictionary:
    return {
        "day": current_day,
        "revenue": daily_revenue,
        "expenses": daily_expenses,
        "items_sold": daily_items_sold,  # Array of {item_name, sale_price}
        "customers_served": daily_customers_served,
        "customers_lost": daily_customers_lost
    }
```

### Flow

```
TimeSystem emits day_ended(day_number)
  → GameManager receives signal
  → GameManager sets state to DAY_SUMMARY
  → TimeSystem pauses (speed = 0)
  → DaySummary scene instantiated and shown
  → Player reviews numbers
  → Player clicks "Continue to Next Day"
  → DaySummary emits continue_pressed
  → GameManager resets daily log, starts next day
  → DaySummary freed
```

## Scene Structure

```
DaySummary (Control, full-screen)
  +- BackgroundDim (ColorRect, full-screen, dark semi-transparent)
  +- CenterPanel (PanelContainer, centered, ~500x600px)
       +- VBoxContainer
            +- HeaderLabel (Label) — "Day 7 — Summary"
            +- HSeparator
            +- StatsGrid (GridContainer, 2 columns)
            |    +- "Revenue:"        / "$1,250.00" (green)
            |    +- "Expenses:"       / "-$50.00" (red)
            |    +- "Net Profit:"     / "+$1,200.00" (green or red based on sign)
            |    +- HSeparator (spanning both columns)
            |    +- "Items Sold:"     / "8 items"
            |    +- "Customers:"      / "12 served, 3 left"
            |    +- "Best Sale:"      / "Rookie Card - $675.00"
            +- HSeparator
            +- ReputationSection (HBoxContainer)
            |    +- "Reputation:"     / "Local Favorite (32.5/100) ▲+3.2"
            +- HSeparator
            +- ContinueButton (Button, centered) — "Continue to Day 8"
```

### Visual Treatment

- Revenue in green, expenses in red
- Net profit: green if positive, red if negative
- Reputation change: green arrow ▲ if positive, red arrow ▼ if negative
- "Best Sale" row only shown if at least one item was sold
- Subtle entrance animation: panel slides up or fades in (Tween, 0.3s)
- Continue button has a slight delay before becoming active (~1 second) to prevent accidental skips

### Empty Day Handling

If no sales were made:
- Revenue shows $0.00
- Items Sold shows "0 items"
- Best Sale row is hidden
- A gentle message appears: "Quiet day. Maybe adjust your prices?"

## Script: `game/scripts/ui/day_summary.gd`

```
extends Control

signal continue_pressed

@onready var header_label: Label = %HeaderLabel
@onready var revenue_label: Label = %RevenueLabel
@onready var expenses_label: Label = %ExpensesLabel
@onready var profit_label: Label = %ProfitLabel
@onready var items_sold_label: Label = %ItemsSoldLabel
@onready var customers_label: Label = %CustomersLabel
@onready var best_sale_label: Label = %BestSaleLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var continue_button: Button = %ContinueButton

func populate(summary: Dictionary, reputation_score: float, reputation_tier: String, reputation_delta: float) -> void:
    header_label.text = "Day %d — Summary" % summary.day
    revenue_label.text = "$%s" % format_cash(summary.revenue)
    expenses_label.text = "-$%s" % format_cash(summary.expenses)
    
    var net = summary.revenue - summary.expenses
    profit_label.text = "%s$%s" % ["+" if net >= 0 else "-", format_cash(absf(net))]
    profit_label.modulate = Color.GREEN if net >= 0 else Color.RED
    
    items_sold_label.text = "%d items" % summary.items_sold.size()
    customers_label.text = "%d served, %d left" % [summary.customers_served, summary.customers_lost]
    
    # Best sale
    if summary.items_sold.size() > 0:
        var best = summary.items_sold.reduce(func(a, b): return a if a.sale_price > b.sale_price else b)
        best_sale_label.text = "%s — $%s" % [best.item_name, format_cash(best.sale_price)]
        best_sale_label.visible = true
    else:
        best_sale_label.visible = false
    
    # Reputation
    var arrow = "▲" if reputation_delta >= 0 else "▼"
    reputation_label.text = "%s (%.1f/100) %s%+.1f" % [reputation_tier, reputation_score, arrow, reputation_delta]
    
    # Delay continue button
    continue_button.disabled = true
    await get_tree().create_timer(1.0).timeout
    continue_button.disabled = false

func _on_continue_button_pressed() -> void:
    continue_pressed.emit()
```

## Integration with GameManager

GameManager handles the lifecycle:
1. Receives `day_ended` signal from TimeSystem
2. Sets game state to `DAY_SUMMARY`
3. Instantiates DaySummary scene, adds to UI layer
4. Calls `populate()` with data from EconomySystem and ReputationSystem
5. Connects to `continue_pressed` signal
6. On continue: removes DaySummary, resets daily log, calls `TimeSystem.start_new_day()`

## Deliverables

- `game/scenes/ui/day_summary.tscn` — full-screen summary overlay scene
- `game/scripts/ui/day_summary.gd` — summary script with data population and continue flow
- Stats display: revenue, expenses, net profit, items sold, customers, best sale, reputation
- Color coding: green for positive, red for negative values
- Continue button with 1-second activation delay
- Integration point: GameManager instantiates on `day_ended`, removes on continue
- `EconomySystem.get_daily_summary()` method (coordinate with issue-010)

## Acceptance Criteria

- Day ends: summary appears automatically as full-screen overlay
- Revenue, expenses, and net profit are accurate (match actual day's transactions)
- Items sold count matches actual sales
- Customers served/lost counts are accurate
- Best sale shows the highest single sale (hidden if no sales)
- Net profit is green when positive, red when negative
- Reputation shows current tier, score, and day's delta with directional arrow
- Continue button starts the next day
- Game time is paused while summary is showing
- Cannot interact with store while summary is up (input captured by overlay)
- Continue button has ~1 second delay before becoming clickable
- Empty day shows appropriate message and $0 values
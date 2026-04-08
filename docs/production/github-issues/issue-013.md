# Issue 013: Implement HUD with cash, time, and day display

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-009, issue-010

## Why This Matters

Players need constant, glanceable feedback on their most important metrics: how much money they have, what time it is, and what day they're on. The HUD is always visible during gameplay.

## Current State

No HUD exists. EventBus already declares `money_changed`, `day_started`, and `hour_changed` signals (issue-009 and issue-010 will emit these). The interaction prompt system from issue-003 needs a place to display — the HUD provides that.

## Design

The HUD is a `CanvasLayer` that floats above the 3D game world. It shows:
- **Top-left**: Cash balance, store name
- **Top-right**: Day number, current time, time speed indicator
- **Bottom-center**: Interaction prompt (managed by issue-003's raycast system)
- **Top-center** (optional): Reputation tier badge

All elements use readable fonts (16px+ equivalent at 1080p), high contrast, and avoid obscuring the center of the store view.

## Scene Structure

```
HUD (CanvasLayer, layer 10)
  +- TopBar (HBoxContainer, anchored top, full width)
  |    +- LeftSection (VBoxContainer, left-aligned)
  |    |    +- CashLabel (Label) — "$1,250.00"
  |    |    +- StoreNameLabel (Label) — "My Sports Shop" (smaller, dimmer)
  |    +- CenterSection (VBoxContainer, center-aligned)
  |    |    +- ReputationLabel (Label) — "Local Favorite" (tier name)
  |    +- RightSection (VBoxContainer, right-aligned)
  |         +- DayLabel (Label) — "Day 7"
  |         +- TimeLabel (Label) — "12:00 PM"
  |         +- SpeedLabel (Label) — ">>" or "▶" or "||" (speed indicator)
  +- BottomCenter (MarginContainer, anchored bottom-center)
  |    +- PromptPanel (PanelContainer, semi-transparent background)
  |         +- PromptLabel (Label) — "Press E to Stock Shelf"
  +- NotificationArea (VBoxContainer, anchored top-center, below TopBar)
       +- (transient notifications slide in/out here)
```

## Script: `game/scripts/ui/hud.gd`

```
extends CanvasLayer

@onready var cash_label: Label = %CashLabel
@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var prompt_label: Label = %PromptLabel
@onready var prompt_panel: PanelContainer = %PromptPanel

func _ready() -> void:
    EventBus.money_changed.connect(_on_money_changed)
    EventBus.day_started.connect(_on_day_started)
    EventBus.hour_changed.connect(_on_hour_changed)
    EventBus.reputation_changed.connect(_on_reputation_changed)
    EventBus.time_speed_changed.connect(_on_time_speed_changed)
    prompt_panel.visible = false

func _on_money_changed(old_amount: float, new_amount: float) -> void:
    cash_label.text = "$%s" % format_cash(new_amount)
    # Flash green if increased, red if decreased

func _on_day_started(day_number: int) -> void:
    day_label.text = "Day %d" % day_number

func _on_hour_changed(hour: int) -> void:
    # Convert 24h to 12h format
    var period = "AM" if hour < 12 else "PM"
    var display_hour = hour % 12
    if display_hour == 0: display_hour = 12
    time_label.text = "%d:00 %s" % [display_hour, period]

func _on_time_speed_changed(speed: float) -> void:
    match speed:
        0.0: speed_label.text = "||"   # paused
        1.0: speed_label.text = "▶"
        2.0: speed_label.text = "▶▶"
        4.0: speed_label.text = "▶▶▶"

func show_prompt(text: String) -> void:
    prompt_label.text = text
    prompt_panel.visible = true

func hide_prompt() -> void:
    prompt_panel.visible = false

func format_cash(amount: float) -> String:
    # Format as X,XXX.XX with comma separators
    var whole = int(amount)
    var cents = int((amount - whole) * 100)
    # Add comma separators for thousands
    var whole_str = str(whole)
    # Insert commas from right
    var formatted = ""
    for i in range(whole_str.length()):
        if i > 0 and (whole_str.length() - i) % 3 == 0:
            formatted += ","
        formatted += whole_str[i]
    return "%s.%02d" % [formatted, cents]
```

## Interaction Prompt Integration

The interaction controller (issue-003) calls `HUD.show_prompt()` and `HUD.hide_prompt()` instead of managing its own label. The HUD owns the prompt display; the player controller tells it what to show.

Approach: The player controller accesses HUD via `get_tree().get_first_node_in_group("hud")` or the HUD is referenced through the GameWorld scene tree. The HUD adds itself to the `"hud"` group in `_ready()`.

## Cash Flash Effect

When cash changes, briefly tint the cash label:
- Green flash on increase (sale)
- Red flash on decrease (expense/rent)
- Use a `Tween` to animate `modulate` from green/red back to white over 0.5 seconds

## Speed Indicator Behavior

The speed label reflects the current TimeSystem speed. The player can change speed with keyboard shortcuts (1-4 keys, defined in issue-009). The HUD just displays the current state via `time_speed_changed` signal.

## EventBus Signals Required

These signals must exist on EventBus (some added by other issues):
- `money_changed(old_amount: float, new_amount: float)` — from issue-010
- `day_started(day_number: int)` — from issue-009
- `hour_changed(hour: int)` — from issue-009
- `reputation_changed(old_value: float, new_value: float)` — from issue-018
- `time_speed_changed(speed: float)` — from issue-009 (needs to be added if not declared)

## Deliverables

- `game/scenes/ui/hud.tscn` — HUD CanvasLayer scene
- `game/scripts/ui/hud.gd` — HUD script with signal connections and formatting
- Top-left: cash display with $X,XXX.XX formatting and color flash on change
- Top-right: day number, time (12h format), speed indicator
- Bottom-center: interaction prompt (show/hide API for issue-003)
- Signal connections to EventBus for real-time updates

## Acceptance Criteria

- Cash label updates immediately when money_changed fires, formatted as $X,XXX.XX
- Cash flashes green on increase, red on decrease
- Day label updates on day_started
- Time label updates every in-game hour in 12-hour format (e.g., "2:00 PM")
- Speed indicator reflects current time speed (paused, 1x, 2x, 4x)
- Interaction prompt appears/disappears when player aims at/away from interactables
- HUD elements are readable at 1080p (16px+ font)
- HUD does not obscure the center of the screen
- All labels have correct initial values on game start (Day 1, $500.00, 8:00 AM)
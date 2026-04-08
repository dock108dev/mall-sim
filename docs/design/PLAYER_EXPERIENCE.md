# Player Experience

This document covers the first-time experience, ongoing satisfaction design, and desktop-first UX considerations.

---

## First 10 Minutes (New Player)

The game needs to earn the player's attention in the first session. Here's the intended flow:

1. **Title screen**: Mall exterior at golden hour, gentle music, "New Game" prominent
2. **Store selection**: Player picks their first store type from a visual menu. Each option shows a brief preview and one-sentence pitch. No wrong choice -- all are viable starting points.
3. **Naming**: Name your store. A sign appears above the door.
4. **The empty store**: Player walks into a bare retail space. Shelves are empty. A delivery crate sits on the floor with starter inventory.
5. **Guided first stock**: Prompted to open the crate and place items on shelves. This teaches inventory -> shelf flow.
6. **Set first prices**: Prompted to price a few items. Shown market value as reference. This teaches the pricing UI.
7. **Open for business**: Flip the OPEN sign. First customers arrive. Watch your first sale happen.
8. **Day ends**: Summary screen shows revenue. Prompted to order new stock for tomorrow.
9. **Day 2 begins**: Player is now self-directed. Contextual hints appear for new mechanics as they become relevant.

Total guided time: ~5 minutes. After that, the player has all the basics and can explore.

## Tutorial Philosophy

- **Show, don't tell**: Prefer contextual prompts over text dumps
- **One concept at a time**: Never introduce two systems simultaneously
- **Let the player fail safely**: If they overprice everything and sell nothing on day 1, that's a lesson, not a game over
- **Dismissable**: Every tutorial prompt can be skipped or disabled entirely
- **No tutorial jail**: After the first-stock sequence, the player is free to explore everything

## Progression Curve

### Early Game (Days 1-10)
- Learning the basics of stocking, pricing, and selling
- Small inventory, limited shelf space
- Earning enough to keep the lights on
- Unlocking first supplier tier upgrade
- Satisfaction source: "I made money! My store has stuff in it!"

### Mid Game (Days 11-30)
- Expanding floor space, adding display cases
- Learning condition grading and rarity mechanics
- Building reputation to attract better customers
- Encountering rare items for the first time
- Satisfaction source: "I found something valuable and knew what to do with it"

### Late Game (Days 30+)
- Opening a second store type
- Mastering the economy (buy low, sell at the right time)
- Pursuing collection milestones
- Hosting events, building community reputation
- Satisfaction source: "I run a retail empire and my stores are exactly how I want them"

## Satisfaction Moments

These are the "feels good" moments the game should deliver regularly:

- **The ka-ching**: Register sound and money animation on every sale
- **The restock**: Filling an empty shelf with fresh product, items snapping into place
- **The rare find**: Opening a shipment and discovering a high-value item
- **The busy day**: Store full of customers, register ringing constantly
- **The milestone**: Reaching a new reputation tier, daily revenue record, collection complete
- **The upgrade**: Placing a new display case, expanding into adjacent space
- **The expertise**: Recognizing an undervalued item before buying it, outsmarting the market

## Desktop-First UX

mallcore-sim is designed for mouse and keyboard at a desk. No mobile, no controller (for now).

### Mouse Interaction
- **Left click**: Select, interact, place items
- **Right click**: Context menu (price item, move to backroom, inspect details)
- **Scroll wheel**: Zoom in/out in 3D view
- **Click and drag**: Move items between shelves, rearrange displays
- **Hover**: Tooltip with item info, customer mood indicator

### Keyboard Shortcuts
- `Space`: Pause / resume time
- `1-4`: Time speed (1x, 2x, 4x, pause)
- `Tab`: Toggle between store view and management UI
- `I`: Open inventory panel
- `P`: Open pricing panel
- `C`: Open catalog / ordering
- `Esc`: Close current panel / open pause menu
- `F1`: Toggle debug overlay (dev builds)

### UI Principles
- Readable at arm's length (desk distance, ~24 inches from a monitor)
- Minimum font size: 14px equivalent at 1080p
- High contrast between interactive and decorative elements
- Panels dock to screen edges, never obscure the center of the store
- No tiny icons without text labels
- Color coding for item rarity and condition, but never color-only (always paired with text or icon shape)

### Window Behavior
- Default resolution: 1920x1080 windowed
- Resizable with sensible minimum (1280x720)
- UI scales proportionally
- Fullscreen toggle via settings or F11
- Game pauses automatically on alt-tab / focus loss (configurable)

## Session Design

- A satisfying session is 15-30 minutes (1-3 in-game days)
- The end-of-day summary is a natural exit point
- Auto-save at day boundaries means the player never loses progress
- "One more day" hook: the ordering screen shows tomorrow's incoming shipment, teasing what's next

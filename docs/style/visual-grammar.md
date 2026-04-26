# Visual Grammar — Mallcore Sim

Canonical token reference for the 2000s-era mall palette. All color decisions in UI code should trace back to these tokens. Runtime access is through `UIThemeConstants` (`game/scripts/ui/ui_theme_constants.gd`). The Godot Theme resource at `game/themes/palette.tres` stores the same values for editor-side theme assignment.

---

## Base Tokens

Nine tokens form the shared neutral chrome used across all screens. They never change per store.

| Token | Hex | Color() | Use |
|---|---|---|---|
| `world_base` | `#13100D` | `Color(0.075, 0.063, 0.051)` | Deepest background; hallway floor, outer void |
| `panel_surface` | `#1F1A16` | `Color(0.122, 0.102, 0.086)` | Drawer body, HUD bars, card backgrounds |
| `panel_raised` | `#2E2722` | `Color(0.180, 0.153, 0.133)` | Buttons, list rows, inner cards |
| `text_primary` | `#F4E9D4` | `Color(0.957, 0.914, 0.831)` | All body copy; 15.1:1 vs panel_surface (AAA) |
| `text_muted` | `#B8A88C` | `Color(0.722, 0.659, 0.549)` | Labels, metadata, disabled hint text |
| `accent_interact` | `#5BB8E8` | `Color(0.357, 0.722, 0.910)` | Interactive affordances, objective rail, info hints |
| `accent_success` | `#6DCF5A` | `Color(0.427, 0.812, 0.353)` | Profitable close, completed objective, positive delta |
| `accent_warning` | `#F2B81C` | `Color(0.949, 0.722, 0.110)` | Low stock, pending action, soft alert |
| `accent_danger` | `#E53E2B` | `Color(0.898, 0.243, 0.169)` | Failed sale, boot validation error, critical alert |

`text_primary` on `panel_surface`: **15.1:1** contrast (WCAG AAA).

---

## Store Accent Tokens

Each store has one primary accent. The accent appears as a **4px header band**, **selection outline**, and **primary CTA button fill** within that store's drawer only. It never bleeds into global HUD chrome.

All primaries are verified ≥ 4.5:1 (WCAG AA) against `panel_surface`. All pairs have hue delta > 20° on the HSL wheel.

| Store | Name | Hex | Color() | HSL Hue | Contrast vs `panel_surface` |
|---|---|---|---|---|---|
| `retro_games` | CRT Amber | `#E8A547` | `Color(0.910, 0.647, 0.278)` | 35° | 8.1:1 ✓ AAA |
| `pocket_creatures` | Holo Teal | `#2EB5A8` | `Color(0.180, 0.710, 0.659)` | 174° | 6.8:1 ✓ AAA |
| `video_rental` | Late-Fee Magenta | `#E04E8C` | `Color(0.878, 0.306, 0.549)` | 335° | 4.6:1 ✓ AA |
| `electronics` | CRT Cyan | `#3AA8D8` | `Color(0.227, 0.659, 0.847)` | 198° | 6.4:1 ✓ AAA |
| `sports_cards` | Grading Crimson | `#E85555` | `Color(0.910, 0.333, 0.333)` | 0° | 4.8:1 ✓ AA |

### Hue separation matrix (all pairs > 20°)

| | retro (35°) | pocket (174°) | video (335°) | electronics (198°) | sports (0°) |
|---|---|---|---|---|---|
| **retro** | — | 139° | 60° | 163° | 35° |
| **pocket** | 139° | — | 161° | 24° | 174° |
| **video** | 60° | 161° | — | 137° | 25° |
| **electronics** | 163° | 24° | 137° | — | 162° |
| **sports** | 35° | 174° | 25° | 162° | — |

---

## Application Rules

1. **Accent = band + outline + CTA only.** Never use a store accent as a panel body fill, global HUD color, or body text color.
2. **Semantic colors outrank store accents.** Inside any store drawer, `accent_danger` / `accent_warning` / `accent_success` override the store accent for status communication.
3. **Inactive accent**: each store has a dark, desaturated variant (see `STORE_ACCENTS_INACTIVE` in `UIThemeConstants`) used in the hub when that store's card is not focused.
4. **Color-blind safety**: accent is never the sole signal channel. Every color-coded element also carries a glyph or label (e.g., `✓ Success`, store icon + name).
5. **No accent-on-accent**: cross-store views (daily summary, hub overview) use neutral chrome with an 8px left border in the store's accent. Never tint row backgrounds.

---

## Typography Scale

Font sizes are defined in `game/themes/mallcore_theme.tres` and mirrored in `UIThemeConstants`. Use the named theme types in scenes; reference the constants in code.

| Token | Theme Type | `UIThemeConstants` constant | Size | Usage |
|---|---|---|---|---|
| `h1` | `TitleLabel` | `FONT_SIZE_H1` | 32px | Screen titles (main menu, day summary header) |
| `h2` | `HeaderLabel` | `FONT_SIZE_H2` | 24px | Section headers (store name, panel titles) |
| `body` | `Label` (default) | `FONT_SIZE_BODY` | 18px | All readable body copy — minimum for sustained text |
| `caption` | `CaptionLabel` | `FONT_SIZE_CAPTION` | 14px | Timestamps, footnotes, tooltip secondary lines |

Body minimum is 18px. Do not use 14px caption for any text the player must read to make a decision.

---

## Interactable States

Every interactable element (store card, shelf slot, button, register) must express all five states listed below. Color alone is never the sole signal: every state also has a shape or layout change.

| State | Fill | Border | Label color | Other |
|---|---|---|---|---|
| **Idle** | `panel_raised` | none | `text_muted` | No glow. Element present but not calling for attention. |
| **Hover** | `panel_raised` (unchanged) | 1px `accent_interact` outline | `text_primary` | Cursor changes to pointing hand. Input hint appears inline (e.g. `[E] Enter`). |
| **Active / Selected** | `panel_raised` + slight lighten (+10% L) | 4px left band in store accent or `accent_interact` | `text_primary` | Indicates the currently focused/selected element. Persists until another element is selected. |
| **Disabled** | `panel_surface` | none | `text_muted` at 50% alpha | No hover response. No input hint. Use a tooltip explaining why if the block is non-obvious. |
| **Warning** | `panel_raised` | 1px `accent_warning` outline | `text_primary` | Prefix label with warning icon (`!`). Used for low-stock shelf slots, overdue tasks, near-bankruptcy HUD. |

Danger state is a sub-variant of Warning with `accent_danger` border and `✕` icon prefix. It signals an unrecoverable or immediately actionable alert (failed transaction, boot error).

### Mockup reference

```
┌──────────────────────────────────┐
│  IDLE       │ text_muted label   │  ← panel_raised, no border
├──────────────────────────────────┤
│▌ HOVER      │ text_primary label │  ← accent_interact 1px outline
├──────────────────────────────────┤
│▌ ACTIVE     │ text_primary label │  ← 4px left band (store accent)
├──────────────────────────────────┤
│  DISABLED   │ muted 50% label    │  ← panel_surface, no border
├──────────────────────────────────┤
│! WARNING    │ text_primary label │  ← accent_warning 1px outline + icon
└──────────────────────────────────┘
```

Screenshots are not committed to the repository; run the game and open the audit overlay (`F3`) to inspect live state rendering.

---

## References

- Runtime constants: `game/scripts/ui/ui_theme_constants.gd`
- Global theme: `game/themes/mallcore_theme.tres` (set as project-wide default in `project.godot`)
- Palette token resource: `game/themes/palette.tres`
- Store accent resources: `game/themes/store_accent_*.tres`
- Contrast verification: `tests/gut/test_palette_contrast.gd`

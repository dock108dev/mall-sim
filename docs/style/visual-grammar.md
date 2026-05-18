# Visual Grammar

This is the current code-grounded UI token reference. Runtime constants live in
`game/scripts/ui/ui_theme_constants.gd`; `project.godot` sets the project
theme to `res://game/themes/game_theme.tres`.

## Panel Tiers

| Constant | Color |
| --- | --- |
| `DARK_PANEL_FILL` | `Color(0.122, 0.102, 0.086, 0.96)` |
| `DARK_PANEL_BORDER` | `Color(0.239, 0.188, 0.157, 0.9)` |
| `DARK_PANEL_TEXT` | `Color(0.957, 0.914, 0.831, 1.0)` |
| `DARK_PANEL_TEXT_SECONDARY` | `Color(0.722, 0.659, 0.549, 1.0)` |
| `DARK_PANEL_FILL_OVERLAY` | `Color(0.122, 0.102, 0.086, 0.88)` |
| `LIGHT_PANEL_FILL` | `Color(0.961, 0.925, 0.839, 1.0)` |
| `LIGHT_PANEL_BORDER` | `Color(0.420, 0.306, 0.180, 0.9)` |
| `LIGHT_PANEL_TEXT` | `Color(0.169, 0.114, 0.071, 1.0)` |
| `LIGHT_PANEL_TEXT_SECONDARY` | `Color(0.420, 0.306, 0.180, 1.0)` |

The source file comments document contrast for the dark and light panel tiers.

## Store Accent

`UIThemeConstants.STORE_ACCENTS` currently contains one active store key:

| Store id | Constant | Color |
| --- | --- | --- |
| `retro_games` | `STORE_ACCENT_RETRO_GAMES` | `Color(0.910, 0.647, 0.278, 1.0)` |

`STORE_ACCENTS_INACTIVE` currently contains the same key with
`Color(0.247, 0.196, 0.133, 1.0)`.

## Semantic Colors

| Constant | Color | Icon constant |
| --- | --- | --- |
| `SEMANTIC_SUCCESS` | `Color(0.427, 0.812, 0.353, 1.0)` | `SEMANTIC_ICON_SUCCESS` |
| `SEMANTIC_WARNING` | `Color(0.949, 0.722, 0.110, 1.0)` | `SEMANTIC_ICON_WARNING` |
| `SEMANTIC_ERROR` | `Color(0.898, 0.243, 0.169, 1.0)` | `SEMANTIC_ICON_ERROR` |
| `SEMANTIC_INFO` | `Color(0.357, 0.722, 0.910, 1.0)` | `SEMANTIC_ICON_INFO` |
| `SEMANTIC_CRITICAL` | `Color(1.0, 0.176, 0.310, 1.0)` | `SEMANTIC_ICON_CRITICAL` |
| `SEMANTIC_MONEY_GAIN` | `Color(0.561, 0.878, 0.459, 1.0)` | n/a |
| `SEMANTIC_MONEY_COST` | `Color(1.0, 0.706, 0.659, 1.0)` | n/a |

`SEMANTIC_STATES` duplicates the success, warning, error, info, and critical
colors with an icon, label, and hex string for descriptor-style lookups.

## Colorblind Mode

`UIThemeConstants` exposes deuteranopia-friendly alternates:

- `RARITY_COLORS_CB`
- `POSITIVE_COLOR_CB`
- `NEGATIVE_COLOR_CB`
- `WARNING_COLOR_CB`

`get_rarity_color()`, `get_positive_color()`, `get_negative_color()`, and
`get_warning_color()` select these alternates when
`Settings.colorblind_mode` is enabled.

## Typography

| Constant | Size |
| --- | --- |
| `FONT_SIZE_CAPTION` | `14` |
| `FONT_SIZE_BODY` | `18` |
| `FONT_SIZE_H2` | `24` |
| `FONT_SIZE_H1` | `32` |

`TRACKING_PRIMARY` is `80`; `TRACKING_BODY` is `40`.

## References

- Runtime constants: `game/scripts/ui/ui_theme_constants.gd`
- Project theme: `game/themes/game_theme.tres`
- Palette token resource: `game/themes/palette.tres`
- Active store accent resource: `game/themes/store_accent_retro_games.tres`

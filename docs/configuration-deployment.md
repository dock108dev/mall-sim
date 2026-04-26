# Configuration and Deployment

## Project configuration

Key current settings in `project.godot`:

- application name: `Mallcore Sim`
- description: `A retail simulator inspired by 2000s mall and store culture.`
- version: `0.1.0`
- main scene: `res://game/scenes/bootstrap/boot.tscn`
- project features: `4.6` with `Forward Plus`
- icon: `res://icon.svg`
- custom theme: `res://game/themes/mallcore_theme.tres`
- translations: English and Spanish translation resources
- enabled editor plugin: `res://addons/gut/plugin.cfg`

The autoload list is documented in [Architecture](architecture.md).

## Input and runtime settings

`project.godot` currently defines action groups for:

- movement and interaction
- debug toggle
- inventory, orders, staff, and pricing panel toggles
- camera orbit, pan, and zoom
- build mode toggle and fixture rotation
- time speed changes and pause

Use `project.godot` as the source of truth for exact bindings.

## User data and persistence

Runtime persistence uses Godot `user://` paths:

- settings: `user://settings.cfg` (owned by `Settings` autoload —
  `game/autoload/settings.gd`)
- save index: `user://save_index.cfg`
- saves: `user://save_slot_<n>.json`

`SaveManager` (`game/scripts/core/save_manager.gd`) currently:

- supports one auto-save slot (slot `0`) plus three manual slots
  (`MAX_MANUAL_SLOTS = 3`)
- caps save-file reads at `10 MiB` (`MAX_SAVE_FILE_BYTES = 10485760`)
- writes save files atomically by writing to a `.tmp` companion file,
  flushing, closing, and renaming over the destination

## Checked-in integrations

The checked-in integrations documented in this repository are:

- Godot editor/runtime through `project.godot`
- GUT through `addons/gut/` and `.gutconfig.json`
- helper scripts in `scripts/` for import and Godot execution
- GitHub Actions workflows for validation and tagged exports
- `gdtoolkit` linting in CI

## Export presets

`export_presets.cfg` currently defines:

| Preset | Export path in preset | Notes |
| --- | --- | --- |
| `Windows Desktop` | `exports/windows/MallcoreSim.exe` | x86_64, embedded PCK, built-in code signing disabled. |
| `macOS` | `exports/macos/MallcoreSim.zip` | universal architecture, minimum macOS `10.15`, built-in code signing disabled. |
| `Linux/X11` | `exports/linux/MallcoreSim.x86_64` | Linux desktop preset checked in for local export use. |

All current presets exclude `.aidlc`, `docs`, `tests`, `game/tests`,
`addons/gut`, `game/addons/gut`, `.godot`, Markdown, text files, `.gitignore`,
and `.gutconfig.json` from export payloads.

## Local export

From the editor:

1. Open `project.godot`.
2. Confirm export templates are installed for your Godot version.
3. Open **Project -> Export**.
4. Select the target preset.
5. Export a release build.

For command-line export, import assets first with:

```bash
bash scripts/godot_import.sh
```

Then use Godot's `--export-release` with the preset name.

## GitHub Actions workflows

### Validation workflow

`.github/workflows/validate.yml` runs on pushes and pull requests to `main`
and currently includes:

1. `lint-docs` - required-file checks (`project.godot`, `README.md`, `LICENSE`,
   `docs/architecture.md`) and repository-shape checks (no committed
   `.DS_Store`).
2. `gut-tests` - Godot install, import, and headless GUT execution.
3. `interaction-audit` - headless audit run that regenerates the daily audit
   summary under `docs/audits/`.
4. `content-originality` - banned-term check for real brands and trademarks.
5. `lint-gdscript` - `gdlint` via `gdtoolkit`.

### Export workflow

`.github/workflows/export.yml` runs on tags matching `v*` and currently:

1. validates `export_presets.cfg` (preset names, x86_64 Windows, no
   hardcoded code-signing identity, no absolute export paths, no obvious
   secrets, ETC2 ASTC import support in `project.godot`)
2. installs Godot plus export templates via `chickensoft-games/setup-godot@v2`
3. imports project assets
4. exports Windows, macOS, and Linux release artifacts in parallel jobs
5. uploads short-retention build artifacts
   (`mallcore-sim-{windows,macos,linux}.{zip,zip,tar.gz}`)
6. creates a GitHub release from those tagged artifacts

## Godot version

`project.godot` declares Godot `4.6` features. Both `validate.yml` and
`export.yml` install Godot `4.6.2-stable`. Use that version for local builds
and tests to match CI.

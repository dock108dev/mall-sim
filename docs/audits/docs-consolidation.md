# Documentation Consolidation Pass — 2026-05-06

Working-tree-driven documentation review. Goal: every active-doc statement is
verifiable from current code, config, or CI; nothing else exists.

Scope: `README.md` plus everything under `docs/` (excluding `docs/audits/`,
which is point-in-time review notes that are not rewritten by this pass).
`BRAINDUMP.md` was not touched (customer voice).

## Summary

The active doc set was largely accurate. Three concrete factual bugs were
fixed and one stale index entry was generalized so it stops drifting between
passes. No files were added or deleted.

## Edits applied

### `README.md`

- **Removed broken link** `[Roadmap](docs/roadmap.md)`. The target file does
  not exist in the repository (verified: no `docs/roadmap.md`, no
  root-level `ROADMAP.md`). The link would 404 from GitHub. No replacement
  doc was created — per the pass rules ("No placeholder docs — every file
  earns its existence"), and per the active-docs boundary in
  `docs/contributing.md` ("keep roadmap or planning language out of the
  active docs set").

### `docs/index.md`

- **Removed broken link** `[Roadmap](roadmap.md)` for the same reason.
- **Generalized two audit-folder descriptions** that named contents which no
  longer match the files on disk:
  - `ssot-report.md` previously said it covered "FP store entry + named
    physics layers + bit-5 interaction-mask migration + Day-1 readiness
    v2." The current report is about the Day-1 close-day SSOT
    consolidation. Index now says the file's content is rewritten each
    pass — true for any point-in-time SSOT report.
  - `cleanup-report.md` previously said "dead-code removal and
    citation-consistency sweep across the audit reports." The current
    report describes a different cleanup surface (sibling to the SSOT /
    error-handling / security passes). Index now states the file is
    rewritten each pass.

### `docs/architecture/ownership.md`

- **Fixed CameraAuthority API name** in row 4. The doc claimed cameras
  "request `make_current(self)` through this singleton." That is not the
  public API. `game/autoload/camera_authority.gd:27` exposes
  `request_current(cam, source) -> bool`; `_make_current` is a private
  helper at line 108. The cell now describes:
  - the actual public entry (`request_current(cam, source)`),
  - the `cameras` group auto-add behaviour (`_register_in_group`,
    `camera_authority.gd:93`), and
  - `assert_single_active()` walking that group on every `store_ready`
    (`camera_authority.gd:63`) — replacing the prior "asserts exactly one
    `current == true`" phrasing, which conflated the C++ Camera3D `current`
    property with the autoload's tracking field.

### `docs/configuration-deployment.md`

- **Added missing input action** `quick_stock` (Q) to the input action group
  list. `project.godot` defines the action at line 132–136 and
  `game/scripts/player/store_player_body.gd` uses it as the shelf-restock
  shortcut. The list previously skipped it.

## Statements verified, no edit needed

The following claim-heavy sections were spot-checked against current source
and confirmed accurate at this point in time. Citations are sample
verifications, not exhaustive.

- **Boot flow** in `docs/architecture.md` — matches
  `game/scripts/core/boot.gd`. The wrapping pair
  (`game/scenes/bootstrap/boot.gd` extending `res://game/scripts/core/boot.gd`)
  exists.
- **GameWorld init tiers 1–5** — function names and per-tier system list
  match `game/scenes/world/game_world.gd` (tier functions at lines 272, 283,
  311, 378, 402).
- **Autoload roster (43 entries)** — matches `project.godot:24-68`. Five
  entries are `.tscn` scenes (`ObjectiveRail`, `InteractionPrompt`,
  `MorningNotePanel`, `MiddayEventCard`, `FailCard`); the rest are scripts.
- **`AudioManager` instantiates `AudioEventHandler` as a child node** —
  matches `audio_manager.gd` `_setup_event_handler()`.
- **`GameManager.State` enum** — `MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER,
  LOADING, DAY_SUMMARY, BUILD, MALL_OVERVIEW, STORE_VIEW`, exact match.
- **`EventLog.queue_free`s itself in release builds** — `event_log.gd:28-32`
  (`if not OS.is_debug_build(): queue_free(); return`).
- **`SceneRouter` is the sole `change_scene_to_*` caller** — grep across
  `game/` finds only `scene_router.gd:84` and `scene_router.gd:103`.
- **`StoreDirector` state machine `IDLE → REQUESTED → LOADING_SCENE →
  INSTANTIATING → VERIFYING → READY/FAILED`** — matches
  `store_director.gd:34-42`.
- **`InputFocus` constants** `CTX_MAIN_MENU`, `CTX_MALL_HUB`,
  `CTX_STORE_GAMEPLAY`, `CTX_MODAL` — matches `input_focus.gd:18-21`.
- **`AuditLog.pass_check` / `fail_check` signatures** — match
  `audit_log.gd:21,39`.
- **EventBus mirror signals** `store_ready`, `store_failed`, `scene_ready`
  (single-arg mirror), `run_state_changed`, `input_focus_changed`,
  `camera_authority_changed`, `panel_opened`, `panel_closed` — all present
  in `event_bus.gd`.
- **DataLoader / ContentRegistry surface** in `docs/content-data.md` —
  `MAX_JSON_FILE_BYTES = 1048576`, `_TYPE_ROUTES` covers every documented
  `entries:<kind>`, singleton, and `ignore` route, ID regex
  `^[a-z][a-z0-9_]{0,63}$`, all 25 documented `get_all_*` / `get_*_config`
  getters exist on `data_loader.gd`.
- **Content tree** — every documented subdirectory and root-level JSON file
  (`audio_registry.json`, `day_beats.json`, `fixtures.json`,
  `haggle_dialogue.json`, `market_trends_catalog.json`, `meta_shifts.json`,
  `objectives.json`, `platforms.json`, `pocket_creatures_cards.json`,
  `tutorial_contexts.json`, `upgrades.json`) is present;
  `game/content/localization/` exists and is empty.
- **Store roster + aliases** in `store_definitions.json` — `sports`
  (`sports_memorabilia`), `retro_games`, `rentals` (`video_rental`),
  `pocket_creatures`, `electronics` (`consumer_electronics`); display
  names match `docs/design.md` §4.
- **`SaveManager`** — `MAX_MANUAL_SLOTS = 3`,
  `MAX_SAVE_FILE_BYTES = 10485760`, atomic `.tmp` + rename writes, all in
  `save_manager.gd`.
- **`Settings` autoload owns `user://settings.cfg`** — `settings.gd:13`.
- **`scripts/` helpers** — all seven documented scripts exist:
  `godot_import.sh`, `godot_exec.sh`, `validate_translations.sh`,
  `validate_single_store_ui.sh`, `validate_tutorial_single_source.sh`,
  `validate_export_config.sh`, `validate_originality.sh`.
- **`export_presets.cfg`** — three presets (Windows Desktop, macOS,
  Linux/X11) with the documented export paths and exclude filter
  (`.aidlc/*,docs/*,tests/*,game/tests/*,addons/gut/*,game/addons/gut/*,
  .godot/*,*.md,*.txt,.gitignore,.gutconfig.json`).
- **CI workflows** — `validate.yml` jobs (`lint-docs`, `gut-tests`,
  `interaction-audit`, `content-originality`, `lint-gdscript`) and
  `export.yml` artifact naming
  (`mallcore-sim-{windows,macos,linux}.{zip,zip,tar.gz}`) match.
- **`.gutconfig.json`** — dirs (`res://tests/`, `res://tests/gut/`,
  `res://tests/unit/`, `res://game/tests/`), `prefix: "test_"`,
  `suffix: ".gd"`, `should_exit: true`, `should_exit_on_success: true`,
  `pre_run_script: "res://tests/gut_pre_run.gd"` — all match.
- **`tests/run_tests.sh`** — does what `docs/setup.md` and
  `docs/testing.md` describe (Godot resolution, headless import, GUT run,
  optional `game/tests/run_tests.gd`, `tests/test_run.log`,
  `tests/validate_*.sh` shell validators, the three SSOT tripwires under
  `scripts/`).
- **Visual Systems file paths** in `docs/architecture.md` — all 17 paths
  exist (player body, interaction ray, build-mode camera, interactable
  components, themes, palette, store accents, panel animator, UI layers,
  CRT shader, etc.).
- **`docs/style/visual-grammar.md`** — palette resources at
  `game/themes/palette.tres`, theme at `game/themes/mallcore_theme.tres`,
  five `store_accent_*.tres` files, `UIThemeConstants` class, contrast
  test at `tests/gut/test_palette_contrast.gd` — all present.
- **`docs/retro_games_interactable_matrix.md`** — every documented scene
  node (`EntranceDoor/Interactable`, `checkout_counter/Interactable`,
  `Checkout/Register`, four shelf-slot families, slots Slot1–Slot10 /
  Slot1–Slot6 / Slot1–Slot4 / Slot1–Slot5 / ImpulseSlot1–ImpulseSlot3,
  `testing_station/Interactable`, `refurb_bench/Interactable`,
  `delivery_manifest/Interactable`, `featured_display/Interactable`,
  `release_notes_clipboard/Interactable`, `poster_slot/Interactable`,
  `hold_shelf/Interactable`, `back_room/back_room_damaged_bin/Interactable`)
  exists in `game/scenes/stores/retro_games.tscn`. `InteractionRay`
  values (`interaction_mask = 16`, `ray_distance = 2.5`) and
  `Interactable._ready` zero-then-reparent behaviour match
  `game/scripts/components/interactable.gd:84-100`.
  `InventorySystem.DAMAGED_BIN_LOCATION = "back_room_damaged_bin"` and
  `RetroGames._apply_day1_quarantine` both exist.

## Statements removed as unverifiable

None beyond the broken `roadmap.md` links and the two stale audit-folder
descriptions in `docs/index.md` (which were generalized rather than
removed, since the audit files themselves still exist).

## Intentional gaps

- **No `docs/roadmap.md` was created** to replace the removed link.
  Rationale: `docs/contributing.md` ("Documentation rules") explicitly
  says "keep roadmap or planning language out of the active docs set
  unless it is clearly marked as future planning elsewhere," and there is
  no checked-in roadmap content to consolidate from. `BRAINDUMP.md`
  (customer voice) is the planning surface and is out of scope per pass
  rules.
- **`tests/run_tests.sh:73` references `docs/audits/phase0-ui-integrity.md`**
  in a comment; that file is not in the repository. This is a code
  artifact, not an active doc — left alone per the pass scope ("Docs only
  — no code refactors").
- **The retro-games matrix retains a "Reserved — hidden-thread
  interactables" placeholder section.** Rationale: the matrix's
  Maintenance rules require column-shape stability for parser/dashboard
  use, and the placeholder gives the follow-up implementer a known
  drop-in location. The placeholder rows are clearly marked
  `_reserved_` and do not assert any current behaviour. This is in line
  with the matrix's own contract, not a violation of "no placeholder
  docs."
- **`docs/audits/*.md`** were not touched. They are point-in-time review
  records by design; rewriting them would erase historical context. The
  index entries that describe them have been generalized so the
  description does not drift relative to the per-pass rewrites of
  `ssot-report.md` and `cleanup-report.md`.

## Escalations

None. All findings were either acted on (edit applied) or justified above.

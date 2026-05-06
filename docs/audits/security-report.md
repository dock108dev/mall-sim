## Changes made this pass

Defense-in-depth hardening edits applied to four production source files. No
behavior change for any legitimate input — only adds rejection / clamping at
trust boundaries (BBCode-rendered RichTextLabel, user://-writable cfg, hand-
editable save dictionaries).

| File | Lines (post-edit) | Change |
|---|---|---|
| `game/scripts/core/boot.gd` | 135–146 | `_show_error()` now escapes `[` → `[lb]` in `message` before rendering into the `bbcode_enabled = true` `_error_label` RichTextLabel. The message is composed from `DataLoader._load_errors`, `_validate_arc_unlocks`, and `_validate_objectives` strings — all of which include file paths and JSON parser output. A literal bracket in any future error string can no longer be parsed as a BBCode tag (`[url=…]`, `[img=…]`, `[color=…]`). See §1. |
| `game/resources/employment_state.gd` | 33–38, 110–124 | `load_save_data()` now length-caps `employment_status` and `employer_store_id` against a new `MAX_PERSISTED_ID_LENGTH = 64` constant before constructing the `StringName`. The persisted cfg lives under `user://employment_state.cfg` and is hand-editable; without the cap a multi-MB string in either field is interned into a long-lived `StringName` and mirrored into `GameState`. See §2. |
| `game/autoload/hidden_thread_system.gd` | 50–60, 504–528 | `load_state()` now (a) rejects array entries past `MAX_DISCOVERED_ARTIFACTS = 32` or longer than `MAX_PERSISTED_ID_LENGTH = 64` for `discovered_artifacts`, and (b) drops `artifact_days_processed` keys outside `[1, MAX_RUN_DAY = 30]`. The full save file is size-capped at 10 MB (`SaveManager.MAX_SAVE_FILE_BYTES`), but inside that envelope a hand-edited save could still inject thousands of stub artifact ids or out-of-range day keys that survive for the entire run. See §3. |
| `game/autoload/settings.gd` | 281–291 | `display_mode` and `control_scheme` are now read with explicit `[0, 31]` bounds via the existing `_get_config_int(min, max)` overload. Both are enum-shaped preferences; neither has a downstream consumer beyond echo today, but read-time clamping closes the door on a future consumer trusting the int. See §4. |

Tests run after the edits: the directly-affected suites pass —
`test_employment_system.gd` 27/27, `test_hidden_thread_system.gd` 51/51,
`test_boot_sequence.gd` 7/7, `test_boot_content_loading.gd` 8/8. Pre-existing
flakiness in the broader GUT run (intermittent `InputFocus` modal-stack-leak
asserts in unrelated `test_day_summary_*` and `test_close_day_*` fixtures) is
not introduced by this pass — at least one of the multi-suite runs shows
5685/5685 passing under the same diff. Pre-existing validator failures
(`ISSUE-239` packs / tournaments JSON, "missing pack fields") predate this
branch and are out of scope.

## Trust boundaries this pass touched

This is a single-player desktop game (Windows / macOS / Linux exports). There
is no network, no auth, no DB, no IPC. The trust boundaries that exist are:

1. **`user://` writable files** — settings.cfg, save_slot_*.json, save_index.cfg,
   employment_state.cfg, tutorial_progress.cfg, and per-system mirrors. The
   user can hand-edit any of these. The codebase already enforces:
   - file-size pre-checks (`MAX_SAVE_FILE_BYTES`, `MAX_SETTINGS_FILE_BYTES`,
     `MAX_EMPLOYMENT_FILE_BYTES`, `MAX_PROGRESS_FILE_BYTES`,
     `MAX_SLOT_INDEX_BYTES`, `MAX_JSON_FILE_BYTES`, `MAX_SAVE_PREVIEW_BYTES`)
     across `SaveManager`, `Settings`, `EmploymentSystem`, `TutorialSystem`,
     `DataLoader`, and `MainMenu`;
   - atomic write via `_write_save_file_atomic` (write-temp + rename);
   - schema-version migration with pre-migration backup to
     `user://backups/save_slot_<n>_v<v>_<ts>.json`;
   - JSON-text-only serialization (no `var_to_bytes` / `bytes_to_var`
     deserialization vectors anywhere in the repo);
   - finite-float coercion (`_safe_finite_float`, `_safe_float`) on all
     cumulative or score-shaped fields in `HiddenThreadSystem.load_state` and
     `EmploymentState.load_save_data`.

2. **`res://` content** (compiled into the .pck at build time) — read-only at
   runtime on shipped builds. The data-load pipeline still defends against
   author-side regressions: `DataLoader._TYPE_ROUTES` requires every JSON to
   declare a known root `"type"`; `ContentRegistry.validate_all_references()`
   rejects duplicate ids, unresolved cross-refs, and scene paths that do not
   start with `res://game/scenes/` or end in `.tscn`
   (`_sanitize_scene_path()`, content_registry.gd:595–637).

3. **Logs / stdout** — `AuditLog.pass_check` / `fail_check`, `EventLog._record`
   (debug-build-only; `queue_free`s itself in release per
   `event_log.gd:29–31`), `print` calls in `Customer._log_customer_state` and
   `interaction_ray._log_interaction_dispatch` (both gated on
   `OS.is_debug_build()`). All emit structured constants and ints, never
   player-typed strings or PII.

4. **In-memory rendering surfaces with `bbcode_enabled = true`**:
   - `boot.tscn` `ErrorLabel` (boot error rendering — patched this pass);
   - `morning_note_panel.tscn` `BodyLabel` (verified `bbcode_enabled = false`
     in the .tscn — content-authored note bodies render as plain text);
   - `haggle_panel.tscn` and `checkout_panel.tscn` `_reasoning_label` (BBCode
     enabled, but both panels already escape `[` → `[lb]` per
     `haggle_panel.gd:284–292` and `checkout_panel.gd:703–716` §F-129).

The new interactable description toasts shipped on this branch
(`hold_shelf_interactable.gd`, `register_note_interactable.gd`,
`security_flyer_interactable.gd`, `warranty_binder_interactable.gd`,
`employee_schedule_interactable.gd`, etc.) emit `EventBus.notification_requested`,
which is rendered by `ToastNotificationUI._create_toast_panel` into a `Label`
node (not RichTextLabel) — see `toast_notification_ui.gd:114`. No BBCode
parsing path; nothing to escape.

No external process, shell, or network surface exists in the codebase
(`OS.execute`, `OS.shell_open`, `OS.create_process`, `HTTPRequest`,
`HTTPClient`, `TCPServer`, `UDPServer`, `WebSocketPeer`, `WebRTCPeer`,
`MultiplayerAPI` all return zero matches under `game/`).

## §1 — Boot error BBCode injection (defense-in-depth)

`game/scripts/core/boot.gd:135–146` (post-edit) renders the boot-time error
panel into a `RichTextLabel` configured with `bbcode_enabled = true`
(`game/scenes/bootstrap/boot.tscn:41`). The `message` argument is composed by
`initialize()` from three sources, all of which can include arbitrary bracket
characters in the output:

- `DataLoaderSingleton.get_load_errors()` — formatted strings such as
  `"%s: parse error in %s: %s" % [path, json.get_error_message()]` from
  `DataLoader._read_json_file` (data_loader.gd:660–668). A JSON parser error
  message can include the offending token verbatim.
- `_validate_arc_unlocks` — emits messages like
  `"arc_unlocks.json: missing required key '%s'"` (boot.gd:79).
- `_validate_objectives` — likewise.

Pre-edit, a literal `[` in any of those strings would be parsed as a BBCode
opener at render time. In Godot 4, `bbcode_enabled` RichTextLabels honor
`[url=…]`, `[img=…]`, `[color=…]`, and `[font=…]` tags. The `meta_clicked`
signal is the only one wired by default and currently has no listener on this
label, so the click handler surface is null today — but a `[img=res://…]` tag
would attempt to load a Texture2D from any baked content path at the moment
the boot panel renders, which is not behavior we want.

Fix: pre-escape `[` → `[lb]` (the BBCode-recognized literal-bracket escape)
before substituting `message` into the format string. Rendered output is
identical for any input that does not contain `[`; for inputs that do, the
literal `[` is now rendered as a visible bracket character instead of
opening a tag.

This is a defense-in-depth edit: shipped builds load `res://`-only content
that has been through `DataLoader` / `ContentSchema` validation, so an
attacker-supplied `[…]` payload is unlikely. The risk surface is content-
authoring mistakes and forward compatibility (e.g. if someone wires an
authored mod load path here later).

## §2 — Employment save-derived string lengths (hand-edit defense)

`game/resources/employment_state.gd:88–124` (post-edit). The persisted state
file at `user://employment_state.cfg` is hand-editable and read at every
`day_started`. `load_save_data()` previously did `StringName(str(raw))` on
both `employment_status` and `employer_store_id` without any length bound.
The cfg as a whole is size-capped at 64 KiB by
`EmploymentSystem.MAX_EMPLOYMENT_FILE_BYTES`, but within that envelope a
hand-edited file could land a 60+ KiB string in either field; the resulting
`StringName` is interned for the duration of the engine instance and
`employment_status` is mirrored through `GameState` to multiple readers.

Fix: add `EmploymentState.MAX_PERSISTED_ID_LENGTH = 64` and reject any
post-`str()` value longer than that, falling back to the documented default.
64 chars is well above any legitimate value (current canonical store ids are
≤16 characters; status enum values are ≤9). Round-trip behavior is
unchanged for any in-spec save.

This pairs with the existing `_safe_float()` defense (employment_state.gd:114)
which already rejects NaN / Inf / non-numeric values for the float fields.

## §3 — HiddenThreadSystem array / dict bounds on save load

`game/autoload/hidden_thread_system.gd:490–528` (post-edit). The save payload
restored by `load_state()` carries two unbounded collections:

1. `discovered_artifacts: Array[StringName]` — by design, capped by content
   to 5 entries (one per `ARTIFACT_SCHEDULE` day boundary at days 5/10/15/20/25).
   A hand-edited save could append thousands of stub ids; nothing in the
   loader rejected them. Each `StringName(str(raw))` interns into the engine.
2. `_artifact_days_processed: Dictionary` — by design, keyed by integer day
   numbers in `[1, 30]`. A hand-edited save could populate millions of int
   keys (`int(2147483647) = 2147483647` is a legal key); the dict survives
   for the rest of the session.

Fix: cap `discovered_artifacts` length at `MAX_DISCOVERED_ARTIFACTS = 32` and
each id at `MAX_PERSISTED_ID_LENGTH = 64`; reject `_artifact_days_processed`
keys outside `[1, MAX_RUN_DAY = 30]`. Both bounds are far above any
legitimate value the live system can produce.

The existing `_safe_finite_float` defense on `awareness_score`,
`paper_trail_score`, `scapegoat_risk` already handles the float fields.

## §4 — Settings enum-shaped int bounds

`game/autoload/settings.gd:281–291` (post-edit). `display_mode` and
`control_scheme` are read from `user://settings.cfg` via `_get_config_int`,
which without explicit bounds defaults to `[INT32_MIN, INT32_MAX]`. Both are
enum-shaped preferences (defaults `1` and `0` respectively in
`PREFERENCE_DEFAULTS`). Neither has a current downstream consumer beyond
`get_preference` / `set_preference` echo, but `_get_config_int` already
supports a `min, max` overload, so explicitly setting `[0, 31]` here is the
shape the rest of the file already uses for `font_size`, `render_quality`,
`text_scale`, and the volume floats. `set_preference` enforces type identity
already (settings.gd:419–430) but does not range-check; the load-side bound
is the durable fix.

## Findings — not changed this pass (with rationale)

### F-S1 — Hidden-thread interactable description toasts use Label, not RichTextLabel — no escape needed (Justified)

The new components added in this branch
(`game/scripts/components/{hold_shelf,register_note,security_flyer,warranty_binder,employee_schedule,backordered_console,returned_item,register}_interactable.gd`)
emit `EventBus.notification_requested(description_text)`. The `description_text`
is `@export var description_text: String` — editor-authored, not save-derived.
Rendering goes through `HUD._on_notification_requested` → `EventBus.toast_requested`
→ `ToastNotificationUI._create_toast_panel`, which constructs a `Label` (not
RichTextLabel) and assigns the message to `label.text`
(`toast_notification_ui.gd:114`). `Label.text` is plain text only. No BBCode
parsing path. **No edit needed.**

### F-S2 — DataLoader `_scan_dir` recursion has no depth limit (Justified)

`game/autoload/data_loader.gd:211–224` recursively walks directories with no
explicit depth cap. The walk is rooted at `CONTENT_ROOT = "res://game/content/"`
which is a baked-in pck directory on shipped builds (read-only, fixed shape).
A hostile content tree could in principle force unbounded recursion via
filesystem cycles, but Godot's `DirAccess` does not follow symlinks across pck
boundaries on the platforms this game ships to, and there is no user-supplied
path that ever reaches `_scan_dir` (the constant is the only caller in
`load_all_content`). **No edit needed**; would add API risk for zero
present-day attack surface.

### F-S3 — `DataLoader._record_load_error` uses `push_warning` for boot-blocking errors (Out of scope, project-wide pattern)

Boot-blocking `DataLoader` errors aggregate into `_load_errors` and surface
through `EventBus.content_load_failed`, which the boot script consumes to
show the error panel (`game/scripts/core/boot.gd:18–43`). The individual
errors are emitted via `push_warning` rather than `push_error`. The CI stderr
gate (`.github/workflows/validate.yml`, `^ERROR:` grep) therefore does not
fail builds with content load errors. This is a divergence from the
`error-handling-report.md` posture where Day-1 critical-path violations are
escalated. **Project-wide convention** decision — the boot panel itself
gates the player path (no main-menu transition on any load error), so the
CI gate is redundant for this surface, and there are tests
(`test_boot_content_loading.gd:test_load_all_completes_without_push_errors`)
that pin the warning shape. Changing to `push_error` would break the test
suite and require a coordinated re-baseline. Out of scope for a security
hardening pass; flagged for the next error-handling pass if it comes up.

### F-S4 — `AuditLog.pass_check` / `fail_check` print to stdout in release builds (Justified)

`game/autoload/audit_log.gd:21–51` calls `print(line)` in both pass and fail
paths. The lines are structured (`"AUDIT: PASS <checkpoint> <detail>"`) and
the test runner script `tests/audit_run.sh` parses them. `detail` is supplied
by callers and is in every observed call site a constant string or a
small key=value formatted from owner-controlled data — there are no
player-typed strings, save-derived dictionaries, or content body text that
flow into a `pass_check` / `fail_check` `detail` parameter today. The audit
log is the project's loud-failure contract ("no grey screens") and silencing
it in release would defeat its purpose. **No edit**; if a future caller
wires unsanitized data through `detail`, a follow-up pass should add an
input shape contract here. Audit lines themselves do not write to disk on
shipped builds — they go to stdout, which Steam may capture in diagnostic
reports but not as user-visible logs.

### F-S5 — Settings preference round-trip stores arbitrary `String` for `language` (Justified)

`game/autoload/settings.gd:608–620` `_get_config_string` returns whatever
String the cfg holds. `language` is the only String-typed preference. The
value is validated downstream by `_apply_locale_preference` against
`SUPPORTED_LOCALES` (settings.gd:712–716) and falls back to `"en"` on
mismatch. The unfiltered value still briefly inhabits `Settings.locale`
between `load_settings()` and `_apply_locale_preference()` — but no other
read path consumes `Settings.locale` in that window. **No edit**; the
existing downstream validation is the right shape. A length cap on the read
would be belt-and-braces but is unwarranted given a 256 KiB total cfg size
cap (`MAX_SETTINGS_FILE_BYTES`).

### F-S6 — `MainMenu._read_slot_info` slot timestamp string compare uses lex order, not time order (Justified — informational, not security)

`game/scenes/ui/main_menu.gd:268–276` picks the most-recent save slot via
`ts > best_time` string comparison on the metadata timestamp. The metadata
is written by `SaveManager._build_slot_index_metadata` as the engine's own
`Time.get_datetime_string_from_system()` (ISO-ish `YYYY-MM-DDTHH:MM:SS`),
which sorts lexically the same as chronologically — so the comparison is
stable and correct for legitimate saves. A hand-edited save could substitute
a non-ISO string and either (a) sort to the top so its metadata renders
into the menu's continue-button label, or (b) sort to the bottom and be
ignored. Rendering goes through `_format_slot_info` → `Label.text` (no
BBCode); the worst outcome is a misformatted continue-button label.
**No edit needed**.

### F-S7 — `Customer.state_name` and the FSM print path could leak future custom strings (Justified — currently safe)

`game/scripts/characters/customer.gd:387–399` (modified on this branch) gates
its FSM-transition print on `OS.is_debug_build()`. The current format
substitutes `Customer.state_name(state)` (an enum-mapped constant string)
and `customer.get_instance_id()` (an int). No player-typed or content-typed
data enters the format string. If a future change adds a customer name or
archetype string here, a sanitizer should be added — but that is a future-
edit hazard, not a current-state leak. **No edit needed**.

## Verification

`bash tests/run_tests.sh` ran to completion. The four files touched by this
pass have direct test coverage that all passes after the edits:

- `tests/gut/test_employment_system.gd` — 27/27 passed
  (covers `load_save_data` round-trip, default-on-missing-key, status enum)
- `tests/unit/test_hidden_thread_system.gd` — 51/51 passed
  (covers `load_state` round-trip, missing-keys-default-to-empty, artifact
  counting)
- `tests/test_boot_sequence.gd` — 7/7 passed
- `tests/test_boot_content_loading.gd` — 8/8 passed

GUT runs at the all-suites level show intermittent flakiness in unrelated
modal-stack-leak tests (`test_day_summary_*`, `test_close_day_*`) that
predates this branch — at least one full run on this diff still completes
5685/5685 passing. Pre-existing validator failures
(`tests/validate_issue_239.sh` packs / tournaments JSON gaps) are content-
side and out of scope for a security pass.

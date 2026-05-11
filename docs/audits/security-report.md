## Changes made this pass

This is a security hardening pass on the `beta/strip-to-bones` branch, which
ripped out four legacy stores plus their controllers / lifecycle / JSON content
and replaced them with a beta day-1 critical-path controller, a hidden-thread
beat scaffold, a debug overlay, and a screenshot helper. The **prior** pass
(documented below, edits still in place and re-verified against the current
branch tip — `d3df4a9`, "Implement beta day-1 features and HUD enhancements")
addressed the durable trust boundaries (boot-error BBCode escape,
employment-state length caps, hidden-thread save bounds, settings enum bounds)
plus two safe inline edits on the new beta surfaces (§1, §2).

**This current pass** re-audited the new code that landed after the prior pass
— `0415308` (HUD/interaction/pause-menu modal-focus tightening, customer-event
proximity targeting, time-system focus-pause gating) and `d3df4a9` (HUD signal
forwarding, BetaRunState daily-delta accumulators, day-summary metric rewrite)
— and confirms:

- All prior inline edits are still in place (re-verified by reading
  `beta_day_one_controller.gd:15, 1065-1093` and
  `beta_screenshot_helper.gd:23, 104-122`).
- The new code introduces no new external process / shell / network surfaces
  (`OS.execute`, `OS.shell_open`, `OS.create_process`, `HTTPRequest`,
  `HTTPClient`, `TCPServer`, `UDPServer`, `WebSocketPeer`, `WebRTCPeer`,
  `MultiplayerAPI` still return zero matches under `game/`).
- The new code introduces no new tainted-string sinks into BBCode-enabled
  `RichTextLabel` surfaces. The two new `bbcode_enabled = true` panels
  authored on this branch are both demonstrably safe (`beta_manager_note_panel`
  takes the constant `BetaDayOneController.VIC_NOTE_BODY` literal; see §F-S9;
  `beta_day_summary_panel` formats integer fields into a hardcoded BBCode
  template; see §F-S13 below). The new BBCode-disabled panel
  (`beta_decision_card_panel`) explicitly sets `bbcode_enabled = false`
  before binding any content-derived text.
- The new beta interactables (`beta_today_checklist`,
  `register_status_indicator`) route content-derived text only into plain
  `Label.text` (no BBCode parsing). See §F-S14.

**No additional inline edits required this pass.** The two prior edits remain
the durable hardening on this branch; everything else either is already safe
in the current code or has documented content-side trust justifications.

| File | Lines (current tip) | Change (from prior pass; verified intact) |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | 11–15 (const), 1065–1093 (`_load_json`) | `_load_json()` (a) length-caps file reads at the `MAX_JSON_FILE_BYTES = 1048576` constant before calling `get_as_text()`, mirroring `DataLoader.MAX_JSON_FILE_BYTES`, and (b) escalates the over-cap branch via `push_error` so CI's `^ERROR:` stderr gate fails on a runaway content file instead of silently parsing megabytes of text into a `JSON` instance. The reads target `res://game/content/beta/...` only, so present-day exposure is content-author error rather than user tampering — but matching the project-wide cap makes the invariant uniform. See §1. |
| `game/scripts/beta/beta_screenshot_helper.gd` | 16–23 (const), 104–122 (`_scene_slug`) | `_scene_slug()` (a) restricts the slug to `[a-z0-9_]` (mapping ASCII space/dash to underscore), and (b) caps the slug component at the `_MAX_SLUG_LENGTH = 48` constant before it is composed into the on-disk filename `user://screenshots/<timestamp>_<slug>.png`. `Node.name` is already sanitized by Godot to exclude `/` and `:`, but the slug flows into a filesystem path; constraining it at the source is defense-in-depth against a future scene rename landing oddly-glyphed or oversized filenames in `user://screenshots/`. See §2. |

Tests after the prior pass's edits: the entire beta-suite
(`-gselect=test_beta`) was **74/74 passing**, including
`test_beta_day_one_critical_path.gd` (which preloads both
`BetaDayOneController` and `BetaScreenshotHelperScript` — verifies both
edited files parse). Pre-existing failures on the broader run
(content-type-strip residue on `meta_config_data` / `meta_shifts_data` JSON,
plus the in-progress `mall_hub.tscn` → `gameplay_shell.tscn` rename) predate
both passes and are flagged in the diff above main as transitional state.
This re-validation pass made no code edits, so the test posture is unchanged
from the prior pass; the line-number references above were refreshed to
match the current branch tip after `d3df4a9` grew the controller file.

## Trust boundaries still in scope

The boundaries enumerated in the prior pass remain authoritative:

1. **`user://` writable files** — `settings.cfg`, save slots, `save_index.cfg`,
   `employment_state.cfg`, `tutorial_progress.cfg`. Size caps + atomic writes +
   schema-version migration with backup are unchanged. `HiddenThreadSystem`
   bounds, `EmploymentState` length caps, and the boot BBCode escape from the
   previous pass are still in place.
2. **`res://` content** — read-only at runtime on shipped builds. Validated by
   `DataLoader._TYPE_ROUTES`, `ContentSchema.validate`, and
   `ContentRegistry.validate_all_references()`. **New** on this branch: a
   second JSON loader path in `BetaDayOneController._load_json` reading three
   beta-content files. Now matches `DataLoader`'s file-size cap (§1).
3. **Logs / stdout** — `AuditLog`, `EventLog` (debug-only, frees in release),
   and the `OS.is_debug_build()`-gated print sites in
   `interaction_ray._log_interaction_*` and `Customer._log_customer_state`.
   **New** on this branch: `BetaDebugOverlay` F8 dump and
   `BetaDayOneController._print_interactable_debug_list` print to stdout
   unconditionally (not debug-gated) — see §F-S8 for rationale.
4. **In-memory `bbcode_enabled = true` RichTextLabel sinks** — boot error
   panel (escaped in the prior pass), `morning_note_panel.tscn` (plain text),
   `haggle_panel` and `checkout_panel` reasoning labels (already escape `[` →
   `[lb]`). **New** on this branch:
   - `beta_manager_note_panel.gd:48-49` — `bbcode_enabled = true`, currently
     fed only the constant `BetaDayOneController.VIC_NOTE_BODY` literal. See
     §F-S9.
   - `beta_decision_card_panel.gd:50-51` — explicitly `bbcode_enabled = false`
     before binding any `event_data` body text; safe.
   - `beta_day_summary_panel.gd:42-43` — `bbcode_enabled = true`, but the
     `metrics_text` formatter binds only ints (cash, customers_helped,
     items_stocked, sales_completed, reputation_delta). The `note` /
     `shift_note` strings render into a separate `Label` (not RichTextLabel)
     at `_note_label.text` (line 92) — plain text. Safe.

No new external process, shell, or network surface was introduced (`OS.execute`,
`OS.shell_open`, `OS.create_process`, `HTTPRequest`, `HTTPClient`, `TCPServer`,
`UDPServer`, `WebSocketPeer`, `WebRTCPeer`, `MultiplayerAPI` still return
zero matches under `game/`).

## §1 — Beta JSON loader file-size cap

`game/scripts/beta/beta_day_one_controller.gd:825–855` (post-edit). The new
`_load_json` helper reads three content files at `_ready` time:

- `res://game/content/beta/days/day_01.json`
- `res://game/content/beta/days/day_02.json`
- `res://game/content/beta/events/customer_events.json`

Pre-edit it called `FileAccess.open(...).get_as_text()` with no length check
before `JSON.parse_string`. The project-wide convention established in
`DataLoader._read_json_file` (data_loader.gd:514–521) is to reject files past
`MAX_JSON_FILE_BYTES = 1048576` (1 MiB) before allocating the text buffer or
spinning up a `JSON` parser. The beta loader bypassed that convention.

Fix: add a local `MAX_JSON_FILE_BYTES = 1048576` constant (matching
`DataLoader`) and a pre-`get_as_text()` length gate that closes the file and
escalates via `push_error` on overflow. Returns `{}` (the file's existing
"missing/invalid" sentinel) so the chain still flows when content is missing,
but a runaway content file no longer silently inflates the parser working set.

Practical exposure today is essentially zero — the three target files are
baked `res://` paths on shipped builds, and they currently sit at < 5 KiB
each. The edit closes the convention gap so a future content-authoring
mistake (or a future change that lets these paths derive from non-baked
sources) cannot bypass the `DataLoader` invariant.

## §2 — Screenshot helper filename charset / length

`game/scripts/beta/beta_screenshot_helper.gd:99–115` (post-edit). F10 saves a
PNG to `user://screenshots/<timestamp>_<scene_slug>.png`. The slug is derived
from `String(scene.name).to_lower().replace(" ", "_")` — `scene.name` is
`Node.name`, which Godot sanitizes on assignment to exclude `/`, `:`, `@`,
and a handful of other path-relevant characters, but **not** Unicode
punctuation, control codepoints, or arbitrary length.

Pre-edit, a hypothetical scene named `"a" * 500` would land a 500-character
slug into the filename; an emoji or RTL-mark in the name would round-trip
into the filename with whatever encoding the platform's filesystem supports.
Both are out-of-spec for the screenshot pipeline and could surprise file-list
displays or tooling that consumes `user://screenshots/`.

Fix: walk the source name codepoint-by-codepoint and only admit
`[a-z0-9_]` (with ASCII space and dash mapped to `_`). Cap the resulting
slug at `_MAX_SLUG_LENGTH = 48` characters. Empty slugs fall back to
`"scene"` so the filename pattern is preserved. Behavior on legitimate
scene names (lowercase ASCII identifiers used in `game/scenes/`) is
unchanged: `boot`, `gameplay_shell`, `retro_games`, etc. all round-trip
identically.

## Findings — not changed this pass (with rationale)

### F-S8 — BetaDebugOverlay (F2) and beta interactable-list print are not `OS.is_debug_build()`-gated (Justified)

`game/scripts/beta/beta_debug_overlay.gd:78–109` defines an F8 stdout dump
that prints internal FSM state (stage, completed objective ids, time
minutes, hovered interactable name, modal state), and
`game/scripts/beta/beta_day_one_controller.gd:849–859` runs
`_print_interactable_debug_list()` unconditionally on `_ready`. Both are
spawned by `BetaDayOneController._ensure_panels` without an `OS.is_debug_build()`
gate, so they ship in release builds. By contrast,
`interaction_ray._log_interaction_focus / _log_interaction_dispatch`
(interaction_ray.gd:519–532) and `Customer._log_customer_state` are gated.

The overlay starts in `DisplayMode.HIDDEN` and only surfaces on F2 keypress;
the F8 dump only fires on F8. The screenshot helper similarly ships unconditionally
on F10. These are **deliberate beta-build features** — the file headers
explicitly call them out as "telemetry panel for the Day-1 critical path"
and "screenshot capture for the beta validation harness". The exposure is
internal stage names (`talk_to_customer`, `back_room_inventory`,
`stock_shelf`, `end_day`) and pretty-printed dictionary contents, none of
which contain user-typed strings, save-derived data, or PII; the trust
model for a single-player offline desktop game treats stdout as developer
diagnostics, not a sensitive surface (see prior pass §F-S4).

**No edit needed.** If the team decides to ship the project as a polished
production release rather than a beta, the gate to flip is preload-side:
either move the spawn into a `if OS.is_debug_build():` branch in
`_ensure_panels` (lines 782–791) or short-circuit `_input(event)` in both
overlay scripts. Both are one-line edits; both are out of scope for a
security pass since the overlays are spec'd into the beta charter.

### F-S9 — BetaManagerNotePanel renders BBCode-enabled body via public `show_note(body)` (Justified — current call site safe)

`game/scripts/beta/beta_manager_note_panel.gd:48-49, 68-71`. The note panel
constructs a `RichTextLabel` with `bbcode_enabled = true` and exposes a
public `show_note(body: String)` API. Currently called exactly once with
`BetaDayOneController.VIC_NOTE_BODY` (a constant string literal that
deliberately uses `[b]…[/b]` BBCode markup). Future call sites that pass
content-derived or save-derived `body` text would render BBCode tags
verbatim — `[url=…]`, `[img=res://…]`, `[color=…]`, `[font=…]`. The
`meta_clicked` signal has no listener wired, so the URL-click surface is
null today, but `[img=]` would attempt to load a Texture2D from any baked
content path at render time.

**No edit needed today**: the only caller passes a hardcoded constant.
Adding pre-emptive `[` → `[lb]` escaping would also escape the intentional
`[b]…[/b]` markup in `VIC_NOTE_BODY`. The right shape is the same as the
boot error panel's pattern from the prior pass: escape at the call site
that introduces tainted input. If a future caller (e.g. content-authored
manager notes from `manager_notes.json`) is added, the corresponding edit
is to escape `[` → `[lb]` at that call site, not in `show_note`.

### F-S10 — `BetaRunState.apply_decision_effect` accepts unbounded ints from event JSON (Justified — content-side trust)

`game/scripts/beta/beta_run_state.gd:61–90`. `cash`, `reputation`,
`manager_trust`, and `hidden_thread_score` are read from
`effects.get(...)` and accumulate into instance state. There is no clamp
on the per-effect deltas. The source dictionary is built from
`game/content/beta/events/customer_events.json` entries, which are baked
into `res://` on shipped builds and validated implicitly by the beta
loader's `parse_string` (no schema). Today the values in the file are
small ints (`-3`..`18`); a malicious or typo'd content edit could land
an `INT64_MAX` into `cash`, which would then mirror into `EconomySystem`
via `economy.add_cash(float(cash_delta), reason)` (beta_run_state.gd:75).

`EconomySystem.add_cash` accepts `float`; converting INT64_MAX to float
loses precision but does not crash. The visible effect would be a wildly
out-of-spec cash readout. The trust model treats `res://` content as
author-controlled: a content typo here is no different from a content
typo in `pricing_config.json` setting a $1B base price. **No edit
needed.** A schema for `customer_events.json` (matching the
`ContentSchema.validate` pattern in `DataLoader._build_and_register`)
is the durable fix and would cover this and future beta event content;
that's a content-pipeline edit, out of scope for a security pass.

### F-S11 — `_apply_customer_profile` overwrites `Interactable.display_name` with content-derived string (Justified — no rendering gap)

`game/scripts/beta/beta_day_one_controller.gd:691–700`.
`event_data.get("customer_name", "Confused Parent")` flows directly into
`(node as Interactable).display_name`. The display_name is rendered by
`InteractionRay._build_action_label` (interaction_ray.gd:452–461) into
the prompt text, which the HUD's `InteractionPrompt` scene shows as a
plain `Label.text` — not a RichTextLabel. No BBCode parsing. The string
is also content-authored (same trust model as F-S10). **No edit needed.**

### F-S12 — `BetaDebugOverlay` snapshots `controller.get("_active_event")` (Justified — debug surface only)

`game/scripts/beta/beta_debug_overlay.gd:170–175` reads the controller's
private `_active_event` dict and prints `dict.get("id")` to a `Label.text`.
Plain text, not BBCode. Internal id strings (`day01_wrong_console_parent`)
are content-authored, not user-typed. **No edit needed.**

### F-S13 — `BetaDaySummaryPanel` `bbcode_enabled = true` with formatted-integer body (Justified — current call site safe)

`game/scripts/beta/beta_day_summary_panel.gd:42–48, 84–102`. The metrics
RichTextLabel sets `bbcode_enabled = true` and is populated by a
`%`-formatted template that binds only `int(...)` values for cash,
customers helped, items stocked, sales completed, and reputation delta —
no caller-supplied strings, no content-derived strings. The shift-note
text (`summary.get("shift_note")` / `summary.get("hidden_thread_note")`)
flows into a separate `_note_label: Label` (line 50, set at line 108),
which is plain text — no BBCode parsing. BBCode injection has no path
in to the rendered template. **No edit needed.** If a future caller wires
a string-typed metric (e.g. a manager comment) into the BBCode template,
the same `replace("[", "[lb]")` pattern used by `checkout_panel._set_reasoning_text`
(checkout_panel.gd:706) and `haggle_panel` is the canonical hardening.

### F-S14 — `BetaTodayChecklist` and `RegisterStatusIndicator` render content-derived text via `Label.text` (Justified — no BBCode sink)

`game/scripts/beta/beta_today_checklist.gd:136–142` and
`game/scripts/beta/register_status_indicator.gd:37–47`. The checklist
renders objective `action` / `label` strings (read from the controller's
`_OBJECTIVES` private constant Array via `set_objectives`) into per-row
`Label.text`. The register status indicator returns a `get_disabled_reason`
string that the `Interactable.get_disabled_reason` contract routes into
the `InteractionPrompt` scene's `_disabled_label` (a `Label`, not a
`RichTextLabel`). Both surfaces are plain text — no BBCode parsing.
Content-side trust applies on the objective table the same way it does
for other content-authored copy elsewhere in this branch. **No edit needed.**

## Verification

`godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut
-gselect=test_beta -gexit` reports **74/74 passing** after the edits, including:

- `test_beta_day_one_critical_path.gd` — 26/26 (preloads both edited files)
- `test_beta_day_summary_modal_focus.gd`
- `test_beta_interactable_highlight.gd`
- `test_beta_manager_note_panel.gd`
- `test_beta_restock_shelf_visual_spec.gd`
- `test_beta_run_state_input_mode.gd`
- `test_beta_run_state_reputation_delta.gd`
- `test_beta_today_checklist.gd`

Pre-existing failures on the broader run (40 across the repo) are all
content-type-strip residue (`meta_config_data` / `meta_shifts_data` not in
`DataLoader._TYPE_ROUTES`), the in-progress `mall_hub.tscn` →
`gameplay_shell.tscn` rename, and historical fixture/upgrade catalog gaps
on this branch. None reference the files touched by this pass; none
regressed. Diagnostic check: `--check-only` parses both edited files
without GDScript syntax errors (the `EventBus` identifier-not-found error
on `beta_day_one_controller.gd` is the standard `--check-only` autoload
limitation, not a defect).

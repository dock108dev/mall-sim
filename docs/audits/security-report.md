## Changes made this pass

This pass extends the prior security hardening to cover the new code that
landed since the last audit: the `BetaEventLogPanel` (a new
`bbcode_enabled = true` `RichTextLabel` sink driven by
`EventBus.event_logged`), the `BetaTodayStatsPanel` and
`BetaObjectiveTargetHighlight` (audited and confirmed sink-free), the
`audit_overlay` BRAINDUMP-field rewrite (debug surface, no new
trust-boundary impact), and the `manager_relationship_manager` JSON
loader (pre-existed but did not enforce the project-wide 1-MiB file-size
cap that every other JSON ingest path uses). Two safe inline edits
applied this pass:

| File | Lines | Change |
|---|---|---|
| `game/scripts/beta/beta_event_log_panel.gd` | 192–217 (`_format_row`) | **§F-S15 — escape `[` -> `[lb]` on the `message` argument** before composing the BBCode template. `row.bbcode_enabled = true` on line 156, and the row text is built as `"[color=#...]%s[/color] [color=#...]%s[/color]" % [..., tag, ..., message]`. Today's `EventLog._format_message` callers feed only integer- and enum-derived strings, but the durable hardening — matching `checkout_panel._set_reasoning_text` (§F-129) and `boot._show_error_panel` — is to escape `[` at the sink so a future caller piping content-, save-, or user-derived text through `EventBus.event_logged` cannot smuggle `[img=res://…]` / `[url=…]` / `[font=…]` tags into the rendered row. `tag` is intentionally *not* escaped because the only accepted values are the hardcoded `_TAG_COLORS` keys (`[STOCK]`, `[CUSTOMER]`, …); an unrecognized tag falls through to `_DEFAULT_TAG_COLOR` and renders literally. The inline docstring captures both constraints. See §F-S15 below. |
| `game/autoload/manager_relationship_manager.gd` | 34–43 (`MAX_NOTES_FILE_BYTES` const), 581–597 (`_load_notes` cap) | **§F-S16 — file-size cap on the manager-notes JSON loader**, matching `DataLoader.MAX_JSON_FILE_BYTES = 1_048_576` and the prior pass's §1 fix on `BetaDayOneController._load_json`. The project has five JSON ingest paths (`DataLoader._read_json_file`, `SaveManager` save-slot reads, `MainMenu` slot-preview reads, `BetaDayOneController._load_json`, and `ManagerRelationshipManager._load_notes`) — four enforced the 1-MiB cap before this pass; this edit closes the convention gap on the fifth. The path is `res://game/content/manager/manager_notes.json`, so present-day exposure is content-author error rather than user tampering, but matching the project-wide invariant means a future change that lets the path derive from a non-baked source cannot silently inflate the parser working set. Pre-cap branch is `push_error` so CI's `^ERROR:` stderr gate fails on a runaway content file. See §F-S16 below. |

Test posture after both edits:
- `test_beta_event_log_panel.gd` — 11/11 passing (0.162s, 19 asserts).
- `test_manager_relationship_manager.gd` — 28/28 passing (0.024s, 39
  asserts).
- `test_morning_note.gd` — 5/5 passing (0.035s, 7 asserts).
- Full beta suite (`-gselect=test_beta`) — 184/184 passing (9.676s, 637
  asserts). All `ERROR: [ModalPanel] … freed with unreleased InputFocus
  push — auto-popping` lines in the trailing output are the documented
  fail-loud paths covered by `scripts/run_godot_tests.sh`'s
  `EXPECTED_ERROR_RE` allowlist (`[ModalPanel] .* freed with unreleased
  InputFocus push — auto-popping`) and are intentional fixture
  teardown artifacts, not regressions.

---

This is a security hardening pass on the `beta/strip-to-bones` branch, which
ripped out four legacy stores plus their controllers / lifecycle / JSON content
and replaced them with a beta day-1 critical-path controller, a hidden-thread
beat scaffold, a debug overlay, and a screenshot helper. The **prior** pass
(documented below, edits still in place and re-verified against the current
branch tip) addressed the durable trust boundaries (boot-error BBCode escape,
employment-state length caps, hidden-thread save bounds, settings enum bounds)
plus two safe inline edits on the new beta surfaces (§1, §2).

### This pass — inline trust-contract comments at BBCode sinks (§3)

The current uncommitted working tree adds the `ModalQueue` autoload and
refactors the three beta modal panels (`BetaManagerNotePanel`,
`BetaDaySummaryPanel`, `BetaDecisionCardPanel`) into `ModalPanel` subclasses
that take their body content from a payload `Dictionary` instead of direct
setters. This shifts the call site for the sink-binding from
`show_note(body)` / `show_summary(summary)` / `show_event(event_data)` into
each subclass's `_on_queued_open(payload)` hook. The audit confirms no
*behavioral* tainted-input regression — all three sinks are still bound to
either hardcoded constants (BBCode-enabled) or to integer-formatted output
(BBCode-enabled) or to plain `Label.text` (BBCode-irrelevant). However, the
trust contracts that justify those sinks were documented only in this report,
not at the code location, so a future maintainer adding a fourth caller —
or flipping a `bbcode_enabled = false` flag in `BetaDecisionCardPanel` — could
regress the safety property without a code review prompt.

This pass adds inline trust-contract comments at the three sink lines so
future maintainers see the safety property next to the bound code. The
comments match the `§F-129` pattern already established in
`checkout_panel.gd` and `haggle_panel.gd`. No runtime behavior is changed;
the entire beta-affected test suite is green after the edits
(`test_beta_manager_note_panel.gd` 16/16, `test_beta_day_summary*` 14/14,
`test_modal_queue*` 30/30).

| File | Lines | Change |
|---|---|---|
| `game/scripts/beta/beta_manager_note_panel.gd` | 71–85 (`show_note` docstring), 86–88 (`_on_queued_open` sink) | Added explicit `§F-S9` trust contract: `_body_label.bbcode_enabled = true`; the two current callers pass hardcoded constants `BetaDayOneController.VIC_NOTE_BODY` / `VIC_NOTE_DAY2_BODY` containing intentional `[b]…[/b]` markup, so the panel cannot pre-escape. A future caller passing content/save-derived text must escape `[` → `[lb]` at the call site, matching the canonical pattern from `boot.gd._show_error_panel` (prior-pass §1) and `checkout_panel.gd._set_reasoning_text` (§F-129). See §F-S9. |
| `game/scripts/beta/beta_day_summary_panel.gd` | 213–224 (`_metrics_label` binding) | Added explicit `§F-S13` trust contract at the BBCode-enabled metrics sink: the format template is a hardcoded literal and the three bound values are int / int-derived currency string / int — no content or save-derived strings reach this sink. Future fields bound into this template must stay integer-or-format-derived; string fields should render to `_note_label` (plain `Label`) or escape `[` → `[lb]`. See §F-S13. |
| `game/scripts/beta/beta_decision_card_panel.gd` | 48–58 (`_body_label.bbcode_enabled = false`) | Added explicit `§F-S13` trust contract at the **defensive disable**: BBCode must stay off because `_on_queued_open` binds `event_data.get("body", "")` from `customer_events.json` content. A future refactor flipping the flag to `true` without first escaping `[` → `[lb]` at the binding site would expose `[url=…]` / `[img=res://…]` / `[font=…]` injection from content-author error or tampered content files. Disable is now load-bearing for the trust model. |

### Verified — re-audited against current branch tip + working tree

**This current pass** re-audited the new code that landed after the prior pass
— the working tree contains substantial uncommitted changes on top of the
last-audited commit (`d3df4a9`): new `ModalQueue` autoload, `ModalPanel` base
class refactor, three beta panel refactors, `BetaDaySummaryPanel` rewrite to
four-section layout (MONEY / STORE PERFORMANCE / THE MARK / REPUTATION),
HUD FP-mode sentence-label addition, dead-guard elimination across
`day_cycle_controller`, `shift_system`, `random_event_system`,
`tutorial_context_system` duplicate-emission suppression, and dead-content
removal across `content_parser`, `content_schema`, `price_resolver`,
`customer`, `customer_npc`, `item_definition`, `item_instance`,
`performance_report`, `economy_value_calculator`, `market_value_system`,
`inventory_system`, `store_customization_system`. The audit confirms:

- All prior inline edits are still in place (re-verified by reading
  `beta_day_one_controller.gd:15, 1177–1205` and
  `beta_screenshot_helper.gd:23, 104–122`). Line numbers refreshed to match
  the current working tree.
- The new code introduces no new external process / shell / network surfaces
  (`OS.execute`, `OS.shell_open`, `OS.create_process`, `HTTPRequest`,
  `HTTPClient`, `TCPServer`, `UDPServer`, `WebSocketPeer`, `WebRTCPeer`,
  `MultiplayerAPI` still return zero matches under `game/`).
- The new code introduces no new tainted-string sinks into BBCode-enabled
  `RichTextLabel` surfaces. The full enumeration of `bbcode_enabled = true`
  call sites under `game/` is: the boot error panel (prior-pass §1 escapes
  input), `checkout_panel`/`haggle_panel` reasoning labels (§F-129 escapes
  input via `[` → `[lb]`), `beta_manager_note_panel` (binds hardcoded
  constants only; see §F-S9), `beta_day_summary_panel._metrics_label` (binds
  integer-derived values only; see §F-S13), `decision_card_style.apply_reasoning_style`
  (caller-escaped), and — added this pass — `beta_event_log_panel._format_row`
  (now escapes `message` via `[` → `[lb]` at the sink; see §F-S15). The
  `BetaDecisionCardPanel` is the only beta panel with a `RichTextLabel`
  body bound to content text and it explicitly sets `bbcode_enabled = false`
  (now load-bearing — see §3 above).
- The new beta interactables (`beta_today_checklist`,
  `register_status_indicator`) route content-derived text only into plain
  `Label.text` (no BBCode parsing). See §F-S14.
- The new `ModalQueue` autoload is a pure data-structure module — no
  `FileAccess`, no `JSON.parse_string`, no network, no string sinks. The
  payload `Dictionary` it carries is passed by reference between caller and
  panel, so the sinks remain the per-panel `_on_queued_open` implementations
  audited above; the queue itself is not a sink.
- The new `ModalPanel` base class (`game/scripts/ui/modal_panel.gd`) is also
  pure InputFocus stack management — no string sinks, no I/O.
- The `BetaDaySummaryPanel` rewrite groups output into four sections
  (MONEY / STORE PERFORMANCE / THE MARK / REPUTATION). The only BBCode-enabled
  sink in the rewrite remains the `_metrics_label` (§F-S13). The new
  audit-detail rows (`_audit_shelf_label`, `_audit_backroom_label`),
  `_shelf_inventory_label`, `_backroom_inventory_label`, `_customers_helped_label`,
  `_items_stocked_label`, `_sales_completed_label`, `_reputation_label`, and
  `_note_label` are all plain `Label.text`. `shift_note` /
  `hidden_thread_note` from `summary` payload flow into plain `Label.text`
  (lines 268, 273) — no BBCode.
- The HUD `_fp_sentence_label` (new in this working tree;
  `hud.gd:1351–1369`) is a plain `Label.new()` bound to two hardcoded
  constants `_HINT_STOCK_FLOOR` and `_HINT_AWAITING_CUSTOMER`. No new sink.
- The day_cycle_controller dead-guard cleanup (§EH-37) replaces
  `get_node_or_null + has_method + .call(...)` chains with direct typed
  autoload access (`ObjectiveDirector.can_close_day()`,
  `ObjectiveDirector.get_close_blocked_reason()`,
  `HiddenThreadSystemSingleton.finalize_day(day)`,
  `HiddenThreadSystemSingleton.hidden_thread_interactions`,
  `UnlockSystemSingleton.is_unlocked(...)`, `ShiftSystem.get_shift_summary()`).
  This is an error-handling tightening, not a security surface change. The
  `hidden_thread_interactions` read remains clamped at `maxi(_, 0)`.
- The `tutorial_context_system._context_shown_since_entry` flag is a UI
  duplicate-emission suppressor. Prompt text still flows from
  `first.get("prompt_text", "")` into plain Label widgets downstream. No
  validation removed.
- The `content_parser` / `content_schema` reductions removed dead rental /
  sports-card / seasonal-event validators because those content types no
  longer exist (the `season`, `seasonal_event`, `rental_*` schemas have no
  callers post-strip). Active schemas (item, store, customer, fixture,
  upgrade, manager_note) are unchanged.
- The new CI helpers `scripts/setup_godot.sh` and `scripts/run_godot_tests.sh`
  audited: `setup_godot.sh` interpolates `$GODOT_VERSION` (from the
  workflow `env:` block, single source of truth) into a pinned GitHub
  Releases URL, fails loudly via `: "${GODOT_VERSION:?…}"` if the var is
  unset, and runs `set -euo pipefail` throughout. `run_godot_tests.sh`
  uses the workspace-rooted `$GITHUB_WORKSPACE` and quotes every
  interpolation; the long `SHUTDOWN_NOISE_RE` / `EXPECTED_ERROR_RE`
  regexes are matched with `grep -vE`/`grep -E` against tool output only
  (never against user input) and the `tee` target is a `mktemp` file.
  Neither script reads from untrusted external input. The pinned engine
  version (`4.6.2-stable`) is centralized in `.github/workflows/validate.yml`
  `env.GODOT_VERSION`; checksum verification of the downloaded archive
  is a separate, distinct hardening item filed under "Escalations" below.
- The new beta `BetaTodayStatsPanel` and `BetaObjectiveTargetHighlight`
  panels render no `RichTextLabel`-bound content; the stat values are
  `int` -> `str(...)` and the highlight chip is a hardcoded `"▶ E"`
  label. Both confirmed sink-free.

**Inline trust-contract comments added at three BBCode-sink locations
this pass** (see §3 above) — codifies the safety properties that the
prior-pass findings documented only in this report. The two prior pass §1/§2
inline edits remain the durable behavioral hardening; the current pass adds
documentation-style hardening to make those safety contracts visible at the
sink.

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
   beta-content files. Now matches `DataLoader`'s file-size cap (§1). This
   pass also added the same cap to the fifth-and-final JSON loader,
   `ManagerRelationshipManager._load_notes` — see §F-S16 below.
3. **Logs / stdout** — `AuditLog`, `EventLog` (ring buffer + stdout print
   are debug-gated via `OS.is_debug_build()`; the
   `EventBus.event_logged(tag, message)` broadcast fires in every build for
   the player-facing bottom-left log surface), and the
   `OS.is_debug_build()`-gated print sites in
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
   - **`beta_event_log_panel.gd:154–166` (NEW this pass)** — per-row
     `RichTextLabel.bbcode_enabled = true`, bound to
     `EventBus.event_logged(tag, message)`. The `message` argument is now
     `[` → `[lb]`-escaped at the sink (§F-S15) so a future tainted-input
     caller cannot smuggle BBCode tags into the rendered row. `tag` is
     gated through the hardcoded `_TAG_COLORS` token allowlist; unknown
     tags fall through to `_DEFAULT_TAG_COLOR` and render literally.

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

### F-S9 — BetaManagerNotePanel renders BBCode-enabled body via public `show_note(body)` (Acted on this pass — inline trust-contract comment added; behavioral posture unchanged)

`game/scripts/beta/beta_manager_note_panel.gd:53-54, 76-88` (post-edit
working tree). The note panel constructs a `RichTextLabel` with
`bbcode_enabled = true` and exposes a public `show_note(body: String)` API
that now routes through `ModalQueue` (rewritten this branch to extend
`ModalPanel`). Currently called from `beta_day_one_controller.gd:315` with
either `VIC_NOTE_BODY` or the new `VIC_NOTE_DAY2_BODY` — both hardcoded
string-literal constants that deliberately use `[b]…[/b]` BBCode markup.
Future call sites that pass content-derived or save-derived `body` text
would render BBCode tags verbatim — `[url=…]`, `[img=res://…]`, `[color=…]`,
`[font=…]`. The `meta_clicked` signal has no listener wired, so the
URL-click surface is null today, but `[img=]` would attempt to load a
Texture2D from any baked content path at render time.

**This pass — comment-only edit applied at the sink**. Adding pre-emptive
`[` → `[lb]` escaping inside `show_note` would also escape the intentional
`[b]…[/b]` markup in `VIC_NOTE_BODY` / `VIC_NOTE_DAY2_BODY`, so the right
shape — same as the boot error panel from the prior pass — is to escape at
the call site that introduces tainted input. This pass added an inline
`§F-S9` trust-contract docstring at `show_note` (lines 71–85) and a
sink-callout at `_on_queued_open` (lines 86–88) so a future caller
introducing tainted `body` text sees the constraint at the code. See §3.

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

### F-S13 — `BetaDaySummaryPanel` `bbcode_enabled = true` with formatted-integer body, plus `BetaDecisionCardPanel` defensive `bbcode_enabled = false` (Acted on this pass — inline trust-contract comments added at both sinks)

`game/scripts/beta/beta_day_summary_panel.gd:69–77, 213–232` (post-edit
working tree — the panel was rewritten this branch to four sections and
to route through `ModalQueue`). The `_metrics_label` is the only sink in
the rewrite with `bbcode_enabled = true`. It is populated by a hardcoded
`%`-formatted template that binds only int values (`starting_cash`,
`ending_cash`) and one int-derived currency string (`sales_today_str`,
built locally from `cash_delta` via `+$%d` / `-$%d` / `$0`). No caller
strings reach the BBCode template. The `_note_label`,
`_hidden_thread_label`, and all per-row metric labels in sections B/C/D
are plain `Label` — `shift_note` / `hidden_thread_note` from the
`summary` payload render at lines 268 and 273 as plain text. BBCode
injection has no path into the rendered template.

`game/scripts/beta/beta_decision_card_panel.gd:48–58, 72–92`
(post-edit working tree). The decision card's `_body_label` is a
`RichTextLabel` with the *defensively-disabled* flag
`bbcode_enabled = false`. Its `_on_queued_open` binds
`event_data.get("body", "")` from `customer_events.json` content — the
disable flag is what keeps that content from interpreting `[url=…]` /
`[img=res://…]` / `[font=…]` tags at render time. **The disable is
load-bearing for the trust model.** If a future refactor flips the
flag without first escaping `[` → `[lb]` at the binding site, the same
`customer_events.json` content (now or any future content edit) would
suddenly be a live BBCode sink.

**This pass — comment-only edits applied at both sinks.** Added a
`§F-S13` block comment immediately above the `_metrics_label.text =`
binding in `beta_day_summary_panel.gd` recording the
integer-only-or-format-derived constraint, and a matching block comment
at the `_body_label.bbcode_enabled = false` line in
`beta_decision_card_panel.gd` recording that the disable is
load-bearing. Future maintainers binding new fields into the metrics
template, or flipping the decision-card flag, see the trust property
at the code. The canonical hardening if either constraint ever needs
to be relaxed is the `replace("[", "[lb]")` pattern from
`checkout_panel._set_reasoning_text` (checkout_panel.gd:706) and
`haggle_panel`. See §3.

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

### F-S15 — `BetaEventLogPanel._format_row` builds a BBCode-enabled row from `EventBus.event_logged` payloads (Acted on this pass — `[` escape applied at the sink)

`game/scripts/beta/beta_event_log_panel.gd:154–166, 192–217`
(post-edit). The new bottom-left event log surface renders one
`RichTextLabel` per `EventBus.event_logged(tag, message)` emit. The row
has `bbcode_enabled = true` (line 156) and the format helper composes
the row text as
`"[color=#%s]%s[/color] [color=#%s]%s[/color]" % [tag_color, tag, msg_color, message]`.

The only registered emitter today is `EventLog._record` (autoload),
which routes through `_format_message` to a per-action template that
binds integer-, enum-, or `StringName`-derived params (`item_id`,
`state_name`, `modal_id`, `day`, `delta`). All of those source values
are content-authored or code-controlled; none flow from save or user
input. But the panel is the *only* consumer of the BBCode-enabled
row text, and any future caller piping a content-author-typo'd label
or a save-derived string through `EventBus.event_logged` would land
verbatim into a sink that renders `[img=res://…]` / `[url=…]` /
`[font=…]` / `[color=…]` tags.

The durable hardening, matching `checkout_panel._set_reasoning_text`
(§F-129) and `boot._show_error_panel` (prior-pass §1), is to escape
`[` -> `[lb]` on the `message` argument before composing the BBCode
template. The color-format tokens added *after* escape are intentional
BBCode; only the tainted input is escaped. `tag` is intentionally not
escaped: it is keyed off the hardcoded `_TAG_COLORS` Dictionary
(`[STOCK]`, `[CUSTOMER]`, `[OBJECTIVE]`, `[DAY]`, `[MODAL]`, `[STAT]`),
so the only accepted values are developer-controlled constants —
escaping it would alter the raw row text without changing the visible
render (`[lb]STOCK]` renders as `[STOCK]` since `[lb]` is the BBCode
escape glyph for `[`), and the existing `test_beta_event_log_panel.gd`
contract pins the raw row text for the tag-color assertion. An
unrecognized tag still degrades safely: it falls through to
`_DEFAULT_TAG_COLOR` and renders the token literally. The inline
docstring at `_format_row` captures both constraints; future
maintainers see the safety property at the sink.

**Tests after edit:** `test_beta_event_log_panel.gd` 11/11 passing.

### F-S16 — `ManagerRelationshipManager._load_notes` did not enforce the project-wide JSON file-size cap (Acted on this pass — 1-MiB cap added)

`game/autoload/manager_relationship_manager.gd:34–43`
(`MAX_NOTES_FILE_BYTES` const), `581–597` (`_load_notes` cap branch).
The project has five JSON ingest paths:

| Path | File-size cap pre-pass |
|---|---|
| `DataLoader._read_json_file` | `MAX_JSON_FILE_BYTES = 1_048_576` |
| `SaveManager._read_json_file` | `MAX_SAVE_FILE_BYTES` |
| `MainMenu` slot preview reader | `MAX_SAVE_PREVIEW_BYTES` |
| `BetaDayOneController._load_json` | `MAX_JSON_FILE_BYTES = 1_048_576` (prior pass §1) |
| `ManagerRelationshipManager._load_notes` | **none** — closed this pass |

The fifth was the only loader without a cap. `NOTES_PATH` resolves to
`res://game/content/manager/manager_notes.json`, a baked content file
on shipped builds — but on Godot 4.x dev builds `res://` resolves to
the source tree, so a misconfigured CI or a developer-workstation
content-authoring mistake (e.g. a multi-MiB notes file landing during
content iteration) would silently inflate the parser working set
before this edit.

Fix mirrors the prior-pass §1 pattern on `BetaDayOneController._load_json`:
add a `MAX_NOTES_FILE_BYTES = 1_048_576` constant (matching `DataLoader`),
and a pre-`get_as_text()` length gate that closes the file and
escalates via `push_error` on overflow. The existing failure-path
return shape (`_notes_loaded` stays false → morning-note feature
disabled) is preserved so the chain still flows when content is
missing or malformed.

**Tests after edit:** `test_manager_relationship_manager.gd` 28/28
passing; `test_morning_note.gd` 5/5 passing.

## §3 — Inline trust-contract comments at BBCode sinks (this pass)

The three modal-panel refactors on the current working tree moved the
sink-binding from public setters into `_on_queued_open(payload)` hooks. The
prior-pass findings §F-S9 / §F-S13 documented the trust property that
justifies each BBCode-enabled (or defensively-disabled) sink only in this
report. A future maintainer adding a fourth caller — or flipping the
`bbcode_enabled = false` flag in `BetaDecisionCardPanel` — could regress
the safety property without seeing the constraint at the binding site.

This pass adds inline comments at the three sink locations so the trust
contract is visible at the code, not only in this audit report. The
comments match the `§F-129` self-referencing pattern already established in
`checkout_panel.gd` and `haggle_panel.gd` (which escape `[` → `[lb]` and
document why at the sink). No runtime behavior is changed; tests remain
green (see Verification below).

`game/scripts/beta/beta_manager_note_panel.gd` — appended trust-contract
docstring to `show_note(body: String)` (lines 71–85) and a one-line
sink-callout to `_on_queued_open` (lines 86–88). The docstring names the
two current hardcoded callers and prescribes the call-site escape pattern
required of any future tainted caller.

`game/scripts/beta/beta_day_summary_panel.gd` — added a `§F-S13` block
comment immediately above the `_metrics_label.text = ...` binding
(lines 213–224) stating that the format template is a hardcoded literal,
the three bound values are int / int-currency-string / int, and that any
future field added to the template must stay integer-or-format-derived
(or route to `_note_label` plain `Label` instead).

`game/scripts/beta/beta_decision_card_panel.gd` — added a `§F-S13` block
comment at the `_body_label.bbcode_enabled = false` assignment
(lines 48–58) recording that BBCode must stay off and that flipping the
flag without first escaping the binding site exposes `[url=…]` /
`[img=res://…]` / `[font=…]` injection from content-author error or
tampered content files. The disable is now load-bearing for the trust
model and the comment names it.

## Escalations

### CI setup_godot.sh — no SHA256 verification on the downloaded Godot archive

`scripts/setup_godot.sh:13–15` downloads
`Godot_v${GODOT_VERSION}_linux.x86_64.zip` from
`github.com/godotengine/godot/releases/download/...` over HTTPS, unzips
it, and `chmod +x`s the binary into `/usr/local/bin/godot`. The TLS
handshake covers transport, but if the GitHub releases CDN were
compromised or the release asset were swapped, CI runs would silently
adopt a tampered engine binary. The durable hardening is to pin a
SHA256 checksum next to `GODOT_VERSION` in
`.github/workflows/validate.yml` (or in the script) and run
`sha256sum -c` on the downloaded zip before unzipping.

**Why not acted on here:** the fix is two-place — both the workflow
env and the script — and requires a checksum value that ships with the
upstream Godot release (not derivable from this repo alone). It is a
real architectural decision (which upstream attestation to trust;
whether to pin per-platform builds; whether to mirror the binary
internally) rather than a local edit. **Smallest concrete next
action:** look up the SHA256 published with the Godot 4.6.2-stable
Linux release on github.com/godotengine/godot, add it as
`GODOT_SHA256` in the workflow env block alongside `GODOT_VERSION`,
and add `echo "${GODOT_SHA256}  /tmp/godot.zip" | sha256sum -c -` in
`setup_godot.sh` between the `wget` and the `unzip` lines. **Who/what
unblocks it:** project owner deciding on the trust model (mirror vs.
upstream-checksum-pin); no code change blocked on tooling.

### BetaDebugOverlay (F2) / `_print_interactable_debug_list` ship in release builds (carry-over from F-S8)

Unchanged from the prior pass. The F8 dump and `_print_interactable_debug_list`
are not `OS.is_debug_build()`-gated and emit internal FSM stage names
to stdout in shipped builds. Trust posture is unchanged: a single-player
offline desktop game treats stdout as developer diagnostics. The
durable fix is a one-line edit in `_ensure_panels` to gate the
overlay-spawn behind `OS.is_debug_build()` once the team decides to
ship the project as a polished production release rather than a beta.

## Verification

After **this pass's two safe inline edits** (BBCode escape in
`beta_event_log_panel._format_row`; 1-MiB size cap in
`manager_relationship_manager._load_notes`), the directly-affected
test suites are green:

- `test_beta_event_log_panel.gd` — 11/11 passing (0.162s, 19 asserts).
- `test_manager_relationship_manager.gd` — 28/28 passing (0.024s, 39
  asserts).
- `test_morning_note.gd` — 5/5 passing (0.035s, 7 asserts).
- Full beta suite (`-gselect=test_beta`) — **184/184 passing**
  (9.676s, 637 asserts). The trailing `ERROR: [ModalPanel] … freed
  with unreleased InputFocus push — auto-popping` lines are documented
  fail-loud paths covered by `scripts/run_godot_tests.sh`'s
  `EXPECTED_ERROR_RE` allowlist and are intentional fixture teardown
  artifacts, not regressions.

The prior pass's section below documents the verification posture for
earlier passes, which remain intact:

After the **prior** pass's three inline-comment edits, the
directly-affected test suites were green:

- `test_beta_manager_note_panel.gd` — 16/16 passing (0.448s, 27 asserts)
- `test_beta_day_summary*` — 26/26 passing across `test_beta_day_summary_modal_focus`
  and `test_beta_day_summary_sections` (0.046s, 129 asserts)
- `test_modal_queue*` — 30/30 passing across `test_modal_queue` and
  `test_modal_queue_panel_routing` (0.028s, 145 asserts)

The three edited files contain only comment-only additions (docstrings
and inline comments), so no GDScript syntax surface changed; the diagnostic
`--check-only` error on these files remains the standard autoload-not-loaded
limitation noted in the prior pass.

Prior-pass test invocation (`-gselect=test_beta`) still reports the same
74/74 beta-suite baseline, since this pass added no new test files and
the directly-edited files are exercised by the test scripts above.

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

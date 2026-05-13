#!/usr/bin/env bash
## Run the GUT suite headlessly, filter engine-shutdown noise, and gate the
## job on GUT's own pass summary plus an allowlist for known push_error()
## lines. Exports $GUT_OUTPUT_FILE to $GITHUB_ENV so a follow-up artifact
## upload step can grab the raw log on failure.
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set (CI provides this; for local use, export the repo root)}"

GUT_OUTPUT_FILE="$(mktemp)"
echo "GUT_OUTPUT_FILE=$GUT_OUTPUT_FILE" >> "${GITHUB_ENV:-/dev/null}"

# Strip engine-shutdown noise emitted *after* GUT finishes, before it reaches
# the log or the CI display. In headless mode the renderer-cleanup pass runs
# while autoload-held UI (AuditOverlay, ErrorBanner, ObjectiveRail,
# InteractionPrompt, FailCard) is still alive, so RIDs for Canvas /
# CanvasItem / DummyTexture / Font / cached resources are reported as
# "leaked at exit." These messages do not indicate test failures and are not
# actionable from GDScript — filter both the headers and their
# `     at: ...` continuation lines so the log shows test signal only.
SHUTDOWN_NOISE_RE='^WARNING: [0-9]+ RIDs? of type "[^"]+" (was|were) leaked\.$|^WARNING: ObjectDB instances leaked at exit|^ERROR: [0-9]+ RID allocations of type .+ were leaked at exit\.$|^ERROR: [0-9]+ resources still in use at exit|^ +at: _free_rids \(servers/rendering/renderer_canvas_cull|^ +at: cleanup \(core/object/object\.cpp|^ +at: clear \(core/io/resource\.cpp'

godot --path "$GITHUB_WORKSPACE" --headless \
	--script res://addons/gut/gut_cmdln.gd -- \
	-gconfig=res://.gutconfig.json -gexit \
	2>&1 | grep -vE "$SHUTDOWN_NOISE_RE" | tee "$GUT_OUTPUT_FILE" || true

# Trust GUT's own summary for pass/fail. On Linux, headless Godot exits
# non-zero whenever autoload-held resources leak at shutdown (unavoidable
# engine cleanup), so Godot's exit code is unreliable.
if ! grep -q "All tests passed" "$GUT_OUTPUT_FILE"; then
	echo "::error::GUT reported test failures (no 'All tests passed' summary found)."
	exit 1
fi

# Catch push_error() calls which GDScript emits as "ERROR:" lines but don't
# fail assertions. Engine-shutdown ERROR: noise is already stripped by
# SHUTDOWN_NOISE_RE above, so the exclusion regex below only needs to cover:
#   1. Errors emitted by tests that intentionally exercise fail-loud paths
#      whose `push_error` is a documented production behavior (and is itself
#      asserted by the validate_*.sh scripts: StoreDirector, ContentRegistry
#      uniqueness / CameraAuthority, StoreRegistry).
#   2. Engine-internal teardown noise that fires after a passing assertion
#      (autofree race on await-suspended tests, settings lambda capture
#      during malformed-config reload).
#   3. ReturnsSystem _debit_store_account fail-loud — the refund trust-delta
#      fixture (test_returns_system.gd) intentionally omits EconomySystem,
#      exercising the documented Tier-1 init regression guard at
#      game/autoload/returns_system.gd.
#   4. Dummy-renderer "Parameter material is null" — the headless renderer
#      emits this from material_storage.cpp during autofree of 3D scenes
#      (mesh nodes without materials). Engine-internal, not actionable from
#      GDScript.
#   5. ModalPanel guard paths — test_modal_panel_base.gd and
#      test_inventory_panel_focus.gd intentionally exercise the three
#      documented fail-loud guards: double-open, freed-while-open auto-pop,
#      and pop-when-not-on-top sibling-frame protection.
EXPECTED_ERROR_RE='ContentRegistry: duplicate (resource|entry) ID|ContentRegistry: alias .* maps to both|\[StoreRegistry\] (unknown store_id|empty store_id|duplicate register store_id)|\[StoreDirector\] .* — unknown store_id|\[CameraAuthority\] (invalid camera|not a Camera2D/Camera3D|expected exactly 1 current camera)|Object is locked and can.t be freed\.|Lambda capture at index 0 was freed\.|ReturnsSystem: _debit_store_account skipped|Parameter "material" is null\.|\[ModalPanel\] .* freed with unreleased InputFocus push — auto-popping|\[ModalPanel\] .*: open\(\) called twice without close\(\) — skipping push|\[ModalPanel\] .*: expected CTX_MODAL on top, got .* — leaving stack untouched'
UNEXPECTED_ERRORS=$(grep "^ERROR:" "$GUT_OUTPUT_FILE" | grep -vE "$EXPECTED_ERROR_RE" || true)
if [ -n "$UNEXPECTED_ERRORS" ]; then
	ERROR_COUNT=$(echo "$UNEXPECTED_ERRORS" | wc -l | tr -d ' ')
	echo ""
	echo "::error::GUT run produced $ERROR_COUNT push_error() call(s). Tests must not emit errors."
	echo "$UNEXPECTED_ERRORS"
	exit 1
fi

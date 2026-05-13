## StoreRegistry — sole owner of the `store_id -> StoreRegistryEntry` map
## (ISSUE-019, ownership.md row "store catalog / id resolution").
##
## Pure lookup table. Does NOT load scenes, does NOT instantiate controllers,
## does NOT cache PackedScenes. StoreDirector (ISSUE-008) consumes
## `resolve(store_id)` as the first step of `enter_store`; a null return is
## converted into a FAIL result there.
##
## Unknown ids fail loud: `push_error` + AuditLog.fail + return null. There is
## no silent empty-string fallback — DESIGN.md §1.2 ("Fail Loud, Never Grey").
extends Node

const CHECKPOINT_RESOLVE: StringName = &"store_registry_resolve"

var _entries: Dictionary = {}


func _ready() -> void:
	_seed_from_content_registry()
	# §EH-38 (docs/audits/error-handling-report.md): EventBus is an autoload
	# (project.godot) and `content_loaded` is owner-declared on it
	# (event_bus.gd). The prior `_autoload("EventBus")` walker + has_signal
	# guard was the §EH-13/§EH-15 dead-guard shape — a rename of the signal
	# would have silently left StoreRegistry seeded only with what was
	# available at boot, dropping any stores DataLoader added later. Typed
	# autoload + typed signal makes the rename fail parse.
	EventBus.content_loaded.connect(_seed_from_content_registry)


## Registers an entry. Asserts on null/empty inputs (programmer error) and
## fails loud on duplicate ids (push_error + AuditLog.fail, no overwrite) —
## the registry is the single source of truth, silent overwrites would let
## two callers disagree on what a store_id means. Returns true on success.
func register(entry: StoreRegistryEntry) -> bool:
	assert(entry != null, "StoreRegistry.register: null entry")
	assert(entry.store_id != &"", "StoreRegistry.register: empty store_id")
	assert(entry.scene_path != "", "StoreRegistry.register: empty scene_path for %s" % entry.store_id)
	if _entries.has(entry.store_id):
		_fail("duplicate register store_id=%s (kept original)" % entry.store_id)
		return false
	_entries[entry.store_id] = entry
	return true


## Returns the entry for `store_id`, or null if unknown. Unknown ids emit
## `push_error` + AuditLog.fail so the failure is observable in headless CI.
func resolve(store_id: StringName) -> StoreRegistryEntry:
	if store_id == &"":
		_fail("empty store_id")
		return null
	if not _entries.has(store_id):
		_fail("unknown store_id: %s" % store_id)
		return null
	var entry: StoreRegistryEntry = _entries[store_id]
	_pass("store_id=%s path=%s" % [store_id, entry.scene_path])
	return entry


## Convenience wrapper used by callers that only need the scene path (e.g.
## StoreDirector's first-step lookup, contract tests). Returns "" when the
## id is unknown — the underlying `resolve()` already emits push_error +
## AuditLog.fail, so the empty string is just a no-silent-throw signal.
func resolve_scene(store_id: StringName) -> String:
	var entry: StoreRegistryEntry = resolve(store_id)
	if entry == null:
		return ""
	return entry.scene_path


## Returns true if `store_id` is registered. Does not log — for callers that
## want a silent existence probe (e.g. UI gating).
func has(store_id: StringName) -> bool:
	return _entries.has(store_id)


## All registered ids, for iteration (mall hub card rendering, contract tests).
func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _entries.keys():
		out.append(k as StringName)
	return out


## Test seam — clears the registry. Tests that exercise registration paths
## should call this in `before_each` and re-seed as needed.
func _reset_for_tests() -> void:
	_entries.clear()


## Seeds the registry from ContentRegistry (the SSOT per
## docs/decisions/0007-remove-sneaker-citadel.md).
## Runs after ContentRegistry has loaded `store_definitions.json`; if content
## isn't ready yet the registry is left empty — callers fail loud through
## `resolve()` rather than returning stale data.
##
## §EH-38 (docs/audits/error-handling-report.md): ContentRegistry is an autoload
## (project.godot); get_all_store_ids/get_scene_path/get_display_name are owner-
## declared methods (content_registry.gd:232/108/91). The prior triple
## `has_method` guard cluster was the §EH-31-shape dead-guard pattern — if any
## of the three names ever changed, this seeder would silently drop the
## affected mall cards (or in the case of get_all_store_ids, ship a registry
## empty for the rest of the run). Typed access makes a rename fail parse.
func _seed_from_content_registry() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	for store_id: StringName in ids:
		if _entries.has(store_id):
			continue
		var scene_path: String = ContentRegistry.get_scene_path(store_id)
		if scene_path.is_empty():
			continue
		var display_name: String = ContentRegistry.get_display_name(store_id)
		if display_name.is_empty():
			display_name = String(store_id)
		register(StoreRegistryEntry.new(
			store_id, scene_path, null, display_name, {}
		))


func _pass(detail: String) -> void:
	# §EH-38: typed autoload — AuditLog.pass_check is declared at
	# audit_log.gd:21. The prior `_audit_log()` walker + has_method guard pair
	# was the §EH-13/§EH-15 dead-guard shape. A rename now fails GDScript parse
	# rather than silently skipping the structured AUDIT PASS record that
	# headless CI scans.
	AuditLog.pass_check(CHECKPOINT_RESOLVE, detail)


func _fail(reason: String) -> void:
	# §EH-38: typed autoload — see _pass above. fail_check is declared at
	# audit_log.gd:39. Without the typed call the failure would have been
	# limited to the push_error line (which CI catches as ^ERROR) but the
	# structured AUDIT FAIL record — the actionable bit for incident review —
	# would have silently dropped.
	push_error("[StoreRegistry] %s" % reason)
	AuditLog.fail_check(CHECKPOINT_RESOLVE, reason)

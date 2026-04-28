## ISSUE-004: state-driven per-store tutorial layer.
##
## Subscribes to EventBus.store_entered / store_exited / day_started /
## objective_changed and emits tutorial_context_entered with the first-step
## prompt for the store the player just walked into. The tutorial content is
## loaded from `res://game/content/tutorial_contexts.json` and keyed by the
## StoreDefinition.tutorial_context_id resolved through ContentRegistry.
##
## This system intentionally sits alongside the legacy `TutorialSystem` (which
## drives the global first-play flow); it is focused on the per-store
## contextual layer that answers "what can I do now in *this* store?".
extends Node

const CONTENT_PATH: String = "res://game/content/tutorial_contexts.json"

var active_store_id: StringName = &""
var active_context_id: StringName = &""

var _contexts: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	_load_contexts()
	_connect_signals()


## Loads tutorial contexts from JSON. Exposed for tests.
func reload() -> void:
	_contexts.clear()
	_loaded = false
	_load_contexts()


## Returns the parsed context dictionary for an id, or `{}` if unknown.
func get_context(context_id: StringName) -> Dictionary:
	var key: String = String(context_id)
	if not _contexts.has(key):
		return {}
	return _contexts[key] as Dictionary


## Returns the ordered list of step dictionaries for a context, or `[]`.
func get_steps(context_id: StringName) -> Array:
	var context: Dictionary = get_context(context_id)
	var steps: Variant = context.get("steps", [])
	if steps is Array:
		return steps as Array
	return []


## Returns the first step dictionary for a context, or `{}`.
func get_first_step(context_id: StringName) -> Dictionary:
	var steps: Array = get_steps(context_id)
	if steps.is_empty():
		return {}
	var first: Variant = steps[0]
	if first is Dictionary:
		return first as Dictionary
	return {}


## Returns the ids of every context defined in the JSON.
func get_context_ids() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _contexts.keys():
		out.append(String(key))
	return out


## Clears the active context. Tests may call this between cases.
func clear_active_context() -> void:
	if active_store_id == &"" and active_context_id == &"":
		return
	active_store_id = &""
	active_context_id = &""
	EventBus.tutorial_context_cleared.emit()


## Returns false during states where tutorial prompts must not render.
## Guards both signal emission and external render decisions: tutorial_context_entered
## never fires (and consumer UIs should not render) in MAIN_MENU, MALL_OVERVIEW,
## DAY_SUMMARY, or while a modal has input focus.
func is_tutorial_rendering_allowed() -> bool:
	var state: GameManager.State = GameManager.current_state
	if (
		state == GameManager.State.MAIN_MENU
		or state == GameManager.State.MALL_OVERVIEW
		or state == GameManager.State.DAY_SUMMARY
	):
		return false
	if InputFocus.current() == InputFocus.CTX_MODAL:
		return false
	return true


func _load_contexts() -> void:
	if _loaded:
		return
	var parsed: Variant = DataLoader.load_json(CONTENT_PATH)
	if not (parsed is Dictionary):
		push_error(
			"TutorialContextSystem: failed to load '%s' as Dictionary"
			% CONTENT_PATH
		)
		_loaded = true
		return
	var root: Dictionary = parsed as Dictionary
	var raw: Variant = root.get("tutorial_contexts", {})
	if not (raw is Dictionary):
		push_error(
			"TutorialContextSystem: '%s' missing 'tutorial_contexts' object"
			% CONTENT_PATH
		)
		_loaded = true
		return
	var contexts: Dictionary = raw as Dictionary
	for key: Variant in contexts:
		var ctx: Variant = contexts[key]
		if not (ctx is Dictionary):
			push_warning(
				"TutorialContextSystem: context '%s' is not an object" % key
			)
			continue
		_contexts[String(key)] = ctx
	_loaded = true


func _connect_signals() -> void:
	if not EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.connect(_on_store_entered)
	if not EventBus.store_exited.is_connected(_on_store_exited):
		EventBus.store_exited.connect(_on_store_exited)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)


func _on_store_entered(store_id: StringName) -> void:
	if store_id == &"":
		return
	if not is_tutorial_rendering_allowed():
		return
	var route: Dictionary = ContentRegistry.get_store_route(store_id)
	if route.is_empty():
		return
	var context_id: StringName = StringName(
		String(route.get("tutorial_context_id", ""))
	)
	if context_id == &"":
		push_warning(
			"TutorialContextSystem: store '%s' has no tutorial_context_id" % store_id
		)
		return
	if not _contexts.has(String(context_id)):
		push_error(
			"TutorialContextSystem: no tutorial context defined for '%s' (store '%s')"
			% [context_id, store_id]
		)
		return
	active_store_id = store_id
	active_context_id = context_id
	var first: Dictionary = get_first_step(context_id)
	var text: String = String(first.get("prompt_text", ""))
	EventBus.tutorial_context_entered.emit(store_id, context_id, text)


func _on_store_exited(_store_id: StringName) -> void:
	clear_active_context()


func _on_day_started(_day: int) -> void:
	# Re-emit the current context's first-step text when a fresh day begins
	# inside a store, so the rail reflects "what can I do now?" without
	# requiring a re-entry.
	if active_context_id == &"":
		return
	if not is_tutorial_rendering_allowed():
		return
	var first: Dictionary = get_first_step(active_context_id)
	var text: String = String(first.get("prompt_text", ""))
	EventBus.tutorial_context_entered.emit(active_store_id, active_context_id, text)

## Verifies the retro games checkout counter advertises only an
## informational label rather than a player-driven verb. Day 1 customers
## auto-complete checkout via PlayerCheckout.process_transaction(); the
## counter has no E-press handler, so any "Press E to checkout customer"
## cue would be a dead prompt. The display_name still mirrors register
## queue size ("Customer at checkout" vs "No customer waiting") so the
## player can still tell the counter is busy, but prompt_text stays empty
## in both states so InteractionRay._build_action_label renders the bare
## label without an "Press E" hint.
extends GutTest


const _SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const _STORE_ID: StringName = &"retro_games"

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(_SCENE_PATH)
	assert_not_null(scene, "Retro Games scene should load")
	_root = scene.instantiate() as Node3D
	add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


func before_each() -> void:
	# Reset to the idle (no-customer) state before each assertion so prior
	# tests cannot leak a "customer waiting" prompt forward.
	EventBus.queue_advanced.emit(0)


# ── No-customer state ─────────────────────────────────────────────────────


func test_idle_register_shows_no_customer_label_after_store_entered() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	var counter: Interactable = _checkout_counter_interactable()
	assert_not_null(
		counter, "checkout_counter/Interactable must exist in retro_games scene"
	)
	assert_eq(
		counter.display_name, "No customer waiting",
		"Idle register must read 'No customer waiting' on store entry"
	)
	assert_eq(
		counter.prompt_text, "",
		"Idle register must clear prompt_text so InteractionPrompt skips the E cue"
	)


func test_idle_register_label_drops_press_e_cue() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	var counter: Interactable = _checkout_counter_interactable()
	var label: String = _build_action_label(counter)
	assert_eq(
		label, "No customer waiting",
		"Idle prompt must render the bare label without a 'Press E' hint"
	)


# ── Customer-waiting state ────────────────────────────────────────────────


func test_customer_arrival_swaps_label_without_press_e_cue() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.queue_advanced.emit(1)
	var counter: Interactable = _checkout_counter_interactable()
	assert_eq(
		counter.display_name, "Customer at checkout",
		"Active register must show 'Customer at checkout' when a customer queues"
	)
	assert_eq(
		counter.prompt_text, "",
		"Active register must keep prompt_text empty (no player-driven verb)"
	)


func test_customer_waiting_label_renders_without_press_e_cue() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.queue_advanced.emit(1)
	var counter: Interactable = _checkout_counter_interactable()
	var label: String = _build_action_label(counter)
	assert_eq(
		label, "Customer at checkout",
		"Active prompt must render the bare label — no 'Press E' cue, "
		+ "since Day 1 customers auto-complete checkout"
	)


# ── State transitions ─────────────────────────────────────────────────────


func test_prompt_reverts_when_queue_empties() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.queue_advanced.emit(2)
	EventBus.queue_advanced.emit(0)
	var counter: Interactable = _checkout_counter_interactable()
	assert_eq(
		counter.display_name, "No customer waiting",
		"Prompt must revert when the register queue empties"
	)
	assert_eq(counter.prompt_text, "")


func test_prompt_remains_active_while_queue_not_empty() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.queue_advanced.emit(3)
	# One customer just got served; queue still has two waiting customers.
	EventBus.queue_advanced.emit(2)
	var counter: Interactable = _checkout_counter_interactable()
	assert_eq(
		counter.display_name, "Customer at checkout",
		"Prompt must stay active while the queue still has customers"
	)
	assert_eq(counter.prompt_text, "")


# ── Helpers ───────────────────────────────────────────────────────────────


func _checkout_counter_interactable() -> Interactable:
	return (
		_root.get_node_or_null("checkout_counter/Interactable") as Interactable
	)


## Mirrors InteractionRay._build_action_label so tests verify the same label
## the player would see in the InteractionPrompt HUD.
func _build_action_label(target: Interactable) -> String:
	var verb: String = target.prompt_text.strip_edges()
	var target_name: String = target.display_name.strip_edges()
	if verb.is_empty() and target_name.is_empty():
		return ""
	if target_name.is_empty():
		return "Press E to %s" % verb.to_lower()
	if verb.is_empty():
		return target_name
	return "%s — Press E to %s" % [target_name, verb.to_lower()]

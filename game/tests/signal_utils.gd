## Shared signal helpers for both `game/tests` and top-level `tests/` suites.
extends RefCounted


static func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

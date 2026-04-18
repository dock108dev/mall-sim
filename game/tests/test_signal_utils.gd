## Shared signal helpers for GUT tests that need defensive cleanup.
extends RefCounted


static func safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)

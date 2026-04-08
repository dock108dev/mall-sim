"""State persistence for AIDLC runs. Handles save, load, checkpoint, resume."""

import json
import logging
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

from .models import RunState, RunStatus, RunPhase


def generate_run_id(config_name: str) -> str:
    """Generate a unique run ID from config name and timestamp."""
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    base = config_name.replace(".json", "").replace(" ", "_")
    return f"{base}_{ts}"


def save_state(state: RunState, run_dir: Path) -> Path:
    """Save current run state to disk atomically."""
    state.last_updated = datetime.now(timezone.utc).isoformat()
    state_path = run_dir / "state.json"
    tmp_path = state_path.with_suffix(".json.tmp")
    with open(tmp_path, "w") as f:
        json.dump(state.to_dict(), f, indent=2)
    os.replace(tmp_path, state_path)
    return state_path


def load_state(run_dir: Path) -> RunState:
    """Load run state from disk, falling back to latest checkpoint if corrupted."""
    logger = logging.getLogger("aidlc")
    state_path = run_dir / "state.json"

    # Try primary state file
    if state_path.exists():
        try:
            with open(state_path) as f:
                data = json.load(f)
            return RunState.from_dict(data)
        except (json.JSONDecodeError, KeyError) as e:
            logger.warning(f"state.json corrupted ({e}), trying checkpoint recovery")

    # Fall back to latest numbered checkpoint
    cp_dir = run_dir / "checkpoints"
    if cp_dir.exists():
        checkpoints = sorted(cp_dir.glob("checkpoint_*.json"), reverse=True)
        for cp_path in checkpoints:
            try:
                with open(cp_path) as f:
                    data = json.load(f)
                logger.warning(f"Recovered state from {cp_path.name}")
                return RunState.from_dict(data)
            except (json.JSONDecodeError, KeyError):
                continue

    raise FileNotFoundError(f"No valid state file or checkpoint at {run_dir}")


def checkpoint(state: RunState, run_dir: Path) -> None:
    """Create a numbered checkpoint snapshot of current state."""
    state.checkpoint_count += 1
    cp_dir = run_dir / "checkpoints"
    cp_dir.mkdir(exist_ok=True)
    cp_path = cp_dir / f"checkpoint_{state.checkpoint_count:04d}.json"
    tmp_path = cp_path.with_suffix(".json.tmp")
    state.last_updated = datetime.now(timezone.utc).isoformat()
    with open(tmp_path, "w") as f:
        json.dump(state.to_dict(), f, indent=2)
    os.replace(tmp_path, cp_path)
    # Also update the main state file
    save_state(state, run_dir)


def find_latest_run(runs_dir: Path, config_name: str) -> Path | None:
    """Find the most recent run directory for a given config."""
    base = config_name.replace(".json", "")
    candidates = sorted(
        [d for d in runs_dir.iterdir() if d.is_dir() and d.name.startswith(base)],
        key=lambda d: d.stat().st_mtime,
        reverse=True,
    )
    for d in candidates:
        state_path = d / "state.json"
        if state_path.exists():
            return d
    return None

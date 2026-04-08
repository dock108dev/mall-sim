"""Config loader for AIDLC runner. Reads JSON config files."""

import json
import os
from pathlib import Path
from typing import Any

# Framework root and project root
AIDLC_ROOT = Path(__file__).parent
PROJECT_ROOT = AIDLC_ROOT.parent.parent
CONFIGS_DIR = AIDLC_ROOT / "configs"
RUNS_DIR = AIDLC_ROOT / "runs"
REPORTS_DIR = AIDLC_ROOT / "reports"

# Default config
DEFAULT_CONFIG = "mall_sim_planning_40h.json"

# Required config keys
REQUIRED_KEYS = [
    "run_name",
    "project_name",
    "run_type",
    "duration_budget_hours",
    "checkpoint_interval_minutes",
]


def load_config(config_name: str = DEFAULT_CONFIG) -> dict:
    """Load and validate a config file from the configs directory."""
    config_path = CONFIGS_DIR / config_name
    if not config_path.exists():
        raise FileNotFoundError(f"Config not found: {config_path}")

    with open(config_path) as f:
        config = json.load(f)

    # Validate required keys
    missing = [k for k in REQUIRED_KEYS if k not in config]
    if missing:
        raise ValueError(f"Config missing required keys: {missing}")

    # Resolve paths relative to project root
    config["_project_root"] = str(PROJECT_ROOT)
    config["_aidlc_root"] = str(AIDLC_ROOT)
    config["_config_path"] = str(config_path)

    return config


def get_project_path(config: dict, relative_path: str) -> Path:
    """Resolve a path relative to the project root."""
    return Path(config["_project_root"]) / relative_path


def get_run_dir(config: dict, run_id: str) -> Path:
    """Get the directory for a specific run."""
    run_dir = RUNS_DIR / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_dir


def get_reports_dir(config: dict, run_id: str) -> Path:
    """Get the reports directory for a specific run."""
    report_dir = REPORTS_DIR / run_id
    report_dir.mkdir(parents=True, exist_ok=True)
    return report_dir

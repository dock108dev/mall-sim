"""Logging for AIDLC runner. Console + file logging with structured output."""

import logging
import sys
from datetime import datetime
from pathlib import Path


def setup_logger(run_id: str, log_dir: Path, verbose: bool = False) -> logging.Logger:
    """Create a logger that writes to both console and run-specific log file."""
    logger = logging.getLogger(f"aidlc.{run_id}")
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    # File handler — captures everything
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"{run_id}.log"
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    ))
    logger.addHandler(fh)

    # Console handler — info+ unless verbose
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.DEBUG if verbose else logging.INFO)
    ch.setFormatter(logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%H:%M:%S",
    ))
    logger.addHandler(ch)

    # Error-only file for quick scanning
    err_file = log_dir / f"{run_id}.errors.log"
    eh = logging.FileHandler(err_file, encoding="utf-8")
    eh.setLevel(logging.ERROR)
    eh.setFormatter(logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    ))
    logger.addHandler(eh)

    return logger


def log_checkpoint(logger: logging.Logger, state_dict: dict) -> None:
    """Log a human-readable checkpoint summary."""
    elapsed_h = state_dict.get('elapsed_seconds', 0) / 3600
    wall_h = state_dict.get('wall_clock_seconds', 0) / 3600
    logger.info("=" * 60)
    logger.info("CHECKPOINT")
    logger.info(f"  Status: {state_dict.get('status')}")
    logger.info(f"  Phase: {state_dict.get('phase')}")
    logger.info(f"  Elapsed (Claude): {elapsed_h:.1f}h")
    logger.info(f"  Elapsed (wall):   {wall_h:.1f}h")
    logger.info(f"  Cycles: {state_dict.get('cycle_count', 0)}")
    logger.info(f"  Actions applied: {state_dict.get('actions_applied', 0)}")
    logger.info(f"  Files created: {state_dict.get('files_created', 0)}")
    logger.info(f"  Issues created: {state_dict.get('issues_created', 0)}")
    logger.info(f"  Artifacts: {len(state_dict.get('created_artifacts', []))}")
    logger.info("=" * 60)

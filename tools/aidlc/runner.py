"""Main runner for AIDLC planning sessions.

Architecture:
    The runner operates in a frontier-based planning loop:
    1. Assess the planning frontier (what needs work)
    2. Build a context-rich prompt with frontier + game design + universe state
    3. Claude proposes structured actions (create files, issues, update deps, etc.)
    4. Runner parses, validates, and applies actions to the repo
    5. Repeat until budget exhausted or frontier is clear

    Near the end of the budget, the runner enters finalization mode where
    only consolidation and cleanup actions are permitted.

Usage:
    python -m tools.aidlc.runner                          # default config
    python -m tools.aidlc.runner --config <name>.json     # specific config
    python -m tools.aidlc.runner --resume                 # resume latest run
    python -m tools.aidlc.runner --dry-run                # dry run (no Claude calls)
"""

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from .config import load_config, get_run_dir, get_reports_dir, RUNS_DIR, PROJECT_ROOT
from .models import RunState, RunStatus, RunPhase
from .state_manager import generate_run_id, save_state, load_state, checkpoint, find_latest_run
from .logger import setup_logger, log_checkpoint
from .scope_guard import ScopeGuard
from .claude_cli import ClaudeCLI
from .prompt_builder import PromptBuilder
from .frontier import FrontierAssessor
from .schemas import parse_planning_output
from .apply import ActionApplier
from .validators import validate_pre_launch, validate_checkpoint
from .reporting import generate_run_report, generate_checkpoint_summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="AIDLC Planning Runner for mall-sim",
        prog="python -m tools.aidlc.runner",
    )
    parser.add_argument(
        "--config",
        default="mall_sim_planning_40h.json",
        help="Config file name (in tools/aidlc/configs/)",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume the most recent run for this config",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate run without making Claude CLI calls",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable debug-level console logging",
    )
    return parser.parse_args()


def init_run(config: dict, resume: bool, dry_run: bool) -> tuple[RunState, Path]:
    """Initialize or resume a run. Returns (state, run_dir)."""
    if dry_run:
        config["dry_run"] = True

    if resume:
        run_dir = find_latest_run(RUNS_DIR, config.get("run_name", ""))
        if run_dir is None:
            print("No previous run found to resume. Starting new run.")
            resume = False
        else:
            state = load_state(run_dir)
            if state.status in (RunStatus.COMPLETE, RunStatus.FAILED):
                print(f"Previous run {state.run_id} is {state.status.value}. Starting new run.")
                resume = False
            else:
                print(f"Resuming run {state.run_id} (status: {state.status.value})")
                # Ensure output dirs exist on resume
                (run_dir / "claude_outputs").mkdir(exist_ok=True)
                return state, run_dir

    # New run
    run_id = generate_run_id(config.get("run_name", "planning"))
    run_dir = get_run_dir(config, run_id)
    state = RunState(
        run_id=run_id,
        config_name=config.get("run_name", "unknown"),
        budget_seconds=config.get("duration_budget_hours", 40) * 3600,
    )
    state.started_at = datetime.now(timezone.utc).isoformat()
    save_state(state, run_dir)

    # Create output logging directory
    (run_dir / "claude_outputs").mkdir(exist_ok=True)

    # Save config snapshot in run dir
    with open(run_dir / "config_snapshot.json", "w") as f:
        serializable = {k: v for k, v in config.items() if not k.startswith("_")}
        json.dump(serializable, f, indent=2)

    return state, run_dir


def run_validation(
    state: RunState,
    scope_guard: ScopeGuard,
    project_root: Path,
    logger,
) -> list[str]:
    """Run validation checks and return issues found."""
    issues = validate_checkpoint(state, scope_guard, project_root)
    for issue in issues:
        logger.warning(f"Validation issue: {issue}")
    state.validation_results.extend(issues)
    return issues


def planning_cycle(
    state: RunState,
    run_dir: Path,
    config: dict,
    scope_guard: ScopeGuard,
    cli: ClaudeCLI,
    prompt_builder: PromptBuilder,
    applier: ActionApplier,
    logger,
    project_root: Path,
) -> bool | None:
    """Execute one planning cycle.

    Returns:
        True: cycle completed successfully
        False: cycle failed (transient or issue error)
        None: frontier is clear, no more planning work needed
    """
    state.cycle_count += 1
    cycle_num = state.cycle_count
    is_finalization = state.phase == RunPhase.FINALIZATION

    logger.info(f"=== Planning Cycle {cycle_num} {'(FINALIZATION)' if is_finalization else ''} ===")

    # 1. Assess the planning frontier
    assessor = FrontierAssessor(project_root, scope_guard, state)
    frontier = assessor.assess()

    frontier_items = frontier.get("items", [])
    if not frontier_items and not is_finalization:
        logger.info("Frontier is clear — no more planning work identified.")
        return None  # Signal: no more work

    logger.info(
        f"Frontier: {len(frontier_items)} items, "
        f"{len(frontier.get('focus_issues', []))} focus issues"
    )

    # 2. Build the planning prompt
    run_context = {
        "phase": state.phase.value,
        "cycle_count": cycle_num,
        "elapsed_hours": state.elapsed_seconds / 3600,
        "budget_hours": state.budget_seconds / 3600,
        "actions_applied": state.actions_applied,
        "files_created": state.files_created,
        "issues_created": state.issues_created,
    }

    prompt = prompt_builder.build_planning_prompt(
        frontier_assessment=frontier,
        run_context=run_context,
        is_finalization=is_finalization,
    )

    logger.debug(f"Prompt size: {len(prompt)} chars")

    # 3. Execute Claude CLI
    start_time = time.time()
    result = cli.execute_prompt(prompt, project_root)
    duration = time.time() - start_time
    state.elapsed_seconds += duration

    # Log raw output to disk
    output_text = result.get("output", "")
    if output_text:
        output_path = run_dir / "claude_outputs" / f"cycle_{cycle_num:04d}.md"
        output_path.write_text(output_text)
        logger.debug(f"Claude output for cycle {cycle_num}: {output_text[:200]}")

    if not result["success"]:
        failure_type = result.get("failure_type", "unknown")
        logger.error(f"Cycle {cycle_num} failed ({failure_type}): {result.get('error')}")
        state._last_failure_type = failure_type
        return False

    # 4. Parse structured output
    if config.get("dry_run"):
        # In dry-run mode, synthesize a no-op output to exercise the loop
        from .schemas import PlanningOutput
        planning_output = PlanningOutput(
            frontier_assessment=f"[DRY RUN] Cycle {cycle_num}: {len(frontier_items)} frontier items assessed",
            actions=[],
            cycle_notes="Dry run — no actions produced",
        )
    else:
        try:
            planning_output = parse_planning_output(output_text)
        except ValueError as e:
            logger.error(f"Failed to parse cycle {cycle_num} output: {e}")
            state._last_failure_type = "issue"
            return False

    # Validate actions with full context
    validation_errors = planning_output.validate(
        is_finalization=is_finalization,
        known_issue_ids=scope_guard.known_issue_ids,
    )
    if validation_errors:
        for err in validation_errors:
            logger.warning(f"Action validation: {err}")

    logger.info(
        f"Cycle {cycle_num}: {len(planning_output.actions)} actions proposed, "
        f"assessment: {planning_output.frontier_assessment[:100]}"
    )

    # 5. Apply actions
    apply_result = applier.apply_all(planning_output)

    # Reload scope guard if universe was modified
    if any(
        a.action_type in ("create_issue", "split_issue", "update_dependency")
        for a in planning_output.actions
    ):
        scope_guard.reload_universe()

    logger.info(
        f"Cycle {cycle_num} complete: {apply_result.summary()}"
    )

    state._last_failure_type = None
    return True


def main_loop(
    state: RunState,
    run_dir: Path,
    config: dict,
    scope_guard: ScopeGuard,
    cli: ClaudeCLI,
    prompt_builder: PromptBuilder,
    logger,
) -> None:
    """Main frontier-based planning loop."""
    project_root = Path(config["_project_root"])
    checkpoint_interval = config.get("checkpoint_interval_minutes", 30) * 60
    last_checkpoint_time = time.time()
    max_consecutive_issue_failures = config.get("max_consecutive_failures", 3)
    max_consecutive_transient_failures = 10
    transient_backoff_schedule = [60, 120, 300]  # seconds
    consecutive_issue_failures = 0
    consecutive_transient_failures = 0

    # Read finalization threshold from config
    finalization_pct = config.get("finalization_budget_percent", 10)
    finalization_threshold = 1.0 - (finalization_pct / 100.0)

    # Wall-clock tracking
    wall_clock_start = time.time()
    wall_clock_offset = state.wall_clock_seconds

    # Action applier is created per-cycle (finalization state and known IDs change)
    def make_applier():
        return ActionApplier(
            project_root, state, logger,
            dry_run=config.get("dry_run", False),
            is_finalization=(state.phase == RunPhase.FINALIZATION),
            known_issue_ids=scope_guard.known_issue_ids.copy(),
        )

    # In dry-run mode, cap cycles to prevent infinite loop (no elapsed time accrues)
    max_cycles = config.get("max_cycles", 0)  # 0 = unlimited (budget-based)
    if config.get("dry_run") and max_cycles == 0:
        max_cycles = 3  # Default dry-run cap

    state.status = RunStatus.RUNNING
    if state.phase not in (RunPhase.FINALIZATION,):
        state.phase = RunPhase.PLANNING
    save_state(state, run_dir)
    logger.info("Entering frontier-based planning loop")

    while True:
        # Budget check
        if state.is_budget_exhausted():
            state.stop_reason = "Budget exhausted"
            logger.info("Budget exhausted. Stopping.")
            break

        # Cycle cap check (primarily for dry-run)
        if max_cycles and state.cycle_count >= max_cycles:
            state.stop_reason = f"Max cycles reached ({max_cycles})"
            logger.info(f"Max cycles reached ({max_cycles}). Stopping.")
            break

        # Finalization check — transition but continue the loop
        if (
            state.elapsed_seconds >= state.budget_seconds * finalization_threshold
            and state.phase != RunPhase.FINALIZATION
        ):
            state.phase = RunPhase.FINALIZATION
            logger.info(
                f"Entering finalization mode "
                f"({finalization_pct}% budget remaining)"
            )
            save_state(state, run_dir)

        # Run one planning cycle (fresh applier each cycle for current finalization/ID state)
        cycle_result = planning_cycle(
            state, run_dir, config, scope_guard, cli,
            prompt_builder, make_applier(), logger, project_root,
        )

        if cycle_result is None:
            # Frontier is clear — planning is done
            state.stop_reason = "Planning frontier is clear"
            logger.info("No more planning work identified. Stopping.")
            break
        elif cycle_result is True:
            consecutive_issue_failures = 0
            consecutive_transient_failures = 0
        else:
            # cycle_result is False — failure
            failure_type = getattr(state, "_last_failure_type", "issue")
            if failure_type == "transient":
                consecutive_transient_failures += 1
                consecutive_issue_failures = 0
                if consecutive_transient_failures >= max_consecutive_transient_failures:
                    state.stop_reason = "Claude CLI appears unavailable (10 consecutive transient failures)"
                    logger.error("Too many transient failures. Stopping.")
                    break
                backoff_idx = min(
                    consecutive_transient_failures - 1,
                    len(transient_backoff_schedule) - 1,
                )
                backoff = transient_backoff_schedule[backoff_idx]
                logger.info(f"Transient failure #{consecutive_transient_failures}, backing off {backoff}s")
                time.sleep(backoff)
            else:
                consecutive_issue_failures += 1
                consecutive_transient_failures = 0
                if consecutive_issue_failures >= max_consecutive_issue_failures:
                    state.stop_reason = f"{max_consecutive_issue_failures} consecutive cycle failures"
                    logger.error("Too many consecutive cycle failures. Stopping.")
                    break

        # Update wall-clock time
        state.wall_clock_seconds = wall_clock_offset + (time.time() - wall_clock_start)

        # Save state after every cycle
        save_state(state, run_dir)

        # Checkpoint at interval
        if time.time() - last_checkpoint_time >= checkpoint_interval:
            checkpoint(state, run_dir)
            report_dir = get_reports_dir(config, state.run_id)
            generate_checkpoint_summary(state, report_dir)
            log_checkpoint(logger, state.to_dict())
            last_checkpoint_time = time.time()

            # Validation at checkpoint
            run_validation(state, scope_guard, project_root, logger)

    state.current_issue_id = None
    state.wall_clock_seconds = wall_clock_offset + (time.time() - wall_clock_start)
    save_state(state, run_dir)


def finalize(
    state: RunState,
    run_dir: Path,
    config: dict,
    cli: ClaudeCLI,
    prompt_builder: PromptBuilder,
    logger,
) -> None:
    """Run final wrap-up: generate summary report."""
    logger.info("Running final report generation...")

    # Generate final report
    state.phase = RunPhase.REPORTING
    report_dir = get_reports_dir(config, state.run_id)
    report_path = generate_run_report(state, report_dir)
    logger.info(f"Final report: {report_path}")

    state.phase = RunPhase.DONE
    state.status = RunStatus.COMPLETE
    save_state(state, run_dir)


def main() -> None:
    args = parse_args()

    # Load config
    try:
        config = load_config(args.config)
    except (FileNotFoundError, ValueError) as e:
        print(f"Config error: {e}")
        sys.exit(1)

    # Init or resume
    state, run_dir = init_run(config, args.resume, args.dry_run)

    # Setup logging
    logger = setup_logger(state.run_id, run_dir, verbose=args.verbose)
    logger.info(f"Run ID: {state.run_id}")
    logger.info(f"Config: {args.config}")
    logger.info(f"Budget: {state.budget_seconds / 3600:.0f}h")
    logger.info(f"Dry run: {config.get('dry_run', False)}")

    # Pre-launch validation
    project_root = Path(config["_project_root"])
    pre_issues = validate_pre_launch(config, project_root)
    if pre_issues:
        for issue in pre_issues:
            logger.error(f"Pre-launch: {issue}")
        logger.error("Pre-launch validation failed. Fix issues and retry.")
        sys.exit(1)

    # Init components
    scope_guard = ScopeGuard(project_root, config)
    cli = ClaudeCLI(config, logger)
    prompt_builder = PromptBuilder(project_root, config)

    # Check Claude CLI
    if not cli.check_available():
        logger.warning(
            "Claude CLI not available. Use --dry-run to test without it."
        )
        if not config.get("dry_run"):
            sys.exit(1)

    # Validate universe
    universe_issues = scope_guard.validate_universe_integrity()
    if universe_issues:
        for issue in universe_issues:
            logger.error(f"Universe integrity: {issue}")
        sys.exit(1)

    logger.info("Pre-launch validation passed. Starting run.")

    try:
        # Main loop
        main_loop(state, run_dir, config, scope_guard, cli, prompt_builder, logger)

        # Final report
        finalize(state, run_dir, config, cli, prompt_builder, logger)

    except KeyboardInterrupt:
        logger.info("Interrupted by user. Saving state for resume.")
        state.status = RunStatus.PAUSED
        state.stop_reason = "User interrupt (Ctrl+C)"
        save_state(state, run_dir)
        checkpoint(state, run_dir)

    except Exception as e:
        logger.exception(f"Unhandled error: {e}")
        state.status = RunStatus.FAILED
        state.stop_reason = f"Unhandled error: {e}"
        save_state(state, run_dir)

    finally:
        report_dir = get_reports_dir(config, state.run_id)
        generate_run_report(state, report_dir)
        logger.info(f"Run {state.run_id} finished: {state.status.value}")
        logger.info(f"State: {run_dir}/state.json")
        logger.info(f"Logs: {run_dir}/{state.run_id}.log")
        logger.info(f"Reports: {report_dir}/")


if __name__ == "__main__":
    main()

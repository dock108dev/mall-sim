"""Report generation for AIDLC runs."""

import json
from datetime import datetime, timezone
from pathlib import Path

from .models import RunState


def generate_run_report(state: RunState, report_dir: Path) -> Path:
    """Generate a human-readable run summary report."""
    report_path = report_dir / f"run_report_{state.run_id}.md"

    elapsed_hours = state.elapsed_seconds / 3600
    wall_hours = state.wall_clock_seconds / 3600
    budget_hours = state.budget_seconds / 3600

    lines = [
        f"# Run Report: {state.run_id}\n",
        f"\n**Status**: {state.status.value}",
        f"**Phase**: {state.phase.value}",
        f"**Started**: {state.started_at or 'not started'}",
        f"**Last Updated**: {state.last_updated}",
        f"**Elapsed (Claude)**: {elapsed_hours:.1f}h / {budget_hours:.0f}h budget",
        f"**Elapsed (wall clock)**: {wall_hours:.1f}h",
        f"**Checkpoints**: {state.checkpoint_count}",
        f"**Stop Reason**: {state.stop_reason or 'N/A'}",
        "",
        "## Progress",
        "",
        f"| Metric | Count |",
        f"|---|---|",
        f"| Planning cycles | {state.cycle_count} |",
        f"| Actions applied | {state.actions_applied} |",
        f"| Files created | {state.files_created} |",
        f"| Files updated | {state.files_updated} |",
        f"| Issues created | {state.issues_created} |",
        f"| Created artifacts | {len(state.created_artifacts)} |",
        f"| Out-of-scope findings | {len(state.out_of_scope_findings)} |",
        f"| Validation results | {len(state.validation_results)} |",
        "",
    ]

    if state.completed_issues:
        lines.append("## Completed Issues\n")
        for issue_id in state.completed_issues:
            lines.append(f"- {issue_id}")
        lines.append("")

    if state.failed_issues:
        lines.append("## Failed Issues\n")
        for item in state.failed_issues:
            lines.append(f"- {item}")
        lines.append("")

    if state.out_of_scope_findings:
        lines.append("## Out-of-Scope Findings\n")
        for finding in state.out_of_scope_findings:
            lines.append(f"- {finding}")
        lines.append("")

    if state.created_artifacts:
        lines.append("## Created Artifacts\n")
        for artifact in state.created_artifacts:
            lines.append(f"- {artifact}")
        lines.append("")

    if state.notes:
        lines.append(f"## Notes\n\n{state.notes}\n")

    content = "\n".join(lines)
    report_path.write_text(content)
    return report_path


def generate_checkpoint_summary(state: RunState, report_dir: Path) -> Path:
    """Generate a brief checkpoint summary."""
    cp_path = report_dir / f"checkpoint_{state.checkpoint_count:04d}.md"
    elapsed = state.elapsed_seconds / 3600

    content = f"""# Checkpoint {state.checkpoint_count}

- **Time**: {datetime.now(timezone.utc).isoformat()}
- **Elapsed**: {elapsed:.1f}h
- **Wave**: {state.current_wave}
- **Current issue**: {state.current_issue_id or 'none'}
- **Cycle**: {state.cycle_count}
- **Actions applied**: {state.actions_applied}
- **Files created**: {state.files_created}
- **Issues created**: {state.issues_created}
"""
    cp_path.write_text(content)
    return cp_path

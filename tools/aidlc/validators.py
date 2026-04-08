"""Validation hooks for AIDLC runner."""

import json
import tempfile
from pathlib import Path
from typing import Optional

from .models import RunState
from .scope_guard import ScopeGuard


def validate_checkpoint(
    state: RunState, scope_guard: ScopeGuard, project_root: Path
) -> list[str]:
    """Run checkpoint validation. Returns list of issues found."""
    issues = []

    # 1. Universe integrity
    universe_issues = scope_guard.validate_universe_integrity()
    issues.extend(universe_issues)

    # 2. No completed issue has unmet dependencies
    completed_set = set(state.completed_issues)
    for issue_id in state.completed_issues:
        issue = scope_guard.get_issue_by_id(issue_id)
        if issue:
            for dep in issue.get("dependencies", []):
                if dep not in completed_set:
                    issues.append(
                        f"{issue_id} completed but dependency {dep} is not"
                    )

    # 3. Created artifacts should exist on disk
    for artifact_path in state.created_artifacts:
        full_path = project_root / artifact_path
        if not full_path.exists():
            issues.append(f"Artifact listed but missing on disk: {artifact_path}")

    # 4. State consistency
    if state.status.value == "complete" and state.phase.value != "done":
        issues.append("Status is complete but phase is not done")

    return issues


def _check_dag_acyclic(issue_list: list[dict]) -> list[str]:
    """Verify the dependency graph has no cycles using DFS."""
    problems = []
    adj = {}
    for issue in issue_list:
        adj[issue["id"]] = issue.get("dependencies", [])

    WHITE, GRAY, BLACK = 0, 1, 2
    color = {iid: WHITE for iid in adj}

    def dfs(node: str, path: list[str]) -> None:
        color[node] = GRAY
        for dep in adj.get(node, []):
            if dep not in color:
                continue
            if color[dep] == GRAY:
                cycle_start = path.index(dep)
                cycle = " -> ".join(path[cycle_start:] + [dep])
                problems.append(f"Dependency cycle detected: {cycle}")
                return
            if color[dep] == WHITE:
                dfs(dep, path + [dep])
        color[node] = BLACK

    for node in adj:
        if color[node] == WHITE:
            dfs(node, [node])

    return problems


def validate_pre_launch(
    config: dict, project_root: Path
) -> list[str]:
    """Pre-launch validation. Checks everything is in place before starting."""
    issues = []

    # 1. Check required manifests exist and parse
    required_manifests = [
        "planning/manifests/final-issue-universe.json",
        "planning/manifests/closed-universe-freeze.json",
        "planning/manifests/final-wave-plan.json",
    ]
    manifest_data = {}
    for manifest in required_manifests:
        path = project_root / manifest
        if not path.exists():
            issues.append(f"Required manifest missing: {manifest}")
        else:
            try:
                with open(path) as f:
                    manifest_data[manifest] = json.load(f)
            except json.JSONDecodeError:
                issues.append(f"Manifest is not valid JSON: {manifest}")

    # 2. Check planning state exists
    state_path = project_root / "planning/state/current_state.json"
    if not state_path.exists():
        issues.append("Planning state file missing")

    # 3. Check issue archive exists
    issues_dir = project_root / "docs/production/github-issues"
    if not issues_dir.exists():
        issues.append("Issue archive directory missing")
    else:
        issue_files = list(issues_dir.glob("issue-*.md"))
        if len(issue_files) == 0:
            issues.append("No issue files found in archive")

    # 4. All issue files referenced in universe exist on disk
    universe_key = "planning/manifests/final-issue-universe.json"
    universe = manifest_data.get(universe_key, {})
    issue_list = universe.get("issues", [])
    for issue in issue_list:
        local_file = issue.get("local_file", "")
        if local_file and not (project_root / local_file).exists():
            issues.append(
                f"Issue {issue['id']} references missing file: {local_file}"
            )

    # 5. Dependency graph is acyclic
    if issue_list:
        cycle_problems = _check_dag_acyclic(issue_list)
        issues.extend(cycle_problems)

    # 6. Wave plan cross-references universe
    wave_key = "planning/manifests/final-wave-plan.json"
    wave_plan = manifest_data.get(wave_key, {})
    universe_ids = {i["id"] for i in issue_list}
    for wave_name, wave_data in wave_plan.get("waves", {}).items():
        for issue_id in wave_data.get("issues", []):
            if issue_id not in universe_ids:
                issues.append(
                    f"Wave {wave_name} references unknown issue: {issue_id}"
                )

    # 7. Run directory is writable
    from .config import RUNS_DIR
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    try:
        test_file = RUNS_DIR / ".write_test"
        test_file.write_text("test")
        test_file.unlink()
    except OSError as e:
        issues.append(f"Run directory not writable: {e}")

    # 8. Template builds without error (dry-run first issue)
    if issue_list:
        try:
            from .prompt_builder import PromptBuilder
            pb = PromptBuilder(project_root, config)
            first_issue = issue_list[0]
            test_content = "Test issue content"
            test_context = {"phase": "planning", "completed_count": 0, "total_issues": 85}
            pb.build_issue_work_prompt(first_issue, test_content, test_context)
        except Exception as e:
            issues.append(f"Prompt template build failed: {e}")

    return issues

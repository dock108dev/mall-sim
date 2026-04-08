"""Apply layer for AIDLC planning-generation mode.

Takes validated PlanningAction objects and applies them to the repo:
- Writes files (design docs, content JSON, planning artifacts)
- Creates/updates issue .md files in the archive
- Updates the issue universe manifest
- Updates the dependency graph
- Logs all changes for auditability
"""

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

from .schemas import PlanningAction, PlanningOutput
from .models import RunState


class ApplyResult:
    """Result of applying a set of planning actions."""

    def __init__(self):
        self.applied: list[dict] = []
        self.skipped: list[dict] = []
        self.errors: list[dict] = []

    @property
    def success_count(self) -> int:
        return len(self.applied)

    @property
    def error_count(self) -> int:
        return len(self.errors)

    def summary(self) -> str:
        return (
            f"Applied: {self.success_count}, "
            f"Skipped: {len(self.skipped)}, "
            f"Errors: {self.error_count}"
        )


class ActionApplier:
    """Applies planning actions to the repository."""

    # Safety: only allow writes under these directories
    ALLOWED_WRITE_PREFIXES = [
        "docs/",
        "game/content/",
        "planning/",
        "tools/",
    ]

    def __init__(
        self,
        project_root: Path,
        state: RunState,
        logger: logging.Logger,
        dry_run: bool = False,
        is_finalization: bool = False,
        known_issue_ids: set | None = None,
    ):
        self.project_root = project_root
        self.state = state
        self.logger = logger
        self.dry_run = dry_run
        self.is_finalization = is_finalization
        self.known_issue_ids = known_issue_ids or set()

    def apply_all(self, output: PlanningOutput) -> ApplyResult:
        """Apply all actions from a planning output."""
        result = ApplyResult()

        for i, action in enumerate(output.actions):
            # Validate action with full context
            errors = action.validate(
                is_finalization=self.is_finalization,
                known_issue_ids=self.known_issue_ids,
            )
            if errors:
                result.errors.append({
                    "index": i,
                    "action_type": action.action_type,
                    "errors": errors,
                })
                self.logger.warning(
                    f"Skipping invalid action [{i}] {action.action_type}: {errors}"
                )
                continue

            try:
                applied = self._apply_action(action, i)
                if applied:
                    result.applied.append({
                        "index": i,
                        "action_type": action.action_type,
                        "detail": applied,
                    })
                else:
                    result.skipped.append({
                        "index": i,
                        "action_type": action.action_type,
                        "reason": "Action returned no result",
                    })
            except Exception as e:
                result.errors.append({
                    "index": i,
                    "action_type": action.action_type,
                    "errors": [str(e)],
                })
                self.logger.error(f"Failed to apply action [{i}] {action.action_type}: {e}")

        # Update state counters
        self.state.actions_applied += result.success_count
        for item in result.applied:
            if item["action_type"] in ("create_file", "update_file"):
                self.state.files_created += 1
                path = item["detail"].get("path", "")
                if path:
                    self.state.created_artifacts.append(path)
            elif item["action_type"] == "create_issue":
                self.state.issues_created += 1
            elif item["action_type"] == "split_issue":
                self.state.issues_created += 1

        # Track out-of-scope findings
        self.state.out_of_scope_findings.extend(output.out_of_scope_findings)

        self.logger.info(f"Apply result: {result.summary()}")
        return result

    def _apply_action(self, action: PlanningAction, index: int) -> dict | None:
        """Apply a single action. Returns detail dict or None."""
        dispatch = {
            "create_file": self._apply_create_file,
            "update_file": self._apply_update_file,
            "create_issue": self._apply_create_issue,
            "update_issue": self._apply_update_issue,
            "split_issue": self._apply_split_issue,
            "update_dependency": self._apply_update_dependency,
        }

        handler = dispatch.get(action.action_type)
        if not handler:
            raise ValueError(f"No handler for action_type: {action.action_type}")
        return handler(action)

    def _apply_create_file(self, action: PlanningAction) -> dict:
        """Create a new file in the repo."""
        path = action.file_path
        if not self._is_safe_path(path):
            raise ValueError(f"Path not in allowed directories: {path}")

        full_path = self.project_root / path
        if full_path.exists():
            self.logger.warning(f"create_file: {path} already exists, treating as update")

        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would create file: {path} ({len(action.content)} chars)")
            return {"path": path, "size": len(action.content), "dry_run": True}

        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(action.content)
        self.logger.info(f"Created file: {path} ({len(action.content)} chars)")
        return {"path": path, "size": len(action.content)}

    def _apply_update_file(self, action: PlanningAction) -> dict:
        """Update an existing file in the repo."""
        path = action.file_path
        if not self._is_safe_path(path):
            raise ValueError(f"Path not in allowed directories: {path}")

        full_path = self.project_root / path
        if not full_path.exists():
            self.logger.warning(f"update_file: {path} doesn't exist, creating it")

        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would update file: {path} ({len(action.content)} chars)")
            return {"path": path, "size": len(action.content), "dry_run": True}

        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(action.content)
        self.logger.info(f"Updated file: {path} ({len(action.content)} chars)")
        return {"path": path, "size": len(action.content)}

    def _apply_create_issue(self, action: PlanningAction) -> dict:
        """Create a new issue .md file and add to universe manifest."""
        issue_id = action.issue_id
        title = action.title

        # Reject if file already exists (duplicate)
        issue_path = f"docs/production/github-issues/{issue_id}.md"
        full_path = self.project_root / issue_path
        if full_path.exists():
            raise ValueError(f"Issue file already exists: {issue_path}")

        # Check for near-duplicate titles in existing universe
        universe_path = self.project_root / "planning/manifests/final-issue-universe.json"
        if universe_path.exists():
            with open(universe_path) as f:
                universe = json.load(f)
            for existing in universe.get("issues", []):
                if existing.get("title", "").lower().strip() == title.lower().strip():
                    raise ValueError(
                        f"Near-duplicate title: '{title}' matches existing "
                        f"{existing['id']}: '{existing['title']}'"
                    )

        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would create issue: {issue_id} — {title}")
            return {"issue_id": issue_id, "title": title, "path": issue_path, "dry_run": True}

        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(action.content)

        # Add to universe manifest
        self._add_to_universe(action)

        self.logger.info(f"Created issue: {issue_id} — {title}")
        return {"issue_id": issue_id, "title": title, "path": issue_path}

    def _apply_update_issue(self, action: PlanningAction) -> dict:
        """Update an existing issue's .md content."""
        issue_id = action.issue_id
        issue_path = f"docs/production/github-issues/{issue_id}.md"
        full_path = self.project_root / issue_path

        if not full_path.exists():
            raise ValueError(f"Cannot update non-existent issue: {issue_id}")

        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would update issue: {issue_id}")
            return {"issue_id": issue_id, "path": issue_path, "dry_run": True}

        full_path.write_text(action.content)
        self.logger.info(f"Updated issue: {issue_id}")
        return {"issue_id": issue_id, "path": issue_path}

    def _apply_split_issue(self, action: PlanningAction) -> dict:
        """Create a sub-task issue linked to a parent."""
        parent_id = action.parent_issue_id
        sub_id = action.issue_id
        title = action.title

        # Verify parent exists
        parent_path = self.project_root / f"docs/production/github-issues/{parent_id}.md"
        if not parent_path.exists():
            raise ValueError(f"Cannot split non-existent parent issue: {parent_id}")

        # Write sub-task issue file
        issue_path = f"docs/production/github-issues/{sub_id}.md"

        if self.dry_run:
            self.logger.info(f"[DRY RUN] Would create sub-task: {sub_id} (parent: {parent_id})")
            return {"issue_id": sub_id, "parent": parent_id, "title": title, "dry_run": True}

        full_path = self.project_root / issue_path
        full_path.parent.mkdir(parents=True, exist_ok=True)

        # Build sub-task content if not provided
        content = action.content or f"""# {sub_id}: {title}

**Wave**: {action.wave or 'TBD'}
**Milestone**: {action.milestone or 'TBD'}
**Labels**: {', '.join(f'`{l}`' for l in action.labels)}
**Dependencies**: {parent_id}
**Parent Issue**: {parent_id}

## Scope

Sub-task of {parent_id}.

{action.rationale}
"""
        full_path.write_text(content)

        # Add to universe with dependency on parent
        deps = action.dependencies or [parent_id]
        action.dependencies = deps
        self._add_to_universe(action)

        self.logger.info(f"Created sub-task: {sub_id} (parent: {parent_id}) — {title}")
        return {"issue_id": sub_id, "parent": parent_id, "title": title, "path": issue_path}

    def _apply_update_dependency(self, action: PlanningAction) -> dict:
        """Update dependency edges for an issue in the universe manifest."""
        issue_id = action.issue_id

        if self.dry_run:
            self.logger.info(
                f"[DRY RUN] Would update deps for {issue_id}: "
                f"+{action.add_dependencies} -{action.remove_dependencies}"
            )
            return {"issue_id": issue_id, "dry_run": True}

        # Load and update universe manifest
        universe_path = self.project_root / "planning/manifests/final-issue-universe.json"
        with open(universe_path) as f:
            universe = json.load(f)

        for issue in universe.get("issues", []):
            if issue["id"] == issue_id:
                deps = set(issue.get("dependencies", []))
                deps.update(action.add_dependencies)
                deps -= set(action.remove_dependencies)
                issue["dependencies"] = sorted(deps)
                break

        with open(universe_path, "w") as f:
            json.dump(universe, f, indent=2)

        self.logger.info(
            f"Updated deps for {issue_id}: "
            f"+{action.add_dependencies} -{action.remove_dependencies}"
        )
        return {
            "issue_id": issue_id,
            "added": action.add_dependencies,
            "removed": action.remove_dependencies,
        }

    def _add_to_universe(self, action: PlanningAction) -> None:
        """Add a new issue entry to the universe manifest."""
        universe_path = self.project_root / "planning/manifests/final-issue-universe.json"
        with open(universe_path) as f:
            universe = json.load(f)

        new_entry = {
            "id": action.issue_id,
            "title": action.title or "",
            "wave": action.wave or "wave-1",
            "milestone": action.milestone or "TBD",
            "labels": action.labels,
            "dependencies": action.dependencies,
            "local_file": f"docs/production/github-issues/{action.issue_id}.md",
        }

        # Don't add duplicates
        existing_ids = {i["id"] for i in universe.get("issues", [])}
        if action.issue_id in existing_ids:
            self.logger.warning(f"Issue {action.issue_id} already in universe, skipping manifest add")
            return

        universe["issues"].append(new_entry)
        universe["total_issues"] = len(universe["issues"])

        with open(universe_path, "w") as f:
            json.dump(universe, f, indent=2)

        # Also update the freeze manifest issue_ids
        freeze_path = self.project_root / "planning/manifests/closed-universe-freeze.json"
        if freeze_path.exists():
            with open(freeze_path) as f:
                freeze = json.load(f)
            if action.issue_id not in freeze.get("issue_ids", []):
                freeze["issue_ids"].append(action.issue_id)
                freeze["total_issues"] = len(freeze["issue_ids"])
                with open(freeze_path, "w") as f:
                    json.dump(freeze, f, indent=2)

    def _is_safe_path(self, path: str) -> bool:
        """Check that a file path is under an allowed directory."""
        return any(path.startswith(prefix) for prefix in self.ALLOWED_WRITE_PREFIXES)

"""Scope guard for closed-universe enforcement during planning runs."""

import json
from pathlib import Path
from typing import Optional


class ScopeGuard:
    """Enforces the closed planning universe rules.

    During the planning run (open window):
    - New issues/tasks/docs CAN be created
    - But must be recorded with rationale
    - Must stay within project planning scope
    - Must avoid duplicates

    During finalization:
    - No new issues/tasks/categories
    - Only finishing, deduping, consolidating
    """

    def __init__(self, project_root: Path, config: dict):
        self.project_root = project_root
        self.config = config
        self._load_universe()

    def _load_universe(self) -> None:
        """Load the issue universe and freeze manifest."""
        universe_path = self.project_root / self.config.get(
            "universe_manifest",
            "planning/manifests/final-issue-universe.json",
        )
        freeze_path = self.project_root / self.config.get(
            "freeze_manifest",
            "planning/manifests/closed-universe-freeze.json",
        )
        wave_path = self.project_root / self.config.get(
            "wave_manifest",
            "planning/manifests/final-wave-plan.json",
        )

        self.universe = {}
        if universe_path.exists():
            with open(universe_path) as f:
                self.universe = json.load(f)

        self.freeze_rules = {}
        if freeze_path.exists():
            with open(freeze_path) as f:
                self.freeze_rules = json.load(f)

        self.wave_plan = {}
        if wave_path.exists():
            with open(wave_path) as f:
                self.wave_plan = json.load(f)

        self.known_issue_ids = set(self.freeze_rules.get("issue_ids", []))
        self.allowed_milestones = set(self.freeze_rules.get("milestones", []))
        self.allowed_waves = set(self.freeze_rules.get("waves", []))
        self.allowed_artifact_classes = set(
            self.freeze_rules.get("allowed_artifact_classes", [])
        )

    def is_known_issue(self, issue_id: str) -> bool:
        """Check if an issue ID is in the known universe."""
        return issue_id in self.known_issue_ids

    def is_valid_milestone(self, milestone: str) -> bool:
        """Check if a milestone is in the allowed set."""
        return milestone in self.allowed_milestones

    def is_valid_wave(self, wave: str) -> bool:
        """Check if a wave is in the allowed set."""
        return wave in self.allowed_waves

    def is_valid_artifact_class(self, artifact_class: str) -> bool:
        """Check if an artifact class is allowed."""
        return artifact_class in self.allowed_artifact_classes

    def check_new_work(
        self, description: str, is_finalization: bool
    ) -> tuple[bool, str]:
        """Check whether new work creation is allowed.

        During planning (not finalization): allowed with recording.
        During finalization: blocked.

        Returns (allowed, reason).
        """
        if is_finalization:
            return False, (
                "Finalization mode: new work creation is prohibited. "
                "Only finishing, deduping, and consolidating are allowed."
            )
        # During planning window, new work is allowed but must be recorded
        return True, f"New work allowed during planning window: {description}"

    def get_issues_for_wave(self, wave: str) -> list[dict]:
        """Get all issues assigned to a specific wave."""
        issues = self.universe.get("issues", [])
        return [i for i in issues if i.get("wave") == wave]

    def get_next_wave(self, current_wave: str) -> Optional[str]:
        """Get the next wave after the current one."""
        waves = sorted(self.allowed_waves)
        try:
            idx = waves.index(current_wave)
            if idx + 1 < len(waves):
                return waves[idx + 1]
        except ValueError:
            pass
        return None

    def get_issue_by_id(self, issue_id: str) -> Optional[dict]:
        """Look up an issue by ID from the universe."""
        for issue in self.universe.get("issues", []):
            if issue["id"] == issue_id:
                return issue
        return None

    def reload_universe(self) -> None:
        """Reload manifests from disk. Call after apply changes the universe."""
        self._load_universe()

    def get_next_issue_id(self) -> str:
        """Generate the next available issue ID (e.g., issue-086)."""
        issues = self.universe.get("issues", [])
        max_num = 0
        for issue in issues:
            try:
                num = int(issue["id"].replace("issue-", ""))
                if num > max_num:
                    max_num = num
            except (ValueError, KeyError):
                pass
        return f"issue-{max_num + 1:03d}"

    def validate_universe_integrity(self) -> list[str]:
        """Run integrity checks on the loaded universe. Returns list of issues found."""
        problems = []
        issues = self.universe.get("issues", [])

        # Check all issue IDs are unique
        ids = [i["id"] for i in issues]
        if len(ids) != len(set(ids)):
            problems.append("Duplicate issue IDs found in universe")

        # Check all dependencies reference existing issues
        id_set = set(ids)
        for issue in issues:
            for dep in issue.get("dependencies", []):
                if dep not in id_set:
                    problems.append(
                        f"Issue {issue['id']} depends on unknown {dep}"
                    )

        # Check all milestones are in allowed set
        for issue in issues:
            if issue.get("milestone") and not self.is_valid_milestone(
                issue["milestone"]
            ):
                problems.append(
                    f"Issue {issue['id']} has unknown milestone: "
                    f"{issue['milestone']}"
                )

        return problems

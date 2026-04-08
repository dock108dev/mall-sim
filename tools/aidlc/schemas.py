"""Structured output schemas for AIDLC planning-generation mode.

Defines the JSON contract between Claude (producer) and the runner (consumer).
Claude outputs a JSON block matching PLANNING_OUTPUT_SCHEMA.
The runner parses it and applies actions via apply.py.
"""

import json
import re
from dataclasses import dataclass, field
from typing import Optional


# Valid action types for planning mode
ACTION_TYPES = {
    "create_file",      # Write a new file to the repo
    "update_file",      # Modify an existing file's content
    "create_issue",     # Create a new issue .md file + manifest entry
    "update_issue",     # Update an existing issue's .md content
    "split_issue",      # Create sub-tasks under an existing issue
    "update_dependency", # Add/remove dependency edges
}


@dataclass
class PlanningAction:
    """A single action proposed by Claude during planning."""
    action_type: str
    rationale: str

    # For file operations
    file_path: Optional[str] = None
    content: Optional[str] = None

    # For issue operations
    issue_id: Optional[str] = None
    parent_issue_id: Optional[str] = None  # For split_issue
    title: Optional[str] = None
    wave: Optional[str] = None
    milestone: Optional[str] = None
    labels: list = field(default_factory=list)
    dependencies: list = field(default_factory=list)

    # For dependency updates
    add_dependencies: list = field(default_factory=list)
    remove_dependencies: list = field(default_factory=list)

    def validate(self, is_finalization: bool = False, known_issue_ids: set | None = None) -> list[str]:
        """Return list of validation errors.

        Args:
            is_finalization: If True, reject create_issue and split_issue actions.
            known_issue_ids: Set of existing issue IDs for dependency validation.
        """
        errors = []
        if self.action_type not in ACTION_TYPES:
            errors.append(f"Unknown action_type: {self.action_type}")

        # Universal: rationale must not be empty
        if not self.rationale or not self.rationale.strip():
            errors.append("rationale must not be empty")

        # Finalization mode: block creation actions
        if is_finalization and self.action_type in ("create_issue", "split_issue"):
            errors.append(
                f"{self.action_type} is prohibited during finalization mode"
            )

        if self.action_type in ("create_file", "update_file"):
            if not self.file_path:
                errors.append(f"{self.action_type} requires file_path")
            if not self.content:
                errors.append(f"{self.action_type} requires content")

        if self.action_type == "create_issue":
            if not self.issue_id:
                errors.append("create_issue requires issue_id")
            elif not re.match(r"^issue-\d{3,}$", self.issue_id):
                errors.append(f"issue_id must match 'issue-NNN' format, got: {self.issue_id}")
            if not self.title:
                errors.append("create_issue requires title")
            if not self.content:
                errors.append("create_issue requires content")
            if not self.wave:
                errors.append("create_issue requires wave")
            if not self.milestone:
                errors.append("create_issue requires milestone")
            if not self.labels:
                errors.append("create_issue requires at least one label")
            # Validate dependency references
            if known_issue_ids and self.dependencies:
                for dep in self.dependencies:
                    if dep not in known_issue_ids:
                        errors.append(f"dependency '{dep}' is not a known issue")

        if self.action_type == "update_issue":
            if not self.issue_id:
                errors.append("update_issue requires issue_id")
            elif not re.match(r"^issue-\d{3,}$", self.issue_id):
                errors.append(f"issue_id must match 'issue-NNN' format, got: {self.issue_id}")
            if not self.content:
                errors.append("update_issue requires content")
            # Must reference an existing issue
            if known_issue_ids and self.issue_id and self.issue_id not in known_issue_ids:
                errors.append(f"cannot update unknown issue: {self.issue_id}")

        if self.action_type == "split_issue":
            if not self.parent_issue_id:
                errors.append("split_issue requires parent_issue_id")
            elif known_issue_ids and self.parent_issue_id not in known_issue_ids:
                errors.append(f"parent issue '{self.parent_issue_id}' is not a known issue")
            if not self.issue_id:
                errors.append("split_issue requires issue_id for sub-task")
            elif not re.match(r"^issue-\d{3,}$", self.issue_id):
                errors.append(f"issue_id must match 'issue-NNN' format, got: {self.issue_id}")
            if not self.title:
                errors.append("split_issue requires title")

        if self.action_type == "update_dependency":
            if not self.issue_id:
                errors.append("update_dependency requires issue_id")
            elif known_issue_ids and self.issue_id not in known_issue_ids:
                errors.append(f"cannot update deps for unknown issue: {self.issue_id}")
            # Validate that dependency targets exist
            if known_issue_ids:
                for dep in self.add_dependencies:
                    if dep not in known_issue_ids:
                        errors.append(f"add_dependency target '{dep}' is not a known issue")

        return errors

    @classmethod
    def from_dict(cls, data: dict) -> "PlanningAction":
        return cls(
            action_type=data.get("action_type", ""),
            rationale=data.get("rationale", ""),
            file_path=data.get("file_path"),
            content=data.get("content"),
            issue_id=data.get("issue_id"),
            parent_issue_id=data.get("parent_issue_id"),
            title=data.get("title"),
            wave=data.get("wave"),
            milestone=data.get("milestone"),
            labels=data.get("labels", []),
            dependencies=data.get("dependencies", []),
            add_dependencies=data.get("add_dependencies", []),
            remove_dependencies=data.get("remove_dependencies", []),
        )


@dataclass
class PlanningOutput:
    """The full structured output from one planning cycle."""
    frontier_assessment: str
    actions: list[PlanningAction]
    cycle_notes: str = ""
    out_of_scope_findings: list = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: dict) -> "PlanningOutput":
        actions = [PlanningAction.from_dict(a) for a in data.get("actions", [])]
        return cls(
            frontier_assessment=data.get("frontier_assessment", ""),
            actions=actions,
            cycle_notes=data.get("cycle_notes", ""),
            out_of_scope_findings=data.get("out_of_scope_findings", []),
        )

    def validate(self, is_finalization: bool = False, known_issue_ids: set | None = None) -> list[str]:
        """Return list of validation errors across all actions.

        Args:
            is_finalization: If True, reject creation actions.
            known_issue_ids: Set of existing issue IDs for reference validation.
        """
        errors = []

        # Check for duplicate issue IDs within this batch
        new_ids = [a.issue_id for a in self.actions if a.action_type in ("create_issue", "split_issue") and a.issue_id]
        seen = set()
        for iid in new_ids:
            if iid in seen:
                errors.append(f"Duplicate issue_id in batch: {iid}")
            seen.add(iid)

        # Check for duplicate issue IDs against existing universe
        if known_issue_ids:
            for iid in new_ids:
                if iid in known_issue_ids:
                    errors.append(f"Issue {iid} already exists in universe — would create duplicate")

        # Check for near-duplicate titles within this batch
        new_titles = [a.title.lower().strip() for a in self.actions if a.title]
        title_seen = set()
        for t in new_titles:
            if t in title_seen:
                errors.append(f"Duplicate title in batch: '{t}'")
            title_seen.add(t)

        for i, action in enumerate(self.actions):
            for err in action.validate(is_finalization=is_finalization, known_issue_ids=known_issue_ids):
                errors.append(f"Action [{i}] ({action.action_type}): {err}")
        return errors


def parse_planning_output(raw_text: str) -> PlanningOutput:
    """Extract and parse the JSON planning output from Claude's response.

    Claude is instructed to wrap its structured output in a ```json block.
    This function finds that block and parses it. Falls back to treating
    the entire response as JSON if no code block is found.
    """
    # Try to find a ```json ... ``` block
    json_match = re.search(
        r"```json\s*\n(.*?)\n\s*```",
        raw_text,
        re.DOTALL,
    )
    if json_match:
        json_str = json_match.group(1)
    else:
        # Try to find any { ... } block that looks like our schema
        brace_match = re.search(r"\{.*\"actions\".*\}", raw_text, re.DOTALL)
        if brace_match:
            json_str = brace_match.group(0)
        else:
            raise ValueError(
                "Could not find structured JSON output in Claude's response. "
                f"Response starts with: {raw_text[:200]}"
            )

    try:
        data = json.loads(json_str)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse planning output JSON: {e}")

    return PlanningOutput.from_dict(data)


# Schema description included in prompts so Claude knows the expected format
OUTPUT_SCHEMA_DESCRIPTION = """\
You MUST output your planning actions as a single JSON block wrapped in ```json``` markers.
The JSON must conform to this schema:

```
{
  "frontier_assessment": "Brief summary of what you assessed and why you chose these actions",
  "actions": [
    {
      "action_type": "create_file | update_file | create_issue | update_issue | split_issue | update_dependency",
      "rationale": "Why this action is needed",

      // For create_file / update_file:
      "file_path": "path/relative/to/project/root",
      "content": "Full file content to write",

      // For create_issue / split_issue:
      "issue_id": "issue-086",
      "parent_issue_id": "issue-006",  // only for split_issue
      "title": "Issue title",
      "wave": "wave-1",
      "milestone": "M1 Foundation + First Playable",
      "labels": ["tech", "phase:m1"],
      "dependencies": ["issue-001", "issue-003"],
      "content": "Full issue markdown content",

      // For update_issue:
      "issue_id": "issue-005",
      "content": "Updated full issue markdown content",

      // For update_dependency:
      "issue_id": "issue-010",
      "add_dependencies": ["issue-009"],
      "remove_dependencies": []
    }
  ],
  "cycle_notes": "Any observations about planning state, risks, or suggestions for next cycle",
  "out_of_scope_findings": ["Things discovered that don't fit any existing issue"]
}
```

Rules for actions:
- create_file: Use for design docs, content JSON, planning artifacts. Path must be under docs/, game/content/, or planning/.
- update_file: Use to revise existing docs or content. Provide the COMPLETE new file content.
- create_issue: Use for genuinely missing work. New issue IDs must be > 085. Must include full markdown content.
- update_issue: Use to add implementation details, refine scope, or add acceptance criteria.
- split_issue: Use when an issue is too large. Creates a sub-task linked to the parent.
- update_dependency: Use to fix missing or incorrect dependency edges.

You may produce 1-10 actions per cycle. Quality over quantity. Each action must have a rationale.
"""

"""Data models for AIDLC runner state, config, and artifacts."""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional
import time


class RunStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    PAUSED = "paused"
    FINALIZING = "finalizing"
    COMPLETE = "complete"
    FAILED = "failed"


class RunPhase(Enum):
    INIT = "init"
    PLANNING = "planning"
    FINALIZATION = "finalization"
    REPORTING = "reporting"
    DONE = "done"


class TaskStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETE = "complete"
    BLOCKED = "blocked"
    SKIPPED = "skipped"
    FAILED = "failed"


@dataclass
class RunState:
    run_id: str
    config_name: str
    status: RunStatus = RunStatus.PENDING
    phase: RunPhase = RunPhase.INIT
    started_at: Optional[str] = None
    last_updated: Optional[str] = None
    elapsed_seconds: float = 0.0
    wall_clock_seconds: float = 0.0
    budget_seconds: float = 144000.0  # 40 hours
    current_wave: str = "wave-1"
    current_issue_id: Optional[str] = None
    completed_issues: list = field(default_factory=list)
    failed_issues: list = field(default_factory=list)
    skipped_issues: list = field(default_factory=list)
    created_artifacts: list = field(default_factory=list)
    out_of_scope_findings: list = field(default_factory=list)
    validation_results: list = field(default_factory=list)
    checkpoint_count: int = 0
    cycle_count: int = 0
    actions_applied: int = 0
    files_created: int = 0
    files_updated: int = 0
    issues_created: int = 0
    stop_reason: Optional[str] = None
    notes: str = ""

    def is_budget_exhausted(self) -> bool:
        return self.elapsed_seconds >= self.budget_seconds

    def should_finalize(self) -> bool:
        """Enter finalization when 90% of budget is consumed."""
        return self.elapsed_seconds >= (self.budget_seconds * 0.9)

    def to_dict(self) -> dict:
        return {
            "run_id": self.run_id,
            "config_name": self.config_name,
            "status": self.status.value,
            "phase": self.phase.value,
            "started_at": self.started_at,
            "last_updated": self.last_updated,
            "elapsed_seconds": self.elapsed_seconds,
            "wall_clock_seconds": self.wall_clock_seconds,
            "budget_seconds": self.budget_seconds,
            "current_wave": self.current_wave,
            "current_issue_id": self.current_issue_id,
            "completed_issues": self.completed_issues,
            "failed_issues": self.failed_issues,
            "skipped_issues": self.skipped_issues,
            "created_artifacts": self.created_artifacts,
            "out_of_scope_findings": self.out_of_scope_findings,
            "validation_results": self.validation_results,
            "checkpoint_count": self.checkpoint_count,
            "cycle_count": self.cycle_count,
            "actions_applied": self.actions_applied,
            "files_created": self.files_created,
            "files_updated": self.files_updated,
            "issues_created": self.issues_created,
            "stop_reason": self.stop_reason,
            "notes": self.notes,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "RunState":
        state = cls(
            run_id=data["run_id"],
            config_name=data["config_name"],
        )
        state.status = RunStatus(data.get("status", "pending"))
        state.phase = RunPhase(data.get("phase", "init"))
        state.started_at = data.get("started_at")
        state.last_updated = data.get("last_updated")
        state.elapsed_seconds = data.get("elapsed_seconds", 0.0)
        state.wall_clock_seconds = data.get("wall_clock_seconds", 0.0)
        state.budget_seconds = data.get("budget_seconds", 144000.0)
        state.current_wave = data.get("current_wave", "wave-1")
        state.current_issue_id = data.get("current_issue_id")
        state.completed_issues = data.get("completed_issues", [])
        state.failed_issues = data.get("failed_issues", [])
        state.skipped_issues = data.get("skipped_issues", [])
        state.created_artifacts = data.get("created_artifacts", [])
        state.out_of_scope_findings = data.get("out_of_scope_findings", [])
        state.validation_results = data.get("validation_results", [])
        state.checkpoint_count = data.get("checkpoint_count", 0)
        state.cycle_count = data.get("cycle_count", 0)
        state.actions_applied = data.get("actions_applied", 0)
        state.files_created = data.get("files_created", 0)
        state.files_updated = data.get("files_updated", 0)
        state.issues_created = data.get("issues_created", 0)
        state.stop_reason = data.get("stop_reason")
        state.notes = data.get("notes", "")
        return state

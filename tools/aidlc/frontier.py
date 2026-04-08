"""Planning frontier assessment for AIDLC runner.

Analyzes the current state of the planning universe to determine what
needs work next. Produces a structured frontier summary that becomes
part of the planning prompt.
"""

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .models import RunState
from .scope_guard import ScopeGuard


@dataclass
class FrontierItem:
    """A single item on the planning frontier."""
    category: str  # missing_doc, underspecified_issue, missing_content, coverage_gap, unblocked_work
    priority: str  # high, medium, low
    description: str
    related_issues: list[str]
    suggested_action: str


class FrontierAssessor:
    """Assesses what planning work needs to happen next."""

    def __init__(self, project_root: Path, scope_guard: ScopeGuard, state: RunState):
        self.project_root = project_root
        self.scope_guard = scope_guard
        self.state = state

    # Strategic priority weights for sorting frontier items.
    # Higher weight = higher priority. Categories are ranked to ensure
    # major structural gaps outweigh minor polishing work.
    CATEGORY_WEIGHTS = {
        "missing_doc": 100,           # Store deep dives, system specs — blocks everything
        "coverage_gap": 80,           # Store content gaps, missing store docs
        "missing_content": 60,        # Content sets not yet created
        "underspecified_issue": 30,   # Issue polishing — important but not blocking
        "unblocked_work": 10,         # Generic unworked items — lowest structural priority
    }

    def assess(self) -> dict:
        """Produce a full frontier assessment.

        Returns a dict with:
        - summary: text summary for the prompt
        - items: list of frontier items (capped to avoid noise)
        - universe_stats: current state metrics
        - focus_issues: list of issue dicts that need attention
        """
        items = []
        items.extend(self._find_missing_deliverables())
        items.extend(self._find_content_gaps())
        items.extend(self._find_underspecified_issues())
        # Unblocked work is capped — we don't want 42 generic items drowning
        # out the strategic gaps above
        unblocked = self._find_unblocked_work()
        items.extend(unblocked[:5])  # Top 5 only

        # Sort by: priority (high > medium > low), then category weight (structural > polish)
        priority_order = {"high": 0, "medium": 1, "low": 2}
        items.sort(key=lambda x: (
            priority_order.get(x["priority"], 9),
            -self.CATEGORY_WEIGHTS.get(x["category"], 0),
        ))

        stats = self._universe_stats()

        # Build focus list: top issues that need attention
        focus_issue_ids = set()
        for item in items[:10]:
            focus_issue_ids.update(item.get("related_issues", []))

        focus_issues = []
        for iid in focus_issue_ids:
            issue = self.scope_guard.get_issue_by_id(iid)
            if issue:
                # Load full issue content
                local_file = issue.get("local_file", "")
                content = ""
                if local_file:
                    path = self.project_root / local_file
                    if path.exists():
                        content = path.read_text()
                focus_issues.append({**issue, "full_content": content})

        summary = self._build_summary(items, stats)

        return {
            "summary": summary,
            "items": items,
            "universe_stats": stats,
            "focus_issues": focus_issues,
        }

    def _universe_stats(self) -> dict:
        """Current state metrics."""
        issues = self.scope_guard.universe.get("issues", [])
        total = len(issues)

        # Count issues by wave
        by_wave = {}
        for issue in issues:
            w = issue.get("wave", "unknown")
            by_wave[w] = by_wave.get(w, 0) + 1

        # Count issues by milestone
        by_milestone = {}
        for issue in issues:
            m = issue.get("milestone", "unknown")
            by_milestone[m] = by_milestone.get(m, 0) + 1

        # Count issues with existing deliverables on disk
        deliverables_exist = 0
        for issue in issues:
            if self._issue_has_deliverables(issue):
                deliverables_exist += 1

        # Count design docs that exist
        design_docs = list((self.project_root / "docs/design").rglob("*.md")) if (self.project_root / "docs/design").exists() else []
        content_files = list((self.project_root / "game/content").rglob("*.json")) if (self.project_root / "game/content").exists() else []

        return {
            "total_issues": total,
            "issues_by_wave": by_wave,
            "issues_by_milestone": by_milestone,
            "issues_with_deliverables": deliverables_exist,
            "design_docs_count": len(design_docs),
            "content_files_count": len(content_files),
            "run_completed_issues": len(self.state.completed_issues),
            "run_actions_applied": self.state.actions_applied,
            "run_files_created": self.state.files_created,
            "run_issues_created": self.state.issues_created,
        }

    def _find_missing_deliverables(self) -> list[dict]:
        """Find issues whose deliverables don't exist on disk yet."""
        items = []
        issues = self.scope_guard.universe.get("issues", [])

        for issue in issues:
            title = issue.get("title", "")
            issue_id = issue["id"]

            # Design doc issues (wave-3 store deep dives, etc.)
            if "design and document" in title.lower() or "design" in issue.get("labels", []):
                expected_paths = self._guess_deliverable_paths(issue)
                missing = [p for p in expected_paths if not (self.project_root / p).exists()]
                if missing:
                    items.append({
                        "category": "missing_doc",
                        "priority": "high" if issue.get("wave") in ("wave-1", "wave-2") else "medium",
                        "description": f"{issue_id}: Design doc deliverable missing — {title}",
                        "related_issues": [issue_id],
                        "suggested_action": f"Create design document(s): {', '.join(missing)}",
                    })

            # Content creation issues
            if "content set" in title.lower() or "content" in issue.get("labels", []):
                # Check if content JSON files exist for this store type
                store_labels = [l for l in issue.get("labels", []) if l.startswith("store:")]
                if store_labels and not self._has_content_for_store(store_labels[0]):
                    items.append({
                        "category": "missing_content",
                        "priority": "medium",
                        "description": f"{issue_id}: Content set not yet created — {title}",
                        "related_issues": [issue_id],
                        "suggested_action": "Create content JSON files for this store type",
                    })

        return items

    def _find_underspecified_issues(self) -> list[dict]:
        """Find issues that are too vague or missing key details."""
        items = []
        issues = self.scope_guard.universe.get("issues", [])

        for issue in issues:
            local_file = issue.get("local_file", "")
            if not local_file:
                continue
            path = self.project_root / local_file
            if not path.exists():
                continue

            content = path.read_text()
            issue_id = issue["id"]

            # Check for short/vague acceptance criteria
            if "## Acceptance Criteria" in content:
                ac_section = content.split("## Acceptance Criteria")[1]
                ac_lines = [l.strip() for l in ac_section.split("\n") if l.strip().startswith("-")]
                if len(ac_lines) < 2:
                    items.append({
                        "category": "underspecified_issue",
                        "priority": "medium",
                        "description": f"{issue_id}: Only {len(ac_lines)} acceptance criteria — needs more detail",
                        "related_issues": [issue_id],
                        "suggested_action": "Add specific, testable acceptance criteria",
                    })
            elif "acceptance" not in content.lower():
                items.append({
                    "category": "underspecified_issue",
                    "priority": "high",
                    "description": f"{issue_id}: No acceptance criteria section",
                    "related_issues": [issue_id],
                    "suggested_action": "Add acceptance criteria section with testable requirements",
                })

            # Check for very short issues (likely stubs)
            if len(content) < 300:
                items.append({
                    "category": "underspecified_issue",
                    "priority": "medium",
                    "description": f"{issue_id}: Issue content is very short ({len(content)} chars) — may need expansion",
                    "related_issues": [issue_id],
                    "suggested_action": "Expand scope, deliverables, and acceptance criteria",
                })

        return items

    def _find_content_gaps(self) -> list[dict]:
        """Find gaps in content coverage across store types."""
        items = []

        # Check each store type has minimum content
        store_types = {
            "store:sports": "sports",
            "store:video-games": "games",
            "store:rentals": "video_rental",
            "store:monster-cards": "fakemon",
            "store:electronics": "electronics",
        }

        content_dir = self.project_root / "game/content/items"
        if content_dir.exists():
            existing_files = list(content_dir.glob("*.json"))
            for store_label, prefix in store_types.items():
                store_files = [f for f in existing_files if prefix in f.name]
                if len(store_files) < 5:
                    items.append({
                        "category": "coverage_gap",
                        "priority": "low",
                        "description": f"Store '{store_label}' has only {len(store_files)} content item(s) — target is 20+",
                        "related_issues": [],
                        "suggested_action": f"Create additional content JSON for {store_label}",
                    })

        # Check for missing store design docs
        stores_doc_dir = self.project_root / "docs/design/stores"
        expected_store_docs = [
            "SPORTS_MEMORABILIA.md",
            "RETRO_GAMES.md",
            "VIDEO_RENTAL.md",
            "POCKETCREATURES.md",
            "ELECTRONICS.md",
        ]
        if stores_doc_dir.exists():
            existing = {f.name for f in stores_doc_dir.glob("*.md")}
        else:
            existing = set()

        for doc in expected_store_docs:
            if doc not in existing:
                items.append({
                    "category": "missing_doc",
                    "priority": "high",
                    "description": f"Store design doc missing: docs/design/stores/{doc}",
                    "related_issues": [],
                    "suggested_action": f"Create docs/design/stores/{doc} with full store deep dive",
                })

        return items

    def _find_unblocked_work(self) -> list[dict]:
        """Find issues that are ready to be worked (deps met) but haven't been touched."""
        items = []
        issues = self.scope_guard.universe.get("issues", [])
        worked = set(self.state.completed_issues)

        for issue in issues:
            issue_id = issue["id"]
            if issue_id in worked:
                continue
            deps = issue.get("dependencies", [])
            # For planning purposes, consider an issue "unblocked" even if deps
            # aren't code-complete — planning work can proceed in parallel
            wave = issue.get("wave", "wave-6")
            if wave in ("wave-1", "wave-2"):
                items.append({
                    "category": "unblocked_work",
                    "priority": "high" if wave == "wave-1" else "medium",
                    "description": f"{issue_id}: {issue.get('title', '')} (unworked, {wave})",
                    "related_issues": [issue_id],
                    "suggested_action": "Review and deepen this issue's planning",
                })

        return items

    def _issue_has_deliverables(self, issue: dict) -> bool:
        """Check if an issue's expected deliverables exist on disk."""
        paths = self._guess_deliverable_paths(issue)
        return any((self.project_root / p).exists() for p in paths) if paths else False

    def _guess_deliverable_paths(self, issue: dict) -> list[str]:
        """Guess likely deliverable file paths from issue title and content."""
        title = issue.get("title", "").lower()
        paths = []

        # Design docs
        if "retro game" in title and "design" in title:
            paths.append("docs/design/stores/RETRO_GAMES.md")
        elif "video rental" in title and "design" in title:
            paths.append("docs/design/stores/VIDEO_RENTAL.md")
        elif "pocketcreatures" in title and "design" in title:
            paths.append("docs/design/stores/POCKETCREATURES.md")
        elif "electronics" in title and "design" in title:
            paths.append("docs/design/stores/ELECTRONICS.md")
        elif "mall environment" in title and "design" in title:
            paths.append("docs/design/MALL_ENVIRONMENT.md")

        return paths

    def _has_content_for_store(self, store_label: str) -> bool:
        """Check if content JSON files exist for a store type."""
        content_dir = self.project_root / "game/content/items"
        if not content_dir.exists():
            return False
        prefix_map = {
            "store:sports": "sports",
            "store:video-games": "games",
            "store:rentals": "video_rental",
            "store:monster-cards": "fakemon",
            "store:electronics": "electronics",
        }
        prefix = prefix_map.get(store_label, "")
        files = list(content_dir.glob(f"*{prefix}*.json"))
        return len(files) >= 5  # Minimum threshold

    def _build_summary(self, items: list[dict], stats: dict) -> str:
        """Build a human-readable frontier summary for the prompt."""
        lines = [
            "## Planning Frontier Assessment",
            "",
            f"**Universe**: {stats['total_issues']} issues across "
            f"{len(stats['issues_by_wave'])} waves and "
            f"{len(stats['issues_by_milestone'])} milestones",
            f"**Design docs on disk**: {stats['design_docs_count']}",
            f"**Content files on disk**: {stats['content_files_count']}",
            f"**Issues with deliverables**: {stats['issues_with_deliverables']}/{stats['total_issues']}",
            "",
            f"**This run so far**: {stats['run_actions_applied']} actions applied, "
            f"{stats['run_files_created']} files created, "
            f"{stats['run_issues_created']} issues created",
            "",
        ]

        if not items:
            lines.append("No frontier items identified — planning may be complete.")
            return "\n".join(lines)

        # Group by category
        by_cat = {}
        for item in items:
            cat = item["category"]
            if cat not in by_cat:
                by_cat[cat] = []
            by_cat[cat].append(item)

        category_labels = {
            "missing_doc": "Missing Design Documents",
            "underspecified_issue": "Underspecified Issues",
            "missing_content": "Missing Content",
            "coverage_gap": "Coverage Gaps",
            "unblocked_work": "Unblocked Work Items",
        }

        for cat, cat_items in by_cat.items():
            label = category_labels.get(cat, cat)
            high = [i for i in cat_items if i["priority"] == "high"]
            med = [i for i in cat_items if i["priority"] == "medium"]
            lines.append(f"### {label} ({len(high)} high, {len(med)} medium priority)")
            for item in cat_items[:5]:  # Top 5 per category
                lines.append(f"- [{item['priority'].upper()}] {item['description']}")
            if len(cat_items) > 5:
                lines.append(f"  ... and {len(cat_items) - 5} more")
            lines.append("")

        return "\n".join(lines)

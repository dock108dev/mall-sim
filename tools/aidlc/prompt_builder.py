"""Prompt assembly for AIDLC runner.

Builds prompts from templates, run state, config, and repo context.
"""

import json
from pathlib import Path
from typing import Optional

from .schemas import OUTPUT_SCHEMA_DESCRIPTION


# Key design docs that provide game context for planning
CONTEXT_DOCS = [
    "docs/design/GAME_PILLARS.md",
    "docs/design/CORE_LOOP.md",
    "docs/design/STORE_TYPES.md",
    "docs/design/PLAYER_EXPERIENCE.md",
    "docs/architecture/SYSTEM_OVERVIEW.md",
    "docs/architecture/DATA_MODEL.md",
    "ARCHITECTURE.md",
    "ROADMAP.md",
]

# Max chars per doc to keep prompt size manageable
MAX_DOC_CHARS = 8000


class PromptBuilder:
    """Assembles prompts for Claude CLI from templates and context."""

    def __init__(self, project_root: Path, config: dict):
        self.project_root = project_root
        self.config = config
        self.templates_dir = Path(__file__).parent / "templates"

    def build_planning_prompt(
        self,
        frontier_assessment: dict,
        run_context: dict,
        is_finalization: bool = False,
    ) -> str:
        """Build the main planning-generation prompt.

        This is the core prompt for the frontier-based planning loop.
        It gives Claude:
        1. Game design context (pillars, stores, architecture)
        2. Current universe state (all issues as a summary table)
        3. Frontier assessment (what needs work)
        4. Focus issues (full content for priority items)
        5. Structured output schema
        6. Instructions appropriate to the current phase
        """
        sections = []

        # 1. Project identity
        sections.append(self._build_project_context())

        # 2. Game design context (key docs)
        sections.append(self._build_design_context())

        # 3. Current issue universe (summary table)
        sections.append(self._build_universe_table())

        # 4. Frontier assessment
        sections.append(frontier_assessment["summary"])

        # 5. Focus issues (full content for items Claude should work on)
        if frontier_assessment.get("focus_issues"):
            sections.append(self._build_focus_issues(frontier_assessment["focus_issues"]))

        # 6. Run state
        sections.append(self._build_run_state(run_context))

        # 7. Phase-specific instructions
        if is_finalization:
            sections.append(self._build_finalization_instructions())
        else:
            sections.append(self._build_planning_instructions())

        # 8. Output schema
        sections.append(OUTPUT_SCHEMA_DESCRIPTION)

        return "\n\n---\n\n".join(sections)

    def _build_project_context(self) -> str:
        return """# Project: mallcore-sim

A nostalgic retail management simulator set in a 2000s mall, built in Godot 4.3+ (GDScript).

**Store pillars**: Sports Memorabilia, Retro Games, Video Rental, PocketCreatures Cards, Consumer Electronics
**Scale targets**: 250+ items, 5 store types, 20+ customer archetypes, 30-hour core completion
**Non-negotiable pillars**: Nostalgic Retail Fantasy, Player-Driven Business, Cozy Simulation, Collector Culture, Modular Variety"""

    def _build_design_context(self) -> str:
        """Load and concatenate key design documents."""
        sections = ["## Game Design Context\n"]
        for doc_path in CONTEXT_DOCS:
            full_path = self.project_root / doc_path
            if full_path.exists():
                content = full_path.read_text()
                if len(content) > MAX_DOC_CHARS:
                    content = content[:MAX_DOC_CHARS] + "\n\n... (truncated)"
                sections.append(f"### {doc_path}\n\n{content}")
        return "\n\n".join(sections)

    def _build_universe_table(self) -> str:
        """Build a condensed summary of the issue universe.

        Instead of a full 85-row table every cycle, provides:
        - Counts by wave and milestone
        - A compact ID→title index (one line per issue, no deps/labels)
        This cuts ~60% of prompt tokens compared to the full table.
        """
        universe_path = self.project_root / self.config.get(
            "universe_manifest",
            "planning/manifests/final-issue-universe.json",
        )
        if not universe_path.exists():
            return "## Issue Universe\n\nNo universe manifest found."

        with open(universe_path) as f:
            universe = json.load(f)

        issues = universe.get("issues", [])

        # Counts by wave
        by_wave = {}
        for issue in issues:
            w = issue.get("wave", "?")
            by_wave[w] = by_wave.get(w, 0) + 1

        # Counts by milestone
        by_milestone = {}
        for issue in issues:
            m = issue.get("milestone", "?")
            by_milestone[m] = by_milestone.get(m, 0) + 1

        lines = [
            "## Issue Universe Summary",
            "",
            f"Total: {len(issues)} issues",
            "",
            "**By wave**: " + ", ".join(f"{w}: {c}" for w, c in sorted(by_wave.items())),
            "**By milestone**: " + ", ".join(f"{m}: {c}" for m, c in sorted(by_milestone.items())),
            "",
            "### Issue Index",
            "",
        ]
        for issue in issues:
            lines.append(f"- {issue['id']}: {issue['title']} [{issue.get('wave', '?')}]")

        return "\n".join(lines)

    def _build_focus_issues(self, focus_issues: list[dict]) -> str:
        """Include full content for priority issues Claude should focus on."""
        sections = [
            "## Focus Issues (Full Content)",
            "",
            "These issues are on the current planning frontier. Read them carefully.",
            "",
        ]
        for issue in focus_issues[:8]:  # Cap at 8 to manage prompt size
            sections.append(f"### {issue['id']}: {issue.get('title', '')}")
            sections.append(f"**Wave**: {issue.get('wave', '?')}")
            sections.append(f"**Milestone**: {issue.get('milestone', '?')}")
            content = issue.get("full_content", "")
            if content:
                sections.append(content)
            sections.append("")
        return "\n\n".join(sections)

    def _build_run_state(self, run_context: dict) -> str:
        return f"""## Current Run State

- **Phase**: {run_context.get('phase', 'planning')}
- **Cycle**: {run_context.get('cycle_count', 0)}
- **Elapsed (Claude time)**: {run_context.get('elapsed_hours', 0):.1f}h / {run_context.get('budget_hours', 40):.0f}h
- **Actions applied this run**: {run_context.get('actions_applied', 0)}
- **Files created this run**: {run_context.get('files_created', 0)}
- **Issues created this run**: {run_context.get('issues_created', 0)}"""

    def _build_planning_instructions(self) -> str:
        return """## Instructions — Planning Mode

You are an active planning agent for mallcore-sim. Your job is to **create and refine the planning universe**.

Based on the frontier assessment above, choose the most impactful actions to take RIGHT NOW.

**What you should do:**
- Create missing design documents (store deep dives, system specs, content catalogs)
- Create missing content definitions (item JSON files for stores)
- Refine underspecified issues (add acceptance criteria, deliverables, scope details)
- Split issues that are too large into sub-tasks
- Create new issues for genuinely missing work that no existing issue covers
- Fix dependency edges that are missing or incorrect
- Write planning artifacts that help implementation proceed

**What you should NOT do:**
- Write GDScript implementation code (that's implementation phase, not planning)
- Create Godot scene files
- Expand the game's scope beyond the 5 defined store types
- Create work items outside the project's defined milestones
- Duplicate existing content or issues

**Priority order:**
1. High-priority frontier items (missing design docs for wave-1/wave-2 issues)
2. Content gaps (stores with < 5 content items)
3. Underspecified issues (missing acceptance criteria)
4. Coverage gaps (areas without issue coverage)

Produce 1-10 high-quality actions. Each action must have a clear rationale.
Quality over quantity — one well-written design doc is worth more than five stubs."""

    def _build_finalization_instructions(self) -> str:
        """Instructions for finalization mode (last portion of budget)."""
        freeze_path = self.project_root / self.config.get(
            "freeze_manifest",
            "planning/manifests/closed-universe-freeze.json",
        )
        prohibited = []
        if freeze_path.exists():
            with open(freeze_path) as f:
                freeze = json.load(f)
            prohibited = freeze.get("prohibited_actions", [])

        prohibited_text = "\n".join(f"- {p}" for p in prohibited)

        return f"""## Instructions — FINALIZATION MODE

The planning budget is nearly exhausted. You are in finalization mode.

**What you MUST do:**
1. Complete any in-progress artifacts to a reviewable state
2. Verify existing issues have adequate acceptance criteria
3. Check for and fix duplicate or contradictory content
4. Ensure dependency graph is complete and consistent
5. Log any remaining gaps as out_of_scope_findings

**What you MUST NOT do:**
{prohibited_text}

Produce only consolidation and cleanup actions. No new work."""

    def build_issue_work_prompt(
        self,
        issue: dict,
        issue_file_content: str,
        run_context: dict,
    ) -> str:
        """Build a prompt for working on a specific issue."""
        template = self._load_template("work_issue.md")
        if not template:
            template = self._default_work_template()

        return template.format(
            issue_id=issue["id"],
            issue_title=issue["title"],
            issue_content=issue_file_content,
            wave=issue.get("wave", "unknown"),
            milestone=issue.get("milestone", "unknown"),
            labels=", ".join(issue.get("labels", [])),
            dependencies=", ".join(issue.get("dependencies", [])),
            run_phase=run_context.get("phase", "planning"),
            completed_so_far=run_context.get("completed_count", 0),
            total_issues=run_context.get("total_issues", 85),
            project_name=self.config.get("project_name", "mall-sim"),
        )

    def build_validation_prompt(self, validation_context: dict) -> str:
        """Build a prompt for a validation pass."""
        template = self._load_template("validation_pass.md")
        if not template:
            template = self._default_validation_template()

        return template.format(
            completed_issues=validation_context.get("completed_issues", []),
            created_artifacts=validation_context.get("created_artifacts", []),
            current_wave=validation_context.get("current_wave", "wave-1"),
            issues_found=validation_context.get("issues_found", "none"),
        )

    def build_finalization_prompt(self, run_summary: dict) -> str:
        """Build the finalization prompt for end-of-run wrap-up."""
        template = self._load_template("finalization.md")
        if not template:
            template = self._default_finalization_template()

        return template.format(
            total_completed=run_summary.get("total_completed", 0),
            total_failed=run_summary.get("total_failed", 0),
            total_skipped=run_summary.get("total_skipped", 0),
            artifacts_created=run_summary.get("artifacts_created", 0),
            elapsed_hours=run_summary.get("elapsed_hours", 0),
            out_of_scope=run_summary.get("out_of_scope", []),
        )

    def build_finalization_issue_prompt(
        self,
        issue: dict,
        issue_file_content: str,
        run_context: dict,
    ) -> str:
        """Build a finalization-mode prompt for working on an issue.

        Same context as the normal work prompt, but wrapped with finalization
        rules that prohibit new work and scope expansion.
        """
        # Load freeze rules for prohibited actions
        freeze_path = self.project_root / self.config.get(
            "freeze_manifest",
            "planning/manifests/closed-universe-freeze.json",
        )
        prohibited = []
        if freeze_path.exists():
            import json
            with open(freeze_path) as f:
                freeze = json.load(f)
            prohibited = freeze.get("prohibited_actions", [])

        prohibited_text = "\n".join(f"- {p}" for p in prohibited) if prohibited else "- No new issues, tasks, or categories"

        base_prompt = self.build_issue_work_prompt(issue, issue_file_content, run_context)

        return f"""## FINALIZATION MODE ACTIVE

You are in the final phase of the planning run. The budget is nearly exhausted.

### Finalization Rules
1. **DO NOT** create new issues, tasks, or planning categories
2. **DO NOT** expand scope beyond what this issue defines
3. **ONLY** finish, consolidate, verify, and deduplicate existing work
4. If this issue is incomplete, do minimal work to bring it to a reviewable state
5. If this issue reveals missing work, log it as an out-of-scope finding — do not do it

### Prohibited Actions
{prohibited_text}

---

{base_prompt}"""

    def _load_template(self, name: str) -> Optional[str]:
        """Load a template file if it exists."""
        path = self.templates_dir / name
        if path.exists():
            return path.read_text()
        return None

    def _default_work_template(self) -> str:
        return """You are working on the {project_name} project.

## Current Task: {issue_id} — {issue_title}

**Wave**: {wave}
**Milestone**: {milestone}
**Labels**: {labels}
**Dependencies**: {dependencies}

## Issue Details

{issue_content}

## Run Context

- Phase: {run_phase}
- Completed so far: {completed_so_far}/{total_issues}

## Instructions

Work this issue to completion. Follow the acceptance criteria exactly.
Update any relevant repo docs or code as needed.
Do not expand scope beyond what this issue defines.
"""

    def _default_validation_template(self) -> str:
        return """Run a validation pass on the current planning state.

Check:
1. All completed issues have their deliverables present
2. No SSOT conflicts introduced
3. Dependencies are respected (nothing completed before its deps)
4. No duplicate artifacts
5. Scope guard: no work outside the closed universe

Current wave: {current_wave}
Completed issues: {completed_issues}
Artifacts created: {created_artifacts}
Known issues: {issues_found}
"""

    def _default_finalization_template(self) -> str:
        return """Enter finalization mode for this planning run.

## Run Summary
- Completed: {total_completed}
- Failed: {total_failed}
- Skipped: {total_skipped}
- Artifacts created: {artifacts_created}
- Elapsed time: {elapsed_hours:.1f} hours

## Finalization Tasks
1. Finish any in-progress artifacts
2. Deduplicate and consolidate tasks/issues
3. Normalize labels, milestones, and dependencies
4. Close invalid or redundant work items
5. Produce final planning report

## Rules
- Do NOT create new issues or planning categories
- Do NOT expand scope
- Only finish, consolidate, and report

## Out-of-Scope Findings to Document
{out_of_scope}
"""

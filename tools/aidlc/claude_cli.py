"""Claude CLI integration for AIDLC runner.

Constructs and executes Claude CLI commands, captures output,
handles failures and retries.

IMPORTANT: This module shells out to `claude` CLI. The CLI must be
installed and authenticated before use. This module does NOT mock
or simulate Claude responses — it calls the real CLI.
"""

import json
import re
import subprocess
import time
from pathlib import Path
from typing import Optional
import logging

# Patterns that indicate transient (infrastructure) failures vs issue-level failures
_TRANSIENT_PATTERNS = re.compile(
    r"rate.?limit|connection|timeout|API error|overloaded|503|502|429|ECONNRESET",
    re.IGNORECASE,
)


class ClaudeCLIError(Exception):
    """Raised when Claude CLI invocation fails."""
    pass


class ClaudeCLI:
    """Wrapper around the Claude CLI for structured agent work."""

    def __init__(self, config: dict, logger: logging.Logger):
        self.config = config
        self.logger = logger
        self.cli_command = config.get("claude_cli_command", "claude")
        self.model = config.get("claude_model", "opus")
        self.max_retries = config.get("retry_max_attempts", 2)
        self.retry_delay = config.get("retry_delay_seconds", 30)
        self.timeout = config.get("claude_timeout_seconds", 600)
        self.dry_run = config.get("dry_run", False)

    def execute_prompt(
        self,
        prompt: str,
        working_dir: Path,
        context_files: list[str] | None = None,
        output_format: str = "text",
    ) -> dict:
        """Execute a prompt via Claude CLI.

        Args:
            prompt: The prompt text to send
            working_dir: Directory to run claude from
            context_files: Optional list of file paths to include
            output_format: "text" or "json"

        Returns:
            dict with keys: success, output, error, duration_seconds, retries
        """
        if self.dry_run:
            self.logger.info("[DRY RUN] Would execute Claude CLI prompt:")
            self.logger.info(f"  Working dir: {working_dir}")
            self.logger.info(f"  Prompt length: {len(prompt)} chars")
            if context_files:
                self.logger.info(f"  Context files: {len(context_files)}")
            return {
                "success": True,
                "output": "[DRY RUN] No actual Claude CLI execution",
                "error": None,
                "duration_seconds": 0.0,
                "retries": 0,
            }

        # Build command
        cmd = [self.cli_command, "--print", "--dangerously-skip-permissions"]
        if output_format == "json":
            cmd.append("--output-format=json")

        result = None
        retries = 0

        for attempt in range(self.max_retries + 1):
            start = time.time()
            try:
                self.logger.debug(
                    f"Claude CLI attempt {attempt + 1}/{self.max_retries + 1}"
                )
                proc = subprocess.run(
                    cmd,
                    input=prompt,
                    capture_output=True,
                    text=True,
                    cwd=str(working_dir),
                    timeout=self.timeout,
                )
                duration = time.time() - start

                if proc.returncode == 0:
                    return {
                        "success": True,
                        "output": proc.stdout,
                        "error": None,
                        "failure_type": None,
                        "duration_seconds": duration,
                        "retries": retries,
                    }
                else:
                    stderr_text = proc.stderr or ""
                    failure_type = self._classify_failure(
                        proc.returncode, stderr_text
                    )
                    self.logger.warning(
                        f"Claude CLI returned {proc.returncode} "
                        f"({failure_type}): {stderr_text[:200]}"
                    )
                    retries += 1
                    if attempt < self.max_retries:
                        self.logger.info(f"Retrying in {self.retry_delay}s...")
                        time.sleep(self.retry_delay)

            except subprocess.TimeoutExpired:
                duration = time.time() - start
                self.logger.error(
                    f"Claude CLI timed out after {duration:.0f}s (transient)"
                )
                retries += 1
                if attempt < self.max_retries:
                    time.sleep(self.retry_delay)

            except FileNotFoundError:
                raise ClaudeCLIError(
                    f"Claude CLI not found at '{self.cli_command}'. "
                    "Install it or update claude_cli_command in config."
                )

        # Default to transient when uncertain (safer — avoids blaming the issue)
        return {
            "success": False,
            "output": None,
            "error": f"Failed after {retries} retries",
            "failure_type": "transient",
            "duration_seconds": 0.0,
            "retries": retries,
        }

    @staticmethod
    def _classify_failure(returncode: int, stderr: str) -> str:
        """Classify a CLI failure as 'transient' (infrastructure) or 'issue' (bad prompt/content)."""
        # Signal-killed processes (returncode > 128 on Unix) are transient
        if returncode > 128 or returncode < 0:
            return "transient"
        # Check stderr for known transient patterns
        if _TRANSIENT_PATTERNS.search(stderr):
            return "transient"
        # Non-zero exit with no transient pattern — likely an issue-level problem
        return "issue"

    def check_available(self) -> bool:
        """Check if Claude CLI is installed and accessible."""
        if self.dry_run:
            return True
        try:
            result = subprocess.run(
                [self.cli_command, "--version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

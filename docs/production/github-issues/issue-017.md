# Issue 017: Add content validation to CI workflow

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `ci`, `phase:m1`, `priority:medium`
**Dependencies**: issue-016

## Why This Matters

Content validation must run automatically on every PR to prevent broken JSON from being merged. Manual validation is unreliable as the content set grows to 143+ items across 20+ files.

## Current State

A GitHub Actions workflow exists at `.github/workflows/ci.yml` (created during Phase 0 scaffolding). Issue-016 creates the Python validation script at `tools/validate_content.py`. This issue wires the script into the CI pipeline.

## Implementation Details

### Workflow Job

Add a `validate-content` job to `.github/workflows/ci.yml`:

```yaml
jobs:
  validate-content:
    name: Validate Content JSON
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Run content validation
        run: python tools/validate_content.py

      - name: Upload validation report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: content-validation-report
          path: validation-report.txt
          retention-days: 7
```

### Script Exit Codes

Per issue-016 spec, `validate_content.py` exits:
- `0` — all validations pass
- `1` — one or more errors found

Warnings (non-Array files, missing optional fields) print to stdout but don't cause failure.

### Trigger Conditions

The workflow should run on:
- Pull requests that modify files in `game/content/**`
- Pull requests that modify `tools/validate_content.py`
- Push to `main` branch

Add path filters to avoid running validation on unrelated PRs:

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'game/content/**'
      - 'tools/validate_content.py'
  pull_request:
    paths:
      - 'game/content/**'
      - 'tools/validate_content.py'
```

### Branch Protection

After the workflow is verified working, enable branch protection on `main` requiring the `validate-content` job to pass before merge. This is a manual GitHub settings step, not automated.

## Deliverables

- Updated `.github/workflows/ci.yml` with `validate-content` job
- Path-filtered triggers for content and validation script changes
- Failure artifact upload for debugging
- Documented branch protection recommendation

## Acceptance Criteria

- CI runs validation on PRs that touch `game/content/**`
- CI passes when all content is valid
- CI fails when content has errors (test by introducing a broken field)
- CI skips validation on PRs that don't touch content files
- Validation output is visible in the GitHub Actions log
- On failure, validation report is available as a downloadable artifact
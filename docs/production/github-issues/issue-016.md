# Issue 016: Build JSON schema validation script for content pipeline

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tools`, `data`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

With 800+ items eventually, manual validation is impossible. Tooling prevents schema rot.

## Scope

Python or GDScript tool that validates all JSON content files against the DATA_MODEL.md schema. Checks required fields, valid enum values (rarity, condition), unique IDs, correct types.

## Deliverables

- tools/validate_content.py (or .gd)
- Validates: required fields present, rarity in valid set, conditions in valid set, IDs unique across files, base_price is positive number
- Exit code 0 on pass, 1 on fail
- Human-readable error messages

## Acceptance Criteria

- Valid content: exits 0, no errors
- Missing required field: exits 1, names the field and file
- Duplicate ID: exits 1, names both files
- Invalid rarity value: exits 1, names the value

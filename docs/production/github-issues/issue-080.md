# Issue 080: Create secret thread clue content definitions (15-25 clues)

**Wave**: wave-6
**Milestone**: M6 Long-tail + Secret Thread
**Labels**: `content`, `secret-thread`, `data`, `phase:m4plus`, `priority:low`
**Dependencies**: issue-079

## Why This Matters

Clue content is what the player actually encounters. Framework is nothing without content.

## Scope

Define 15-25 clue entries across categories: environmental, communication, customer behavior, inventory anomaly, temporal. Each clue has: id, category, trigger_condition, delivery_mechanism, awareness_delta, participation_options.

## Deliverables

- game/content/secret/clues.json with 15-25 entries
- Clues spread across all 5 categories from SECRET_THREAD.md
- 5 guaranteed 'something weird' moments from the framework
- Each clue has trigger conditions and delivery mechanism
- Participation options define score deltas

## Acceptance Criteria

- Clues cover all 5 delivery categories
- Guaranteed moments are included
- Trigger conditions are implementable
- Awareness/participation deltas are reasonable
- Clues don't reference systems that don't exist

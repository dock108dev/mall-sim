# Issue 039: Create content generation templates for each store type

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `tools`, `content`, `data`, `phase:m2`, `priority:medium`
**Dependencies**: issue-016, issue-032

## Why This Matters

Templates prevent schema drift during bulk content creation.

## Scope

Template JSON files with placeholder values for each store type. Include store-specific fields. Used as starting point for bulk content authoring.

## Deliverables

- tools/templates/item_template_sports.json
- tools/templates/item_template_games.json
- tools/templates/item_template_rental.json
- tools/templates/item_template_fakemon.json
- tools/templates/item_template_electronics.json
- Each matches the normalized schema with store-specific optional fields

## Acceptance Criteria

- Each template passes content validation
- Templates include all required fields with placeholder values
- Store-specific fields (depreciates, appreciates, etc.) present where relevant

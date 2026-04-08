# Issue 051: Create retro game content set (20-30 items)

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `content`, `store:video-games`, `data`, `phase:m3`, `priority:medium`
**Dependencies**: issue-041, issue-016

## Why This Matters

Second store needs enough content to be playable.

## Scope

20-30 retro game items across 2-3 fictional platforms. Cartridges (loose/CIB), consoles, accessories, strategy guides. Spread across rarity tiers.

## Deliverables

- game/content/items/retro_games.json with 20-30 items
- Mix of loose carts, CIB, consoles, accessories
- 2-3 fictional platform names
- Appropriate condition_ranges per type

## Acceptance Criteria

- Passes content validation
- Items span multiple categories and platforms
- CIB items have condition_range including near_mint/mint
- Loose items exclude mint

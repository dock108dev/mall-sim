# Content Scale Specification

This document defines the target content scale for mallcore-sim across all store types. It establishes item counts, rarity distributions, category breakdowns, and content organization strategies.

---

## Scale Overview

### Current State (Cycle 7)

| Store | Items | Categories | Rarity Tiers | Price Range |
|---|---|---|---|---|
| Sports Memorabilia | 19 | 4 | 5 | $1.50–$1,200 |
| Retro Games | 28 | 5 | 5 | $5–$350 |
| Video Rental | 30 | 4 | 5 | $2–$125 |
| PocketCreatures | 38 | 5 | 5 | $0.50–$500 |
| Consumer Electronics | 28 | 5 | 5 | $5–$400 |
| **Total** | **143** | — | — | — |

### Target Scale

The game targets a **30-hour core completion** with 5 store types running simultaneously. Content must sustain novelty across that span.

| Store | M1 Target | M3 Target | Full Target | Rationale |
|---|---|---|---|---|
| Sports Memorabilia | 19 (done) | 40-50 | 80-100 | Era expansion (60s-2000s), more players/teams |
| Retro Games | 28 (done) | 50-60 | 100-120 | More platforms, import variants, accessories |
| Video Rental | 30 (done) | 50-60 | 80-100 | Genre depth, franchise sequels, seasonal titles |
| PocketCreatures | 38 (done) | 60-80 | 120-150 | Set expansions, foil variants, tournament staples |
| Consumer Electronics | 28 (done) | 45-55 | 80-100 | Product generations, brand variants, bundles |
| **Total** | **143** | **245-305** | **460-570** | — |

**Note**: The original 800-1500 target assumed procedural variant generation (e.g., auto-generating condition/era variants of base items). The hand-authored target is 460-570 unique item definitions. The runtime variety comes from ItemInstance condition rolls, price variation, and market dynamics — not from needing 1500 distinct JSON entries.

## Rarity Distribution

Target distribution per store, expressed as percentages of total items:

| Rarity | % of Items | Purpose | Price Multiplier |
|---|---|---|---|
| Common | 35-40% | Bread-and-butter stock, high turnover | 1.0x |
| Uncommon | 25-30% | Interesting finds, moderate margin | 2.5x |
| Rare | 15-20% | Destination items, collector bait | 6.0x |
| Very Rare | 8-12% | Trophy items, significant investment | 15.0x |
| Legendary | 2-5% | Aspirational, once-per-playthrough finds | 40.0x |

### Distribution by Store (Current vs Target)

| Store | Common | Uncommon | Rare | Very Rare | Legendary |
|---|---|---|---|---|---|
| Sports (19) | 4 (21%) | 4 (21%) | 3 (16%) | 3 (16%) | 1 (5%) |
| Retro (28) | 10 (36%) | 6 (21%) | 5 (18%) | 3 (11%) | 1 (4%) |
| Video (30) | 12 (40%) | 8 (27%) | 5 (17%) | 3 (10%) | 2 (7%) |
| Pocket (38) | 14 (37%) | 10 (26%) | 7 (18%) | 4 (11%) | 3 (8%) |
| Electronics (28) | 10 (36%) | 8 (29%) | 5 (18%) | 3 (11%) | 2 (7%) |

Current distributions are close to target. PocketCreatures legendary count (3) is slightly high at 8% — acceptable for a TCG store where chase cards are thematically important.

## Category Breakdowns

### Sports Memorabilia

| Category | Current | Target (Full) | Notes |
|---|---|---|---|
| Trading cards (singles) | 11 | 40-50 | Expand eras: 60s, 70s, 80s, 90s, 00s. Add more sports (football, hockey) |
| Sealed packs | 2 | 10-15 | One per era/sport combination |
| Sealed product (boxes, sets) | 2 | 10-15 | Hobby boxes, factory sets, case breaks |
| Memorabilia | 4 | 15-20 | Jerseys, signed items, equipment per sport |

### Retro Games

| Category | Current | Target (Full) | Notes |
|---|---|---|---|
| Cartridges (loose) | 12 | 35-45 | Cover all fictional platforms, genre spread |
| Cartridges (CIB/NIB) | 3 | 15-20 | Premium variants of popular loose titles |
| Consoles | 4 | 12-15 | Working, for-parts, CIB variants per platform |
| Accessories | 4 | 15-20 | Controllers, memory cards, cables per platform |
| Guides/magazines | 2 | 8-10 | Strategy guides, gaming magazines |
| Imports | 2 | 8-10 | JP and PAL exclusives |

### Video Rental

| Category | Current | Target (Full) | Notes |
|---|---|---|---|
| VHS tapes | ~20 | 40-50 | Genre coverage: action, comedy, horror, drama, family, sci-fi |
| DVDs | ~6 | 20-25 | Premium format, same genre spread |
| Snacks | ~2 | 8-10 | Candy, popcorn, drinks — impulse buys |
| Merchandise | ~2 | 8-12 | Posters, standees, promo items |

### PocketCreatures Cards

| Category | Current | Target (Full) | Notes |
|---|---|---|---|
| Singles (common/uncommon) | ~15 | 50-60 | Element types, evolution stages |
| Singles (rare/holo) | ~8 | 20-25 | Holographic, full art variants |
| Booster packs | ~5 | 10-15 | One per set expansion |
| Sealed boxes/cases | ~3 | 8-10 | Investment-grade sealed product |
| Accessories | ~4 | 10-15 | Sleeves, binders, playmats, deck boxes |
| Starter decks | ~3 | 5-8 | Entry-level product per element type |

### Consumer Electronics

| Category | Current | Target (Full) | Notes |
|---|---|---|---|
| Portable music | ~6 | 15-20 | MP3 players, CD players, minidisc across brands |
| Portable gaming | ~5 | 15-20 | Handhelds, cartridges, accessories |
| Audio | ~6 | 15-20 | Headphones, speakers, clock radios |
| Gadgets | ~6 | 15-20 | Cameras, PDAs, USB drives, novelty tech |
| Accessories | ~5 | 15-20 | Cases, chargers, cables, screen protectors |

## Content File Organization

### Current Structure (Per-Store Files)

```
game/content/items/
  sports_memorabilia_cards.json    # 19 items
  retro_games.json                 # 28 items
  video_rental.json                # 30 items
  pocket_creatures.json            # 38 items
  consumer_electronics.json        # 28 items
```

This structure works well up to ~60 items per file. Beyond that, consider splitting.

### Recommended Split Point (100+ items per store)

When a store exceeds 80-100 items, split by category:

```
game/content/items/
  sports/
    trading_cards.json
    sealed_product.json
    memorabilia.json
  retro_games/
    cartridges.json
    consoles.json
    accessories.json
    guides_and_imports.json
```

DataLoader should support both flat files and directory-based organization. When it encounters a subdirectory in `items/`, it should load all `.json` files within it.

### Naming Convention

Item IDs follow the pattern: `{store_type}_{item_name}_{variant}`

Examples:
- `sports_griffey_rookie` (base item)
- `retro_sonic2_cart_loose` (with variant)
- `pocket_flamefox_holo` (with variant)
- `electronics_zune_30gb` (with spec)

## Store-Specific Metadata

Each store type has optional fields beyond the base item schema. These are preserved in the `extra` Dictionary on ItemDefinition:

| Store | Extra Fields | Purpose |
|---|---|---|
| Sports | `era`, `sport`, `team`, `player`, `authenticated` | Season cycle, authentication mechanic |
| Retro Games | `platform`, `region`, `completeness` | Platform filtering, import identification |
| Video Rental | `rental_period_days`, `genre`, `format` | Rental lifecycle, recommendation engine |
| PocketCreatures | `set_name`, `element`, `evolution_stage`, `is_holographic` | Set tracking, meta shifts, pack opening |
| Electronics | `brand`, `generation`, `warranty_eligible` | Depreciation, warranty upsell |

These fields are documented per-store in `docs/architecture/RESOURCE_CLASS_SPEC.md`.

## Content Quality Standards

Every item definition must meet these standards:

1. **Unique, evocative name**: Parody/homage names that capture the era without trademark issues
2. **Meaningful description**: 1-2 sentences of flavor text that grounds the item in the 2000s mall setting
3. **Accurate pricing**: Base price reflects real-world equivalent at "good" condition (adjusted for fictional branding)
4. **Appropriate rarity**: Rarity should reflect both real-world scarcity and gameplay balance
5. **Complete tags**: At least 2-3 tags for customer preference matching
6. **Valid condition range**: Loose/used items exclude "mint"; sealed/new items include full range

## Content Authoring Workflow

1. **Determine category gaps**: Check current counts against target distribution
2. **Draft items in JSON**: Follow the schema in `docs/architecture/DATA_MODEL.md`
3. **Cross-validate**: Ensure item categories match store definition's `allowed_categories`
4. **Price check**: Verify price range supports all customer budget tiers for that store
5. **Run validation**: Execute `tools/validate_content.py` (issue-016) to catch schema errors
6. **Test in DataLoader**: Boot game and verify items load (issue-001)

## Expansion Strategy

Content expansion happens in phases aligned with milestones:

- **M1 (current)**: Minimum viable content per store (15-30 items). Focus on category coverage and rarity spread.
- **M3**: Double content per store (40-60 items). Add depth within categories — more era variants, platform coverage, genre spread.
- **M4+**: Full content target (80-150 items). Add seasonal items, event-exclusive items, secret thread clue items.

Each expansion pass should maintain the target rarity distribution. Resist the temptation to add mostly rare/legendary items — common items are the economic foundation.
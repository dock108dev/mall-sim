# Sports Store: Legendary Item Addition

The sports_memorabilia_cards.json needs 1 legendary item added to complete the rarity spread.

## Proposed Item

```json
{
  "id": "sports_mantle_1952_psa",
  "name": "1952 Topps Mickey Mantle PSA 6",
  "description": "The holy grail of baseball cards. A PSA 6 is as good as you'll find outside a museum. Handle with extreme care.",
  "category": "trading_cards",
  "subcategory": "singles",
  "store_type": "sports",
  "base_price": 1200.00,
  "rarity": "legendary",
  "condition_range": ["good", "near_mint"],
  "tags": ["baseball", "vintage", "50s", "HOF", "iconic", "graded", "investment"],
  "appreciates": true
}
```

This item:
- Fills the legendary rarity gap (currently 0 legendary in sports)
- Gives the Card Investor customer type a high-end target
- Creates a chase item for late-game progression
- Base price $1200 with legendary multiplier = $48,000 market value at good condition
- Only appears via tier-3 suppliers or special events

## Action

Append this item to `game/content/items/sports_memorabilia_cards.json` during implementation.

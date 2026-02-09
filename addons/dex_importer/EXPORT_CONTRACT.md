# Export Contract — Dex → Game Data Endpoint

> **Version**: 3
> **Purpose**: Defines the JSON shape the game-side importer expects from the dex export endpoint. The dex team implements `GET /export/game` to match this contract exactly.

---

## Endpoint

### `GET /export/game`

Bulk export of the entire game-relevant dataset. No pagination. Single JSON response.

---

## Response Shape

```jsonc
{
  "version": 3,
  "exported_at": "2026-02-08T12:00:00.000Z",

  "lookups": {
    "elements": [{ "name": "Null" }, { "name": "Fire" } /* ...all 11 */],
    "attributes": [{ "name": "None" }, { "name": "Vaccine" } /* ...all 7 */],
    "evolution_types": [{ "name": "Standard" } /* ...all 7 */],
    "trait_categories": [
      { "name": "Size", "max_traits": 1 },
      { "name": "Movement", "max_traits": null },
      { "name": "Type", "max_traits": 1 },
      { "name": "Element", "max_traits": null }
    ]
  },

  "traits": [
    { "name": "Tiny", "category": "Size" },
    { "name": "Medium", "category": "Size" },
    { "name": "Dragon", "category": "Type" },
    { "name": "Fire", "category": "Element" },
    { "name": "Terrestrial", "category": "Movement" }
    // ...all traits
  ],

  "techniques": [
    {
      "game_id": "pepper_breath",
      "jp_name": "Baby Flame",
      "dub_name": "Pepper Breath",
      "name": null,
      "description": null,
      "mechanic_description": null,
      "class": "Physical",
      "priority": 0,
      "targeting": "SingleFoe",
      "energy_cost": 10,
      "accuracy": 95,
      "element": "Fire",
      "bricks": [/* raw JSON */]
    }
  ],

  "abilities": [
    {
      "game_id": "blaze",
      "name": "Blaze",
      "description": null,
      "mechanic_description": null,
      "trigger": "onHpThreshold",
      "stack_limit": "oncePerBattle",
      "trigger_condition": null,
      "bricks": [/* raw JSON */]
    }
  ],

  "items": [
    {
      "game_id": "potion",
      "name": "Potion",
      "description": "Restores 50 HP.",
      "mechanic_description": null,
      "category": "Medicine",
      "is_consumable": true,
      "is_combat_usable": true,
      "is_revive": false,
      "buy_price": 200,
      "sell_price": 100,
      "has_icon": true,
      "gear_slot": null,
      "trigger": null,
      "stack_limit": null,
      "trigger_condition": null,
      "bricks": [{"brick": "healing", "type": "fixed", "amount": 50}]
    },
    {
      "game_id": "power_band",
      "name": "Power Band",
      "description": "Boosts damage dealt by 20%.",
      "mechanic_description": null,
      "category": "Gear",
      "is_consumable": false,
      "is_combat_usable": false,
      "is_revive": false,
      "buy_price": 5000,
      "sell_price": 2500,
      "has_icon": true,
      "gear_slot": "Equipable",
      "trigger": "continuous",
      "stack_limit": "unlimited",
      "trigger_condition": null,
      "bricks": [{"brick": "damageModifier", "multiplier": 1.2}]
    }
  ],

  "digimon": [
    {
      "game_id": "yukidarumon",
      "jp_name": "Yukidarumon",
      "dub_name": "Frigimon",
      "name": null,
      "level": 4,
      "attribute": "Vaccine",
      "bst": 350,
      "hp": 60, "energy": 40, "attack": 55, "defence": 65,
      "special_attack": 50, "special_defence": 55, "speed": 40,
      "resistances": { "Null": 1.0, "Fire": 0.5 /* ...all 11 */ },
      "traits": [
        { "name": "Medium", "category": "Size" },
        { "name": "Terrestrial", "category": "Movement" },
        { "name": "Icy", "category": "Type" },
        { "name": "Ice", "category": "Element" }
      ],
      "techniques": [
        { "game_id": "ice_blast", "requirements": [{ "type": "innate" }] },
        { "game_id": "sub_zero_ice_punch", "requirements": [{ "type": "level", "level": 15 }] }
      ],
      "abilities": [
        { "game_id": "ice_body", "slot": 1 },
        { "game_id": "thick_fur", "slot": 2 },
        { "game_id": "frostbite", "slot": 3 }
      ]
    }
  ],

  "evolutions": [
    {
      "from_game_id": "gabumon",
      "to_game_id": "yukidarumon",
      "evolution_type": "Standard",
      "requirements": [{ "type": "level", "value": 11 }],
      "jogress_partners": ["wormmon"]
    }
  ],

  "locations": {
    "regions": [
      {
        "name": "Asuka Server",
        "description": null,
        "sectors": [
          {
            "name": "Central Park",
            "description": null,
            "zones": [
              {
                "name": "Entrance",
                "description": null,
                "digimon": [{ "game_id": "yukidarumon", "rarity": "common" }]
              }
            ]
          }
        ]
      }
    ]
  }
}
```

---

## Field Notes

### General

- **`version`**: Integer. Importer checks this matches its expected version.
- **`exported_at`**: ISO 8601 timestamp. Logged by importer, not validated.

### Lookups — Trait Categories

| Field | Type | Notes |
|---|---|---|
| `name` | `string` | Category name: `Size`, `Movement`, `Type`, `Element`. |
| `max_traits` | `int?` | Maximum traits per Digimon in this category. `null` = unlimited. |

### Traits

| Field | Type | Notes |
|---|---|---|
| `name` | `string` | Display name (PascalCase or multi-word). |
| `category` | `string` | Must match a `trait_categories` name. |

### Techniques

| Field | Type | Notes |
|---|---|---|
| `game_id` | `string` | Unique key. snake_case. |
| `jp_name` | `string` | Romanised Japanese (not kanji). |
| `dub_name` | `string` | English dub name. |
| `name` | `string?` | Optional game-specific override. `null` for most. |
| `description` | `string?` | Flavour text. `null` if not set. |
| `mechanic_description` | `string?` | Detailed mechanical text. `null` if not set. |
| `class` | `string` | `Physical`, `Special`, or `Status`. |
| `priority` | `int` | -4 to 4. Game maps via `DEX_PRIORITY_MAP`. |
| `targeting` | `string` | PascalCase enum: `Self`, `SingleTarget`, `SingleOther`, `SingleAlly`, `SingleFoe`, `AllAllies`, `AllOtherAllies`, `AllFoes`, `All`, `AllOther`, `SingleSide`, `Field`. |
| `energy_cost` | `int` | Energy to use. |
| `accuracy` | `int?` | 1-100. `null` = always hits (game maps to `0`). |
| `element` | `string?` | Element name (PascalCase). `null` = elementless. |
| `bricks` | `array` | Raw brick JSON. Validated game-side per `BRICK_CONTRACT.md`. |

### Abilities

| Field | Type | Notes |
|---|---|---|
| `game_id` | `string` | Unique key. snake_case. |
| `name` | `string` | Display name. |
| `description` | `string?` | Flavour text. |
| `mechanic_description` | `string?` | Detailed mechanical text. |
| `trigger` | `string` | camelCase: `onEntry`, `onExit`, `onTurnStart`, etc. |
| `stack_limit` | `string` | camelCase: `unlimited`, `oncePerTurn`, `oncePerSwitch`, `oncePerBattle`, `firstOnly`. |
| `trigger_condition` | `object?` | Optional condition details. `null` if none. |
| `bricks` | `array` | Raw brick JSON. |

### Items

| Field | Type | Notes |
|---|---|---|
| `game_id` | `string` | Unique key. snake_case. |
| `name` | `string` | Display name. |
| `description` | `string?` | Flavour text. `null` if not set. |
| `mechanic_description` | `string?` | Detailed mechanical text. `null` if not set. |
| `category` | `string` | `General`, `CaptureScan`, `Medicine`, `Performance`, `Gear`, `Key`, `Quest`, `Card`. |
| `is_consumable` | `bool` | Consumed on use. |
| `is_combat_usable` | `bool` | Can be used during battle. |
| `is_revive` | `bool` | Targets fainted party Digimon. |
| `buy_price` | `int` | Shop buy price (0 = not buyable). |
| `sell_price` | `int` | Shop sell price (0 = not sellable). |
| `has_icon` | `bool` | Whether an icon image exists for this item. |
| `gear_slot` | `string?` | `Equipable` or `Consumable`. `null` for non-gear. |
| `trigger` | `string?` | camelCase trigger from AbilityTrigger. `null` for non-gear. |
| `stack_limit` | `string?` | camelCase stack limit. `null` for non-gear. |
| `trigger_condition` | `string?` | Condition string. `null` if none. |
| `bricks` | `array` | Raw brick JSON. |

### Digimon

| Field | Type | Notes |
|---|---|---|
| `game_id` | `string` | Unique key. snake_case. |
| `jp_name` | `string` | Romanised Japanese. |
| `dub_name` | `string` | English dub name. |
| `name` | `string?` | Optional game-specific override. |
| `has_sprite` | `bool` | Whether a sprite image exists for this Digimon. |
| `level` | `int` | Evolution level (1-10). |
| `attribute` | `string` | PascalCase: `None`, `Vaccine`, `Virus`, `Data`, `Free`, `Variable`, `Unknown`. |
| `bst` | `int` | Base Stat Total. |
| `hp`..`speed` | `int` | 7 base stat values. |
| `resistances` | `object` | Element name (PascalCase) → float multiplier. All 11 elements present. |
| `traits` | `array` | Objects with `name` (string) and `category` (string). See Traits section. |
| `techniques` | `array` | Objects with `game_id` and `requirements`. |
| `abilities` | `array` | Objects with `game_id` and `slot` (1-3). |
| `growth_rate` | `string?` | XP growth rate: `Erratic`, `Fast`, `MediumFast`, `MediumSlow`, `Slow`, `Fluctuating`. Default: `MediumFast`. |
| `base_xp_yield` | `int?` | Base XP awarded when defeated. Default: `50`. |

#### Technique Requirements (OR logic — any met = learnable)

| Type | Fields | Meaning |
|---|---|---|
| `innate` | — | Signature technique, always known. |
| `level` | `level: int` | Learned at this level. |
| `tutor` | `text: string` | Learned from a tutor NPC. |
| `item` | `text: string` | Learned via a consumable item. |

#### Ability Slots

| Field | Type | Notes |
|---|---|---|
| `game_id` | `string` | Ability key. |
| `slot` | `int` | 1 = standard, 2 = alternate, 3 = hidden/secret. |

### Evolutions

| Field | Type | Notes |
|---|---|---|
| `from_game_id` | `string` | Source Digimon key. |
| `to_game_id` | `string` | Target Digimon key. |
| `evolution_type` | `string` | PascalCase: `Standard`, `Spirit`, `Armor`, `Slide`, `X-Antibody`, `Jogress`, `Mode Change`. |
| `requirements` | `array` | AND logic — all must be met. |
| `jogress_partners` | `array[string]` | Digimon keys. Empty if not Jogress. |

#### Evolution Requirements (AND logic — all must be met)

| Type | Fields | Meaning |
|---|---|---|
| `level` | `value: int` | Minimum level. |
| `stat` | `stat: string`, `value: int` | Specific stat threshold. |
| `stat_highest_of` | `stat: string`, `among: array[string]` | Stat must be highest. |
| `spirit` | `item: string` | Requires spirit item. |
| `digimental` | `item: string` | Requires digimental. |
| `x_antibody` | — | Requires X-Antibody item. |
| `description` | `text: string` | Freeform requirement. |

### Locations

Nested region → sector → zone hierarchy. May be `null` or have empty `regions` array if no location data exists.

| Level | Fields |
|---|---|
| Region | `name`, `description?`, `sectors[]` |
| Sector | `name`, `description?`, `zones[]` |
| Zone | `name`, `description?`, `digimon[]` |
| Zone Digimon | `game_id`, `rarity` (`common`, `uncommon`, `rare`, `very_rare`) |

---

## Validation Rules (Game-Side)

The game importer validates:

1. **`version`** must equal `3`
2. **Techniques**: bricks must pass `BRICK_CONTRACT.md` validation. Empty/invalid bricks → technique discarded.
3. **Abilities**: Same brick validation. Empty/invalid → discarded.
4. **Items**: Always imported. Gear items mapped to `GearData`; all others to `ItemData`. Saved to category subfolders.
5. **Digimon**: Always imported. Technique/ability key references may point to discarded entries (Atlas returns `null`).
6. **Evolutions**: Always imported.
7. **Locations**: Skipped if empty/null.
8. **Traits**: Each `digimon.traits` entry must have both `name` and `category`. Entries missing either field are skipped.

---

## Sprite Download

### `GET /sprites/:game_id`

Returns the PNG sprite image for the given `game_id`. Public endpoint (no auth required).

- **200**: PNG binary data
- **404**: No sprite exists for this Digimon

The importer uses the base URL (derived from the API URL by stripping `/export/game`) combined with this path to download sprites.

### `GET /item-icons/:game_id`

Returns the PNG icon image for the given item `game_id`. Public endpoint (no auth required).

- **200**: PNG binary data
- **404**: No icon exists for this item

The importer uses the base URL combined with this path to download item icons.

---

*Last Updated: 2026-02-09*

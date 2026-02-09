# Export Contract — Dex → Game Data Endpoint

> **Version**: 1
> **Purpose**: Defines the JSON shape the game-side importer expects from the dex export endpoint. The dex team implements `GET /export/game` to match this contract exactly.

---

## Endpoint

### `GET /export/game`

Bulk export of the entire game-relevant dataset. No pagination. Single JSON response.

---

## Response Shape

```jsonc
{
  "version": 1,
  "exported_at": "2026-02-08T12:00:00.000Z",

  "lookups": {
    "elements": [{ "name": "Null" }, { "name": "Fire" } /* ...all 11 */],
    "attributes": [{ "name": "None" }, { "name": "Vaccine" } /* ...all 7 */],
    "evolution_types": [{ "name": "Standard" } /* ...all 7 */]
  },

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

  "digimon": [
    {
      "game_id": "yukidarumon",
      "jp_name": "Yukidarumon",
      "dub_name": "Frigimon",
      "name": null,
      "type": "Icy",
      "level": 4,
      "attribute": "Vaccine",
      "bst": 350,
      "hp": 60, "energy": 40, "attack": 55, "defence": 65,
      "special_attack": 50, "special_defence": 55, "speed": 40,
      "resistances": { "Null": 1.0, "Fire": 0.5 /* ...all 11 */ },
      "techniques": [
        { "game_id": "ice_blast", "requirements": [{ "type": "innate" }] },
        { "game_id": "sub_zero_ice_punch", "requirements": [{ "type": "level", "value": 15 }] }
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

### Digimon

| Field | Type | Notes |
|---|---|---|
| `game_id` | `string` | Unique key. snake_case. |
| `jp_name` | `string` | Romanised Japanese. |
| `dub_name` | `string` | English dub name. |
| `name` | `string?` | Optional game-specific override. |
| `type` | `string?` | Descriptive tag (e.g. "Icy", "Dragon"). |
| `level` | `int` | Evolution level (1-10). |
| `attribute` | `string` | PascalCase: `None`, `Vaccine`, `Virus`, `Data`, `Free`, `Variable`, `Unknown`. |
| `bst` | `int` | Base Stat Total. |
| `hp`..`speed` | `int` | 7 base stat values. |
| `resistances` | `object` | Element name (PascalCase) → float multiplier. All 11 elements present. |
| `techniques` | `array` | Objects with `game_id` and `requirements`. |
| `abilities` | `array` | Objects with `game_id` and `slot` (1-3). |

#### Technique Requirements (OR logic — any met = learnable)

| Type | Fields | Meaning |
|---|---|---|
| `innate` | — | Signature technique, always known. |
| `level` | `value: int` | Learned at this level. |

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

1. **`version`** must equal `1`
2. **Techniques**: bricks must pass `BRICK_CONTRACT.md` validation. Empty/invalid bricks → technique discarded.
3. **Abilities**: Same brick validation. Empty/invalid → discarded.
4. **Digimon**: Always imported. Technique/ability key references may point to discarded entries (Atlas returns `null`).
5. **Evolutions**: Always imported.
6. **Locations**: Skipped if empty/null.

---

*Last Updated: 2026-02-08*

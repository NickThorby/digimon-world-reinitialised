# Item Schema Spec — Dex Team

> **Purpose**: Defines the Prisma model, enums, and API additions needed to support items in the dex export.

---

## Prisma Model

```prisma
model Item {
  id                   String   @id @default(cuid())
  game_id              String   @unique
  name                 String
  description          String?
  mechanic_description String?
  category             ItemCategory
  is_consumable        Boolean  @default(false)
  is_combat_usable     Boolean  @default(false)
  is_revive            Boolean  @default(false)
  buy_price            Int      @default(0)
  sell_price           Int      @default(0)
  has_icon             Boolean  @default(false)
  gear_slot            GearSlot?
  trigger              String?
  stack_limit          String?
  trigger_condition    String?
  bricks               Json     @default("[]")
  created_at           DateTime @default(now())
  updated_at           DateTime @updatedAt
}
```

---

## Enums

```prisma
enum ItemCategory {
  General
  CaptureScan
  Medicine
  Performance
  Gear
  Key
  Quest
  Card
}

enum GearSlot {
  Equipable
  Consumable
}
```

---

## Trigger Values (camelCase strings)

Reuse existing ability triggers from the `AbilityTrigger` enum:

| Value | Meaning |
|---|---|
| `continuous` | Always active (passive gear effects) |
| `onEntry` | When Digimon enters the field |
| `onTurnStart` | At the start of each turn |
| `onTurnEnd` | At the end of each turn |
| `onBeforeTechnique` | Before using a technique |
| `onAfterTechnique` | After using a technique |
| `onDealDamage` | After dealing damage |
| `onTakeDamage` | After taking damage |
| `onBeforeHit` | Before being hit |
| `onHpThreshold` | When HP crosses a threshold |
| `onStatusApplied` | When a status is applied to self |
| `onStatChange` | When stats change |

---

## Stack Limit Values (camelCase strings)

| Value | Meaning |
|---|---|
| `unlimited` | No limit |
| `oncePerTurn` | Once per turn |
| `oncePerSwitch` | Once per switch-in |
| `oncePerBattle` | Once per battle |
| `firstOnly` | Only the first activation matters |

---

## Export Shape (in `GET /export/game`)

Items are included as a top-level `"items"` array. See `EXPORT_CONTRACT.md` for the full field specification.

---

## API Endpoints

### `GET /export/game`

Updated to include `"items"` array in the response.

### `GET /item-icons/:game_id`

Returns the PNG icon for the given item `game_id`.

- **200**: PNG binary data
- **404**: No icon exists

---

## Example Items

### Medicine (Potion)
```json
{
  "game_id": "potion",
  "name": "Potion",
  "description": "Restores 50 HP to one Digimon.",
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
}
```

### Medicine (Revive)
```json
{
  "game_id": "revive",
  "name": "Revive",
  "description": "Revives a fainted Digimon with 50% HP.",
  "category": "Medicine",
  "is_consumable": true,
  "is_combat_usable": true,
  "is_revive": true,
  "buy_price": 1500,
  "sell_price": 750,
  "has_icon": true,
  "gear_slot": null,
  "trigger": null,
  "stack_limit": null,
  "trigger_condition": null,
  "bricks": [{"brick": "healing", "type": "percentage", "percent": 50}]
}
```

### Equipable Gear (Power Band)
```json
{
  "game_id": "power_band",
  "name": "Power Band",
  "description": "Boosts damage dealt by 20%.",
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
```

### Consumable Gear (Heal Berry)
```json
{
  "game_id": "heal_berry",
  "name": "Heal Berry",
  "description": "Restores 25% HP when below half health. Consumed after use.",
  "category": "Gear",
  "is_consumable": true,
  "is_combat_usable": false,
  "is_revive": false,
  "buy_price": 1000,
  "sell_price": 500,
  "has_icon": true,
  "gear_slot": "Consumable",
  "trigger": "onHpThreshold",
  "stack_limit": "oncePerBattle",
  "trigger_condition": "userHpBelow:50",
  "bricks": [{"brick": "healing", "type": "percentage", "percent": 25}]
}
```

### Capture/Scan Item
```json
{
  "game_id": "basic_scanner",
  "name": "Basic Scanner",
  "description": "Attempts to scan and capture a wild Digimon.",
  "category": "CaptureScan",
  "is_consumable": true,
  "is_combat_usable": true,
  "is_revive": false,
  "buy_price": 500,
  "sell_price": 250,
  "has_icon": true,
  "gear_slot": null,
  "trigger": null,
  "stack_limit": null,
  "trigger_condition": null,
  "bricks": []
}
```

---

*Last Updated: 2026-02-09*

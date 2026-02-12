# Brick Contract — Dex ↔ Game Shared Schema

> **Version**: 1.0
> **Purpose**: Defines the complete parameter schema for all 28 brick types, shared between the digimon-dex editor and the game engine. Both sides must conform to this contract.

---

## Conventions

- Brick dictionaries use **camelCase** keys to match dex JSON (no translation layer needed).
- The `brick` key is the **discriminator** — its value determines which schema applies.
- String references to statuses, weather, terrain, etc. use **dex-style names** (camelCase where multi-word).
- Stat references use **abbreviations**: `hp`, `atk`, `def`, `spa`, `spd`, `spe`, `energy`, `accuracy`, `evasion`.
- The importer converts dex camelCase identifiers to game snake_case where needed (e.g., `entryDamage` → `entry_damage`).
- Dex `paralyzed` → game `paralysed`, dex `vitalized` → game `vitalised` (British English).

---

## Enum Value Lists (Stored as both enums and database tables on the digimon-dex)

### Targeting (technique-level)

`self`, `singleTarget`, `singleOther`, `singleAlly`, `singleFoe`, `allAllies`, `allOtherAllies`, `allFoes`, `all`, `allOther`, `singleSide`, `field`

### BrickTarget (within-brick)

`self`, `target`, `allFoes`, `allAllies`, `all`, `attacker`, `field`

### TechniqueFlag

`contact`, `sound`, `punch`, `kick`, `bite`, `blade`, `beam`, `explosive`, `bullet`, `powder`, `wind`, `flying`, `groundable`, `defrost`, `reflectable`, `snatchable`

### StatusCondition

**Negative**: `asleep`, `burned`, `badlyBurned`, `frostbitten`, `frozen`, `exhausted`, `poisoned`, `badlyPoisoned`, `dazed`, `trapped`, `confused`, `blinded`, `paralyzed`, `bleeding`, `encored`, `taunted`, `disabled`, `perishing`, `seeded`

**Positive**: `regenerating`, `vitalized`

**Neutral**: `nullified`, `reversed`

*Note: Dex uses American spelling (`paralyzed`, `vitalized`). Importer maps to British (`paralysed`, `vitalised`).*

### BattleStat

`hp`, `atk`, `def`, `spa`, `spd`, `spe`, `energy`, `accuracy`, `evasion`

### BattleCounter

`timesHitThisBattle`, `alliesFaintedThisBattle`, `foesFaintedThisBattle`, `userStatStagesTotal`, `targetStatStagesTotal`, `turnsOnField`, `consecutiveUses`

### SemiInvulnerableState

`sky`, `underground`, `underwater`, `shadow`, `intangible`

### Weather (More to be added)

`sun`, `rain`, `sandstorm`, `hail`, `snow`, `fog`

### Terrain (More to be added)

`flooded`, `blooming`

### Hazard

`entryDamage`, `entryStatReduction`, `entryStatusEffect`

### GlobalEffect

`groundingField`, `speedInversion`, `gearSuppression`, `defenceSwap`

### SideEffect

`physicalBarrier`, `specialBarrier`, `dualBarrier`, `statDropImmunity`, `statusImmunity`, `speedBoost`, `critImmunity`, `spreadProtection`, `priorityProtection`, `firstTurnProtection`

### ShieldType

`hpDecoy`, `intactFormGuard`, `endure`, `lastStand`, `negateOneMoveClass`

---

## Brick Schemas (28)

### 1. `damage`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"damage"` | Yes | Discriminator |
| `type` | `String` | Yes | `standard`, `fixed`, `percentage`, `scaling`, `level`, `returnDamage`, `counterScaling` |
| `power` | `int` | No | Base power (standard) |
| `amount` | `int` | No | Fixed damage (fixed) |
| `percent` | `float` | No | % of HP (percentage) |
| `source` | `String` | No | `userMaxHp`, `userCurrentHp`, `targetMaxHp`, `targetCurrentHp` |
| `stat` | `String` | No | Stat abbreviation for scaling |
| `basePower` | `int` | No | Base power for counterScaling |
| `damageSource` | `String` | No | `lastPhysicalHit`, `lastSpecialHit`, `lastHit` (returnDamage) |
| `returnMultiplier` | `float` | No | Multiplier for returned damage |
| `scalesWithCounter` | `String` | No | BattleCounter name |
| `scalingPerCount` | `float` | No | Power added per count |
| `scalingCap` | `int` | No | Max bonus from scaling |
| `elements` | `Array[String]` | No | Multi-element damage |

### 2. `damageModifier`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"damageModifier"` | Yes | Discriminator |
| `condition` | `String` | No | When to apply |
| `multiplier` | `float` | No | Damage multiplier. *Note: `damageModifier` bricks are meta-consumed during damage calculation — they modify the damage result of a sibling `damage` brick rather than executing standalone.* |
| `flatBonus` | `int` | No | Flat damage added |
| `ignoreDefense` | `bool` | No | Ignore target defence |
| `ignoreEvasion` | `bool` | No | Ignore evasion stages |
| `ignoreAbility` | `bool` | No | Ignore target ability |
| `bypassProtection` | `bool` | No | Bypass protection |
| `ignoreTypeImmunity` | `bool` | No | Ignore 0x resistance |
| `ignoreBarriers` | `bool` | No | Ignore damage barriers |
| `ignoreStatBoosts` | `bool` | No | Ignore target's positive stages |

### 3. `recoil`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"recoil"` | Yes | Discriminator |
| `type` | `String` | Yes | `damagePercent`, `hpPercent`, `fixed`, `crash` |
| `percent` | `float` | No | % of damage dealt or max HP |
| `amount` | `int` | No | Fixed amount |

### 4. `statModifier`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"statModifier"` | Yes | Discriminator |
| `stats` | `String` or `Array` | Yes | Stat abbreviation(s) |
| `modifierType` | `String` | No | `stage` (default), `percent`, `fixed` |
| `stages` | `int` | No | Stage change -6 to +6 |
| `percent` | `float` | No | Percentage modifier |
| `value` | `int` | No | Fixed value |
| `target` | `String` | No | BrickTarget (default `self`) |
| `chance` | `int` | No | Probability 1-100 (default 100) |
| `scalesWithCounter` | `String` | No | BattleCounter name |
| `scalingPerCount` | `float` | No | Stages per count |
| `scalingCap` | `int` | No | Max bonus stages |
| `condition` | `String` | No | Condition for applying |
| `setToMax` | `bool` | No | Set to +6 |
| `swapWithTarget` | `bool` | No | Swap all stages with target |

### 5. `statProtection`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"statProtection"` | Yes | Discriminator |
| `stats` | `String`/`Array`/`"all"` | Yes | Stats to protect |
| `target` | `String` | No | BrickTarget (default `self`) |
| `preventLowering` | `bool` | No | Prevent drops |
| `preventRaising` | `bool` | No | Prevent raises |
| `duration` | `int` | No | Turns (null = while on field) |

### 6. `statusEffect`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"statusEffect"` | Yes | Discriminator |
| `status` | `String` | Yes | Status name (dex name) |
| `target` | `String` | Yes | BrickTarget |
| `chance` | `int` | No | Probability 1-100 (default 100) |
| `duration` | `int` | No | Duration in turns |
| `remove` | `bool` | No | Remove instead of inflict |
| `removeAll` | `bool` | No | Remove all statuses |
| `canUpgrade` | `bool` | No | If false, prevents status upgrade (e.g. poisoned to badly_poisoned). Default true |

### 7. `statusInteraction`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"statusInteraction"` | Yes | Discriminator |
| `ifUserHas` | `String` | No | Check user status |
| `ifTargetHas` | `String` | No | Check target status |
| `cure` | `bool` | No | Cure the checked status |
| `transfer` | `bool` | No | Transfer status to opponent |
| `bonusDamage` | `float` | No | Bonus damage multiplier |
| `bonusEffect` | `String` | No | Additional effect |

### 8. `healing`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"healing"` | Yes | Discriminator |
| `type` | `String` | Yes | `percentage`, `fixed`, `drain`, `weather`, `status`, `energyFixed`, `energyPercentage` |
| `percent` | `float` | No | % of max HP |
| `amount` | `int` | No | Fixed HP |
| `target` | `String` | No | BrickTarget (default `self`) |
| `weather` | `String` | No | Weather modifying heal |
| `terrain` | `String` | No | Terrain modifying heal |
| `cureStatus` | `String`/`Array` | No | Status(es) to cure |

### 9. `fieldEffect`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"fieldEffect"` | Yes | Discriminator |
| `type` | `String` | Yes | `weather`, `terrain`, `global` |
| `weather` | `String` | No | Weather name |
| `terrain` | `String` | No | Terrain name |
| `global` | `String` | No | Global effect name |
| `duration` | `int` | No | Duration (default from GameBalance) |
| `remove` | `bool` | No | Remove instead of set |

### 10. `sideEffect`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"sideEffect"` | Yes | Discriminator |
| `effect` | `String` | Yes | Side effect name |
| `side` | `String` | Yes | `user`, `target`, `allFoes`, `both` |
| `duration` | `int` | No | Duration (default from GameBalance) |
| `remove` | `bool` | No | Remove instead of set |

`user` = user's side. `target` = the targeted Digimon's side (resolved at runtime). `allFoes` = all foe sides. `both` = user's side + all foe sides.

### 11. `hazard`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"hazard"` | Yes | Discriminator |
| `hazardType` | `String` | Yes | `entryDamage`, `entryStatReduction`, `entryStatusEffect` |
| `side` | `String` | No | `target` (default), `user`, `allFoes`, `both` |
| `maxLayers` | `int` | No | Maximum stackable layers (default 1, max 5) |
| `damagePercent` | `float` | No | HP% damage per layer on switch-in (entryDamage) |
| `element` | `String` | No | Element key — if set, damage scales with target's resistance (entryDamage) |
| `stat` | `String` | No | Stat abbreviation to reduce on switch-in (entryStatReduction) |
| `stages` | `int` | No | Stat stages to drop on switch-in (entryStatReduction, default -1) |
| `status` | `String` | No | Status to inflict on switch-in (entryStatusEffect). At 2+ layers, upgrades stackable statuses (e.g. poisoned → badly_poisoned) |
| `hazardName` | `String` | No | Display name for the hazard in battle messages and UI. Falls back to technique source_name, then key |
| `remove` | `bool` | No | Remove this hazard type |
| `removeAll` | `bool` | No | Remove all hazards |
| `aerialIsImmune` | `bool` | No | If true, Digimon with aerial movement trait are immune to this hazard on switch-in (default false) |

### 12. `positionControl`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"positionControl"` | Yes | Discriminator |
| `type` | `String` | Yes | `forceSwitch`, `switchOut`, `switchOutPassStats`, `swapPositions` |
| `target` | `String` | No | BrickTarget (default `target`) |
| `bypassProtection` | `bool` | No | Bypass protection (phaze techniques) |

### 13. `turnEconomy`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"turnEconomy"` | Yes | Discriminator |
| `recharge` | `bool` | No | Must recharge next turn |
| `semiInvulnerable` | `String` | No | `sky`, `underground`, `underwater`, `shadow`, `intangible` |
| `multiTurn` | `Dictionary` | No | `{minHits, maxHits, lockedIn?}` |
| `multiHit` | `Dictionary` | No | `{minHits, maxHits, fixedHits?}` |
| `delayedAttack` | `Dictionary` | No | `{delay, targetsSlot?, bypassProtection?}` |
| `delayedHealing` | `Dictionary` | No | `{delay, percent, target?}` |

### 14. `chargeRequirement`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"chargeRequirement"` | Yes | Discriminator |
| `turnsToCharge` | `int` | Yes | Charge turns needed |
| `semiInvulnerable` | `String` | No | State during charge |
| `skipInWeather` | `String` | No | Weather that skips charge |
| `skipInTerrain` | `String` | No | Terrain that skips charge |

### 15. `synergy`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"synergy"` | Yes | Discriminator |
| `synergyType` | `String` | Yes | `combo` or `followUp` |
| `partnerTechniques` | `Array[String]` | No | Technique keys that trigger synergy |
| `bonusPower` | `int` | No | Additional power |
| `bonusEffect` | `String` | No | Description of bonus |

### 16. `requirement`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"requirement"` | Yes | Discriminator |
| `failCondition` | `String` | Yes | Condition string |
| `failMessage` | `String` | No | Translation key |
| `checkTiming` | `String` | No | `beforeExecution` (default), `afterSelection` |

### 17. `conditional`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"conditional"` | Yes | Discriminator |
| `condition` | `String` | Yes | Condition string |
| `bonusPower` | `int` | No | Additional power |
| `bonusAccuracy` | `int` | No | Additional accuracy |
| `bonusCrit` | `int` | No | Crit stage bonus |
| `alwaysHits` | `bool` | No | Bypass accuracy check |
| `alwaysCrit` | `bool` | No | Guaranteed crit |
| `damageMultiplier` | `float` | No | Damage multiplier |
| `applyBricks` | `Array[Dictionary]` | No | Nested bricks when condition met |

### 18. `protection`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"protection"` | Yes | Discriminator |
| `type` | `String` | Yes | `all`, `wide`, `priority` |
| `failChance` | `float` | No | Base fail chance (escalates) |
| `damageReduction` | `float` | No | Partial reduction (not full block) |
| `counterDamage` | `float` | No | Damage to attacker on contact |
| `reflectStatus` | `bool` | No | Reflect status techniques back |

### 19. `priorityOverride`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"priorityOverride"` | Yes | Discriminator |
| `condition` | `String` | Yes | Condition string |
| `newPriority` | `int` | Yes | New priority (-4 to 4, mapped via DEX_PRIORITY_MAP) |

### 20. `elementModifier`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"elementModifier"` | Yes | Discriminator |
| `type` | `String` | Yes | Modifier subtype (see values below) |
| `element` | `String` | Conditional | Element name. Required for all types except `matchTargetWeakness`. |
| `target` | `String` | Conditional | BrickTarget. Required for trait and resistance operations on a target. |
| `value` | `float` | Conditional | Resistance multiplier. Required for `changeUserResistanceProfile` and `changeTargetResistanceProfile`. |

**`type` values**:

| Value | Description | Requires |
|---|---|---|
| `addElement` | Add element trait to target temporarily | `element`, `target` |
| `removeElement` | Remove element trait from target temporarily | `element`, `target` |
| `replaceElements` | Replace all element traits with one | `element`, `target` |
| `changeTechniqueElement` | Change the technique's element for this use | `element` |
| `matchTargetWeakness` | Set technique element to one the target is weak to | — |
| `changeUserResistanceProfile` | Set user's resistance to `element` to `value` | `element`, `value` |
| `changeTargetResistanceProfile` | Set target's resistance to `element` to `value` | `element`, `value` |

**`value`** must be one of: `0.0` (immune), `0.5` (resistant), `1.0` (neutral), `1.5` (weak), `2.0` (very weak).

*Element traits determine STAB and can be temporarily modified during battle. Resistance profile changes modify the multiplier for a specific element. All modifications last until switch-out or battle end unless otherwise specified. The `target` field uses BrickTarget values.*

### 21. `criticalHit`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"criticalHit"` | Yes | Discriminator |
| `stage` | `int` | No | Additional crit stages (0-4) |
| `alwaysCrit` | `bool` | No | Guaranteed crit |
| `neverCrit` | `bool` | No | Cannot crit |

### 22. `resource`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"resource"` | Yes | Discriminator |
| `consumeItem` | `bool` | No | Consume target's gear |
| `stealItem` | `bool` | No | Steal target's gear |
| `swapItems` | `bool` | No | Swap gear with target |
| `removeItem` | `bool` | No | Destroy target's gear |
| `giveItem` | `String` | No | Give specific item key |

### 23. `useRandomTechnique`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"useRandomTechnique"` | Yes | Discriminator |
| `source` | `String` | Yes | `allTechniques`, `userKnown`, `userKnownExceptThis`, `targetKnown` |
| `excludeTechniques` | `Array[String]` | No | Technique keys to exclude |
| `onlyDamaging` | `bool` | No | Only damaging techniques |
| `onlyStatus` | `bool` | No | Only status techniques |
| `limitToFlags` | `Array[String]` | No | Only techniques with at least one of these flags (e.g. `["contact", "sound"]`) |

### 24. `transform`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"transform"` | Yes | Discriminator |
| `copyStats` | `Array[String]` or `bool` | No | Stat abbreviations to copy (e.g. `["atk", "spa"]`). Uses BRICK_STAT_MAP keys: `hp`, `atk`, `def`, `spa`, `spd`, `spe`, `energy`. Also accepts `true` (bool) to copy all base stats. |
| `copyTechniques` | `bool` | No | Copy known techniques |
| `copyAbility` | `bool` | No | Copy ability |
| `copyResistances` | `bool` | No | Copy resistance profile |
| `copyElementTraits` | `bool` | No | Copy element traits (affects STAB) |
| `copyAppearance` | `bool` | No | Copy sprite/visual |
| `duration` | `int` | No | Null = until switch/battle end |

### 25. `shield`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"shield"` | Yes | Discriminator |
| `type` | `String` | Yes | `hpDecoy`, `intactFormGuard`, `endure`, `lastStand`, `negateOneMoveClass` |
| `hpCost` | `float` | No | HP cost as % of max |
| `hpThreshold` | `float` | No | HP threshold — optional for `intactFormGuard` (omit = always triggers like Disguise), required for `lastStand` |
| `moveClass` | `String` | No | `physical` or `special` — required for `negateOneMoveClass` |
| `breakOnHit` | `bool` | No | Breaks after one hit |
| `oncePerBattle` | `bool` | No | Only activates once |
| `blocksStatus` | `bool` | No | While this shield exists, status effects targeting this Digimon are blocked |

### 26. `copyTechnique`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"copyTechnique"` | Yes | Discriminator |
| `source` | `String` | Yes | `lastUsedByTarget`, `lastUsedByAny`, `lastUsedOnUser`, `randomFromTarget` |
| `permanent` | `bool` | No | Permanently learn |
| `replaceSlot` | `int` | No | Replace technique slot (0-3) |
| `duration` | `int` | No | Copy duration |

### 27. `abilityManipulation`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"abilityManipulation"` | Yes | Discriminator |
| `type` | `String` | Yes | `copy`, `swap`, `suppress`, `replace`, `give`, `nullify` |
| `target` | `String` | No | BrickTarget (default `target`) |
| `abilityName` | `String` | No | Ability key (for `replace`) |
| `duration` | `int` | No | Null = until switch/battle end |

### 28. `turnOrder`

| Key | Type | Required | Description |
|---|---|---|---|
| `brick` | `"turnOrder"` | Yes | Discriminator |
| `type` | `String` | Yes | `makeTargetMoveNext`, `makeTargetMoveLast`, `repeatTargetMove` |
| `target` | `String` | No | BrickTarget (default `target`) |

---

## Condition Strings

Several bricks use `condition` or `failCondition` strings. These are evaluated by `BrickConditionEvaluator` at runtime. The format is:

```
condType:value
```

Multiple conditions can be combined with `|` (AND logic — all must pass):

```
damageTypeIs:fire|userHpBelow:50
```

### Common Conditions

| Condition | Meaning |
|---|---|
| `userHpBelow:50` | User HP below 50% |
| `userHpAbove:50` | User HP above 50% |
| `targetHpBelow:50` | Target HP below 50% |
| `targetAtFullHp` | Target is at full HP |
| `userHasStatus:burned` | User has Burned status |
| `targetHasStatus:asleep` | Target is asleep |
| `targetNoStatus:burned` | Target does not have Burned |
| `damageTypeIs:fire` | Technique element is Fire |
| `techniqueIsType:fire` | Same as `damageTypeIs` |
| `weatherIs:sun` | Sun weather is active |
| `terrainIs:flooded` | Flooded terrain is active |
| `isFirstTurn` | User's first turn on field |
| `targetNotActed` | Target hasn't acted this turn |
| `targetActed` | Target has acted this turn |
| `userStatHigher:atk` | User's ATK > target's ATK |
| `targetStatHigher:spe` | Target's SPE > user's SPE |
| `userEpBelow:50` | User energy below 50% |
| `usingTechniqueOfClass:physical` | Technique is physical class |
| `turnIsLessThan:5` | Battle turn < 5 |
| `turnIsMoreThan:5` | Battle turn > 5 |
| `userHasAbility:blaze` | User has named ability |
| `targetHasAbility:blaze` | Target has named ability |
| `isSuperEffective` | Technique is super effective |
| `isNotVeryEffective` | Technique is not very effective |
| `lastTechniqueWas:tackle` | User's last technique was named |
| `userHasItem:power_band` | User has named gear equipped |
| `userHasNoItem:power_band` | User does not have named gear |
| `moveHasFlag:contact` | Technique has the named TechniqueFlag |
| `userHasTrait:element:fire` | User Digimon has named trait in category (element, movement, size, type) |
| `targetHasTrait:element:fire` | Target Digimon has named trait in category |
| `allyHasTrait:element:fire` | Any active ally (same side, not self) has named trait in category |

---

## Dex → Game Spelling Map

The importer handles these conversions automatically:

| Dex (American) | Game (British) |
|---|---|
| `paralyzed` | `paralysed` |
| `vitalized` | `vitalised` |

## Dex → Game Identifier Map

The importer converts camelCase identifiers to snake_case:

| Dex | Game |
|---|---|
| `entryDamage` | `entry_damage` |
| `entryStatReduction` | `entry_stat_reduction` |
| `entryStatusEffect` | `entry_status_effect` |
| `groundingField` | `grounding_field` |
| `speedInversion` | `speed_inversion` |
| `gearSuppression` | `gear_suppression` |
| `defenceSwap` | `defence_swap` |
| `physicalBarrier` | `physical_barrier` |
| `specialBarrier` | `special_barrier` |
| `dualBarrier` | `dual_barrier` |
| `statDropImmunity` | `stat_drop_immunity` |
| `statusImmunity` | `status_immunity` |
| `speedBoost` | `speed_boost` |
| `critImmunity` | `crit_immunity` |
| `spreadProtection` | `spread_protection` |
| `priorityProtection` | `priority_protection` |
| `firstTurnProtection` | `first_turn_protection` |
| `hpDecoy` | `hp_decoy` |
| `intactFormGuard` | `intact_form_guard` |
| `lastStand` | `last_stand` |
| `negateOneMoveClass` | `negate_one_move_class` |

---

*Last Updated: 2026-02-12*

# Digimon World: Reinitialised — Technical Context

> **Quick Start for AI Sessions**: Read `README.md` for project structure and style guide, this file for technical architecture, and `CONCEPT.md` for game design vision.

---

## 1. Project Overview

A 2D top-down Digimon RPG built in **Godot 4.6** using GDScript. The project is heavily data-driven, sourcing its content from a sister project ([digimon-dex](../digimon-dex)) that contains the authoritative database of Digimon, techniques, abilities, and evolutions.

**Key architectural decisions**:
- Resource vs State pattern for clean separation of templates and runtime data
- Key-based references between resources (StringName keys, not resource paths)
- Autoload singletons for global state and data access
- Modular "brick" system for composing technique, ability, and gear effects
- Source-data-only serialisation for save files

---

## 2. Core Architecture

### Resource vs State Pattern

- **Resources** (`data/` folder): Immutable templates loaded from `.tres` files. Define what things *can be* (DigimonData, TechniqueData, AbilityData).
- **States** (`scripts/systems/` folder): Mutable runtime objects representing actual game instances. Hold what things *are* (a specific Digimon, its current HP, equipped techniques).

### Key-Based References

Resources reference each other via `StringName` keys, not Godot resource paths. This prevents circular dependencies and makes the ingestion pipeline simpler.

```gdscript
# Good — key-based reference
@export var ability_slot_1_key: StringName = &"flame_aura"

# Bad — direct resource reference
@export var ability: AbilityData
```

At runtime, look up resources via Atlas: `Atlas.abilities[ability_slot_1_key]`.

### Autoload Singletons

| Autoload      | Purpose                                  |
|---------------|------------------------------------------|
| Settings      | Display preferences (persists to cfg)    |
| Registry      | Central enum registry + game constants   |
| Atlas         | Data resource loader (all .tres files)   |
| Game          | Game lifecycle (new/load/save/quit)      |
| SceneManager  | Scene transitions with fade effects      |

---

## 3. Digimon System

### DigimonData Resource Schema

Mapped from digimon-dex `Digimon` table:

| Field                     | Type                     | Description                        |
|---------------------------|--------------------------|------------------------------------|
| `key`                     | `StringName`             | Unique identifier (game_id)        |
| `jp_name`                 | `String`                 | Japanese name                      |
| `dub_name`                | `String`                 | English dub name                   |
| `custom_name`             | `String`                 | Optional custom override           |
| `size_trait`              | `StringName`             | Size trait key (max 1)             |
| `movement_traits`         | `Array[StringName]`      | Movement trait keys (unlimited)    |
| `type_trait`              | `StringName`             | Type trait key (max 1)             |
| `element_traits`          | `Array[StringName]`      | Element trait keys (for STAB)      |
| `level`                   | `int`                    | Evolution level (1-10)             |
| `attribute`               | `Registry.Attribute`     | Vaccine, Virus, Data, etc.         |
| `base_hp` through `base_speed` | `int`              | 7 base stat values                 |
| `bst`                     | `int`                    | Base Stat Total                    |
| `resistances`             | `Dictionary`             | Element key -> float multiplier    |
| `technique_entries`       | `Array[Dictionary]`      | Techniques with learn requirements |
| `ability_slot_1_key`      | `StringName`             | Standard ability slot 1            |
| `ability_slot_2_key`      | `StringName`             | Standard ability slot 2            |
| `ability_slot_3_key`      | `StringName`             | Hidden/secret ability              |
| `growth_rate`             | `Registry.GrowthRate`    | XP growth rate curve               |
| `base_xp_yield`           | `int`                    | Base XP when defeated              |

Each `technique_entries` element: `{ "key": StringName, "requirements": Array[Dictionary] }`. Requirement types (OR logic — any met = learnable): `innate` (no fields), `level` (`level: int`), `tutor` (`text: String`), `item` (`text: String`). Helpers: `get_innate_technique_keys()`, `get_technique_keys_at_level(level)`, `get_all_technique_keys()`.

### DigimonState Runtime

| Field                    | Type                | Description                         |
|--------------------------|---------------------|-------------------------------------|
| `key`                    | `StringName`        | Which DigimonData template          |
| `nickname`               | `String`            | Player-given name                   |
| `level`                  | `int`               | Current level                       |
| `experience`             | `int`               | Current XP                          |
| `personality_key`        | `StringName`        | Original personality reference      |
| `personality_override_key` | `StringName`      | Override personality (items); use `get_effective_personality_key()` for lookup |
| `ivs`                    | `Dictionary`        | Stat key -> 0-50 (permanent)        |
| `tvs`                    | `Dictionary`        | Stat key -> 0-500 (earned)          |
| `current_hp`             | `int`               | Current hit points                  |
| `current_energy`         | `int`               | Current energy                      |
| `known_technique_keys`   | `Array[StringName]` | All known techniques                |
| `equipped_technique_keys`| `Array[StringName]` | Active techniques (max 4)           |
| `active_ability_slot`    | `int`               | Which slot is active (1, 2, or 3)   |
| `equipped_gear_key`      | `StringName`        | Equipable gear                      |
| `equipped_consumable_key`| `StringName`        | Consumable gear                     |
| `training_points`        | `int`               | Training points for stat training  |
| `scan_data`              | `float`             | Scan progress (0.0-1.0)            |

### Stat Formula

```
FLOOR((((2 * BASE + IV + (TV / 5)) * LEVEL) / 100)) + LEVEL + 10
```

Where:
- `BASE` = from DigimonData template
- `IV` = Individual Value (0-50, random at creation, permanent)
- `TV` = Training Value (0-500, earned through training)
- `LEVEL` = current Digimon level

### Personality Modifiers

Each personality boosts one stat by +10% and reduces another by -10%. When both target the same stat, the effect cancels out (neutral personality).

### Display Name Resolution

Name resolution is controlled by two settings in the `Settings` autoload:

- **Display Preference** (`JAPANESE` or `DUB`, default: `DUB`) — selects the base name tradition
- **Use Game Names** (`true` or `false`, default: `true`) — enables game-specific custom overrides

Resolution logic (applies to `DigimonData.display_name` and `TechniqueData.display_name`):

1. If `use_game_names` is ON and `custom_name != ""` → return `custom_name`
2. If preference is `JAPANESE` → return `jp_name`
3. If preference is `DUB` → return `dub_name` (fallback to `jp_name` if empty)

Evolution level labels follow `display_preference` only (no game name override). Use `Registry.get_evolution_level_label(level)` or `Registry.evolution_level_labels[level]`.

---

## 4. Attribute Triangle

```
Vaccine > Virus > Data > Vaccine
```

| Attacker vs Defender | Multiplier |
|----------------------|------------|
| Advantage            | 1.5x      |
| Disadvantage         | 0.5x      |
| Neutral              | 1.0x      |
| Free/Variable/None   | 1.0x      |

The attribute triangle affects damage calculation. Free, Variable, None, and Unknown attributes are neutral against everything.

---

## 5. Element System

**11 elements**: Null, Fire, Water, Air, Earth, Ice, Lightning, Plant, Metal, Dark, Light

### Resistance Tiers

| Multiplier | Tier       |
|------------|------------|
| 0.0        | Immune     |
| 0.5        | Resistant  |
| 1.0        | Neutral    |
| 1.5        | Weak       |
| 2.0        | Very Weak  |

Each Digimon has individual resistance values per element (stored in `DigimonData.resistances`).

### Trait System

Digimon have traits across 4 categories, stored as separate fields on DigimonData:

| Category | Field | Cardinality | Values |
|---|---|---|---|
| Size | `size_trait` | Max 1 (`StringName`) | `tiny`, `small`, `medium`, `large`, `huge`, `gargantuan` |
| Movement | `movement_traits` | Unlimited (`Array[StringName]`) | `aerial`, `aquatic`, `terrestrial` |
| Type | `type_trait` | Max 1 (`StringName`) | `dragon`, `beast`, `humanoid`, etc. (38 values) |
| Element | `element_traits` | Unlimited (`Array[StringName]`) | `null`, `fire`, `water`, `air`, `earth`, `ice`, `lightning`, `plant`, `metal`, `dark`, `light` |

Trait keys are lowercase snake_case StringNames (e.g., `&"dragon"`, `&"fire"`, `&"royal_knight"`).

### STAB (Same-Type Attack Bonus)

When a Digimon's `element_traits` includes the technique's `element_key`, damage is multiplied by `element_stab_multiplier` (default 1.5, configurable in GameBalance). Element trait keys match element keys directly (both lowercase StringNames).

---

## 6. Evolution System

### Evolution Levels (10)

Labels depend on `Settings.display_preference` (Japanese vs Dub):

| Value | Japanese        | Dub             |
|-------|-----------------|-----------------|
| 1     | Baby I          | Fresh           |
| 2     | Baby II         | In-Training     |
| 3     | Child           | Rookie          |
| 4     | Adult           | Champion        |
| 5     | Perfect         | Ultimate        |
| 6     | Ultimate        | Mega            |
| 7     | Super Ultimate  | Ultra           |
| 8     | Armor           | Armor           |
| 9     | Hybrid          | Hybrid          |
| 10    | Unknown         | Unknown         |

### Evolution Types (7)

Standard, Spirit, Armor, Slide, X-Antibody, Jogress, Mode Change

### EvolutionLinkData

| Field                  | Type                    | Description                        |
|------------------------|-------------------------|------------------------------------|
| `key`                  | `StringName`            | Unique link identifier             |
| `from_key`             | `StringName`            | Source Digimon key                  |
| `to_key`               | `StringName`            | Target Digimon key                 |
| `evolution_type`       | `Registry.EvolutionType`| Type of evolution                  |
| `requirements`         | `Array[Dictionary]`     | AND logic — all must be met        |
| `jogress_partner_keys` | `Array[StringName]`     | Required partners for Jogress      |

### Requirement Types

Requirements are dictionaries with a `type` field:
- `level` — minimum level threshold
- `stat` — specific stat must reach a value
- `stat_highest_of` — a stat must be the highest among specified stats
- `spirit` — requires a specific spirit item
- `digimental` — requires a specific digimental
- `x_antibody` — requires X-Antibody item
- `description` — freeform text requirement (for manual/story gates)

Requirements are checked at runtime by `EvolutionChecker` (see Utility Classes section).

---

## 7. Battle System

### Turn Order

1. Group actions by priority tier (Maximum first, Minimum last)
2. Within the same tier, calculate effective speed: `base_speed * priority_multiplier`
3. Higher effective speed goes first
4. Ties broken randomly

### Priority Tiers and Speed Multipliers

| Tier      | Behaviour                                |
|-----------|------------------------------------------|
| Maximum   | Always first (ordered by speed among ties) |
| Instant   | Always first (after Maximum)             |
| Very High | Speed * 2.0x                             |
| High      | Speed * 1.5x                             |
| Normal    | Speed * 1.0x                             |
| Low       | Speed * 0.5x                             |
| Very Low  | Speed * 0.25x                            |
| Negative  | Always last (before Minimum)             |
| Minimum   | Always last                              |

### Damage Formula (TemTem-inspired)

```
damage = ROUND((7 + level / 200) * power * (ATK / DEF) * modifier)
modifier = attribute_mult * element_mult * stab * crit * variance
```

Where:
- `level` = user's level
- `power` = technique base power
- `ATK / DEF` = ATK/DEF for Physical, SPATK/SPDEF for Special (with stat stages and personality applied)
- `attribute_mult` = from attribute triangle (0.5, 1.0, or 1.5)
- `element_mult` = target's resistance to technique's element (0.0-2.0)
- `stab` = 1.5 if technique element is in user's `element_traits`, else 1.0 (configurable via `GameBalance.element_stab_multiplier`)
- `crit` = 1.5 if critical hit, else 1.0
- `variance` = random factor between 0.85 and 1.0

### Physical vs Special vs Status

| Class    | Damage Stats      | Description                  |
|----------|-------------------|------------------------------|
| Physical | ATK vs DEF        | Contact-based attacks        |
| Special  | SPATK vs SPDEF    | Ranged/energy attacks        |
| Status   | No damage calc    | Effect-only techniques       |

### Stat Stages

Stats can be modified from -6 to +6 during battle:

| Stage | Multiplier | Stage | Multiplier |
|-------|------------|-------|------------|
| -6    | 0.25       | +1    | 1.50       |
| -5    | 0.29       | +2    | 2.00       |
| -4    | 0.33       | +3    | 2.50       |
| -3    | 0.40       | +4    | 3.00       |
| -2    | 0.50       | +5    | 3.50       |
| -1    | 0.67       | +6    | 4.00       |
| 0     | 1.00       |       |            |

Affects: ATK, DEF, SPATK, SPDEF, SPD.

### Energy System

- Each technique has an `energy_cost`
- **Overexertion**: Using a technique without enough energy deals recoil damage (multiplier configurable in GameBalance)
- **Regeneration per turn**: 5% of max energy
- **Regeneration on rest**: 25% of max energy (by choosing to rest/skip turn)
- **After battle**: 100% energy restored

### Charge System

Some techniques require charges before use:

- `charge_required`: Number of charges needed (0 = instant use)
- `charge_conditions`: Array of conditions for gaining charges
  - `turns` — gain a charge each turn
  - `damaged` — gain a charge when hit
  - `hit_by_type` — gain a charge when hit by a specific element
- Charges **persist through switches** (Digimon switching out retains charges)
- Charges **reset on use** (after firing the charged technique)
- Charges **reset when battle ends**

### Battle VFX System

Element-aware particle effects for technique animations, driven by `BattleVFX` (`scenes/battle/battle_vfx.gd`).

**Element Colours** — `Registry.ELEMENT_COLOURS` maps element StringName keys to `Color` values (e.g. `&"fire"` -> orange-red, `&"water"` -> blue).

**Animation behaviour by technique class:**

| Class    | User Effect            | VFX                                          |
|----------|------------------------|----------------------------------------------|
| Physical | Lunge (Y offset)       | Element burst particles at user sprite        |
| Special  | Element-tinted flash   | Projectile particles from user to target      |
| Status   | Subtle element tint    | Gentle particles drifting from user to target |

When `element_key` is `&""`, VFX is skipped and only the tween plays (backward-compatible fallback).

**Future override** — `TechniqueData.animation_key` (currently unused) will allow per-technique animation overrides. When set, `play_attack_animation()` will check it before falling through to the default element+class animation.

---

## 8. Technique & Brick System

### TechniqueData Resource

Mapped from digimon-dex `Attack` table (**"attack" in dex = "technique" in game**):

| Field                  | Type                      | Description                      |
|------------------------|---------------------------|----------------------------------|
| `key`                  | `StringName`              | Unique identifier (game_id)     |
| `jp_name`              | `String`                  | Japanese name                    |
| `dub_name`             | `String`                  | English dub name                 |
| `custom_name`          | `String`                  | Optional custom override         |
| `description`          | `String`                  | Flavour text                     |
| `mechanic_description` | `String`                  | Detailed mechanical effect text  |
| `technique_class`      | `Registry.TechniqueClass` | Physical, Special, or Status     |
| `targeting`            | `Registry.Targeting`      | Who can be targeted              |
| `element_key`          | `StringName`              | Element of this technique        |
| `power`                | `int`                     | Base power (0 for Status)        |
| `accuracy`             | `int`                     | Hit chance (0 = always hits, bypasses accuracy check) |
| `energy_cost`          | `int`                     | Energy to use                    |
| `priority`             | `Registry.Priority`       | Priority tier                    |
| `animation_key`        | `StringName`              | Override animation (future hook, default `&""`) |
| `flags`                | `Array[TechniqueFlag]`    | Contact, Sound, Beam, etc. Imported from technique-level `flags` field (dex export v3+). |
| `charge_required`      | `int`                     | Charges needed (0 = instant)     |
| `charge_conditions`    | `Array[Dictionary]`       | How charges are gained           |
| `bricks`               | `Array[Dictionary]`       | Modular effect definitions       |

### Brick Types (29)

The brick system enables modular effect composition. Each brick is a dictionary with a `brick` type field. Full parameter schemas are in `addons/dex_importer/BRICK_CONTRACT.md`.

| Brick Type           | Purpose                                          |
|----------------------|--------------------------------------------------|
| `damage`             | Deals damage (standard, fixed, percentage, etc.) |
| `damageModifier`     | Modifies damage calculation (ignore defence, etc.)|
| `recoil`             | User takes damage after attacking                |
| `statModifier`       | Raises or lowers stat stages                     |
| `statProtection`     | Prevents stat changes                            |
| `statusEffect`       | Inflicts or removes status conditions            |
| `statusInteraction`  | Interacts with existing statuses                 |
| `healing`            | Restores HP                                      |
| `fieldEffect`        | Sets weather, terrain, or global effects         |
| `sideEffect`         | Applies effects to a side of the field           |
| `hazard`             | Sets or removes entry hazards                    |
| `positionControl`    | Forces switches or traps targets                 |
| `turnEconomy`        | Multi-turn, multi-hit, or delayed effects        |
| `chargeRequirement`  | Requires a charge turn                           |
| `synergy`            | Combo/followUp effects with partner techniques   |
| `requirement`        | Technique fails if condition not met             |
| `conditional`        | Bonus effects under certain conditions           |
| `protection`         | Protects from attacks (full protection)           |
| `priorityOverride`   | Changes technique priority conditionally         |
| `elementModifier`    | Modifies element traits and resistance profiles  |
| `criticalHit`        | Modifies critical hit rate                       |
| `resource`           | Interacts with held items                        |
| `useRandomTechnique` | Uses a random technique                          |
| `transform`          | Transforms into target                           |
| `shield`             | Creates protective shields (decoy-like)           |
| `copyTechnique`      | Copies or mimics techniques                      |
| `abilityManipulation`| Copies, swaps, or suppresses abilities           |
| `turnOrder`          | Manipulates turn order                           |
| `outOfBattleEffect`  | Item-only: processed by ItemApplicator, invisible to battle engine |

### Per-Brick Conditions

Individual bricks can have a `condition` field — a condition string that must evaluate to true before the brick executes. Condition format:

- **Single**: `conditionType` or `conditionType:value`
- **Multiple (AND)**: `cond1|cond2|cond3` — all must pass

Evaluated by `BrickConditionEvaluator` (`scripts/utilities/brick_condition_evaluator.gd`). Supported on `damageModifier`, `statModifier`, and `statusEffect` bricks. Empty string or missing `condition` = always active.

#### Condition Types (32 Tier 1)

| Category | Conditions |
|----------|-----------|
| HP thresholds | `userHpBelow:N`, `userHpAbove:N`, `targetHpBelow:N`, `targetHpAbove:N`, `targetAtFullHp` |
| Status | `userHasStatus:key`, `targetHasStatus:key`, `targetNoStatus:key` |
| Element/type | `damageTypeIs:elem`, `techniqueIsType:elem` |
| Technique flags | `moveHasFlag:flag` |
| Traits | `userHasTrait:cat:trait`, `targetHasTrait:cat:trait`, `allyHasTrait:cat:trait` (categories: `element`, `movement`, `size`, `type`) |
| Field | `weatherIs:key`, `terrainIs:key` |
| Timing | `isFirstTurn`, `targetNotActed`, `targetActed` |
| Stats | `userStatHigher:abbr`, `targetStatHigher:abbr` |
| Energy | `userEpBelow:N`, `userEpAbove:N`, `targetEpBelow:N`, `targetEpAbove:N` |
| Technique class | `usingTechniqueOfClass:physical\|special\|status` |
| Turn | `turnIsLessThan:N`, `turnIsMoreThan:N` |
| Ability | `userHasAbility:key`, `targetHasAbility:key` |
| Effectiveness | `isSuperEffective`, `isNotVeryEffective` |
| Last technique | `lastTechniqueWas:key` |
| Items | `userHasItem:key`, `userHasNoItem:key`, `targetHasItem:key`, `targetHasNoItem:key` |

### damageModifier Brick

Not executed standalone — consumed by the `damage` brick handler. After base damage calculation, the damage handler collects `damageModifier` bricks from:

1. The technique's own bricks
2. The user's CONTINUOUS ability bricks (skipped if user is nullified)

Each modifier's `condition` is evaluated; passing modifiers apply their `multiplier` (default 1.0) and `flatBonus` (default 0). Final damage clamped to minimum 1.

### Technique Flags (16)

Flags are metadata on techniques that interact with abilities and status effects:

| Flag        | Description                                          |
|-------------|------------------------------------------------------|
| Contact     | Makes physical contact — triggers contact abilities  |
| Sound       | Sound-based — may bypass decoys                      |
| Punch       | Punch-based — boosted by fist-related abilities      |
| Kick        | Kick-based                                           |
| Bite        | Bite-based — boosted by jaw-related abilities        |
| Blade       | Slashing/blade-based                                 |
| Beam        | Beam/ray-based                                       |
| Explosive   | Explosion — may hit semi-invulnerable targets        |
| Bullet      | Projectile-based                                     |
| Powder      | Powder/spore — blocked by certain abilities          |
| Wind        | Wind-based — interacts with airborne states          |
| Flying      | Aerial — blocked by grounding field                  |
| Gravity     | Affected by grounding field                          |
| Defrost     | Thaws frozen user before executing                   |
| Reflectable | Can be reflected by technique reflection              |
| Snatchable  | Can be snatched                                      |

### Targeting (12)

Multi-side semantics: "Foe" = any side on a different team. "Ally" = same side. In FFA, every other side is a foe.

| Value            | Description                                          |
|------------------|------------------------------------------------------|
| Self             | User only                                            |
| Single Target    | Any one Digimon (ally or foe)                        |
| Single Other     | Any one Digimon except user                          |
| Single Ally      | One ally on same side (not self)                     |
| Single Foe       | One Digimon on any foe side                          |
| All Allies       | All Digimon on user's side (incl. self)              |
| All Other Allies | All allies on user's side except self                |
| All Foes         | All Digimon on all foe sides                         |
| All              | Every Digimon on the field                           |
| All Other        | Every Digimon except user                            |
| Single Side      | An entire side (for hazards, side effects)           |
| Field            | Entire field (weather, terrain, global)              |

---

## 9. Ability System

### Structure

Every Digimon has 3 possible abilities:
- **Slot 1**: Standard ability
- **Slot 2**: Standard ability (alternate)
- **Slot 3**: Secret/hidden ability

Only **one ability is active** at a time, stored as `active_ability_slot` on DigimonState.

### AbilityData Resource

| Field                  | Type                      | Description                      |
|------------------------|---------------------------|----------------------------------|
| `key`                  | `StringName`              | Unique identifier                |
| `name`                 | `String`                  | Display name                     |
| `description`          | `String`                  | Flavour text                     |
| `mechanic_description` | `String`                  | Detailed effect text             |
| `trigger`              | `Registry.AbilityTrigger` | When the ability activates       |
| `stack_limit`          | `Registry.StackLimit`     | How often it can trigger         |
| `trigger_condition`    | `String`                  | Condition string (BrickConditionEvaluator format) |
| `bricks`               | `Array[Dictionary]`       | Effect definitions (same system) |

### Trigger Events

| Trigger            | When it fires                              |
|--------------------|--------------------------------------------|
| `ON_ENTRY`         | When Digimon enters the field              |
| `ON_EXIT`          | When Digimon leaves the field              |
| `ON_TURN_START`    | At the start of the Digimon's turn         |
| `ON_TURN_END`      | At the end of the Digimon's turn           |
| `ON_BEFORE_TECHNIQUE` | Before the Digimon uses a technique     |
| `ON_AFTER_TECHNIQUE`  | After the Digimon uses a technique      |
| `ON_BEFORE_HIT`    | Before being hit by a technique            |
| `ON_AFTER_HIT`     | After being hit by a technique             |
| `ON_DEAL_DAMAGE`   | When dealing damage                        |
| `ON_TAKE_DAMAGE`   | When receiving damage                      |
| `ON_FAINT`         | When this Digimon faints                   |
| `ON_ALLY_FAINT`    | When an ally faints                        |
| `ON_FOE_FAINT`     | When a foe faints                          |
| `ON_STATUS_APPLIED`| When a status is applied to this Digimon   |
| `ON_STATUS_INFLICTED`| When this Digimon inflicts a status      |
| `ON_STAT_CHANGE`   | When any stat stage changes                |
| `ON_WEATHER_CHANGE`| When weather changes                       |
| `ON_TERRAIN_CHANGE`| When terrain changes                       |
| `ON_HP_THRESHOLD`  | When HP crosses a threshold                |
| `CONTINUOUS`       | Always active (passive effect)             |

### CONTINUOUS Abilities

CONTINUOUS abilities are not fired via `_fire_ability_trigger()`. Instead, their `damageModifier` bricks are collected by `BrickExecutor._collect_damage_modifiers()` during damage calculation. Each brick's `condition` string is evaluated against the current context. The nullified status suppresses CONTINUOUS ability effects.

### Trigger Condition Strings

`AbilityData.trigger_condition` is a condition string (same format as per-brick conditions). Evaluated by `BrickConditionEvaluator` in `BattleEngine._check_trigger_condition()`. Empty string = no condition (always triggers).

### Stack Limits

| Limit             | Description                              |
|-------------------|------------------------------------------|
| `UNLIMITED`       | Can trigger any number of times          |
| `ONCE_PER_TURN`   | Maximum once per turn                    |
| `ONCE_PER_SWITCH` | Maximum once per switch-in               |
| `ONCE_PER_BATTLE` | Maximum once per battle                  |
| `FIRST_ONLY`      | Only triggers the first time ever        |

---

## 10. Status Conditions

### No Stacking Limit

Multiple different status conditions can be active simultaneously. There is **no limit** on how many statuses a Digimon can have at once. Status stacking is a valid strategy.

### Override Rules

Thematic overrides and upgrade paths:
- **Burned** removes Frostbitten and Frozen
- **Frostbitten** removes Burned and Badly Burned
- Applying **Burned** to an already Burned Digimon upgrades to **Badly Burned** (escalating DoT)
- Applying **Frostbitten** to an already Frostbitten Digimon upgrades to **Frozen**
- Applying **Poisoned** to an already Poisoned Digimon upgrades to **Badly Poisoned** (escalating DoT)
- Applying **Asleep** to an Exhausted Digimon removes Exhausted, then applies Asleep

### Full Status Table (23)

| Status         | Category | Mechanics                                              |
|----------------|----------|--------------------------------------------------------|
| Asleep         | Negative | Cannot act. Wakes after 2-5 turns or when hit.        |
| Burned         | Negative | 1/16 max HP DoT. Physical ATK halved.                 |
| Badly Burned   | Negative | Escalating DoT (1/16→1/8→1/4→1/2→1/1). ATK halved. Resets on switch. |
| Frostbitten    | Negative | 1/16 max HP DoT. Special ATK halved.                  |
| Frozen         | Negative | Cannot act. Thaws after 1-3 turns or fire hit.        |
| Exhausted      | Negative | +50% energy cost on techniques.                       |
| Poisoned       | Negative | 1/8 max HP DoT.                                       |
| Badly Poisoned | Negative | Escalating DoT (1/16→1/8→1/4→1/2→1/1). Resets on switch. |
| Dazed          | Negative | Equipped gear effects disabled.                       |
| Trapped        | Negative | Cannot switch out.                                    |
| Confused       | Negative | Uses random technique. Duration 2-5 turns.            |
| Blinded        | Negative | Accuracy significantly reduced.                       |
| Paralysed      | Negative | SPD halved. May fail to act (25%).                    |
| Bleeding       | Negative | -1/8 HP when using a technique. Removed by resting.   |
| Encored        | Negative | Must repeat last technique for duration.              |
| Taunted        | Negative | Can only use damaging techniques for duration.        |
| Disabled       | Negative | One specific technique unusable for duration.         |
| Perishing      | Negative | Faints when countdown reaches 0 (default 3 turns).   |
| Seeded         | Negative | Loses 1/8 HP/turn, seeder gains it.                  |
| Regenerating   | Positive | Restores HP each turn.                                |
| Vitalised      | Positive | -50% energy cost on techniques.                       |
| Nullified      | Neutral  | Ability is suppressed.                                |
| Reversed       | Neutral  | Stat changes are inverted.                            |

### Escalating DoT (Badly Burned / Badly Poisoned)

Badly Burned and Badly Poisoned deal escalating damage each turn based on a turn counter:

| Turn | Fraction | Damage (of max HP) |
|------|----------|--------------------|
| 0    | 1/16     | 6.25%              |
| 1    | 1/8      | 12.5%              |
| 2    | 1/4      | 25%                |
| 3    | 1/2      | 50%                |
| 4+   | 1/1      | 100%               |

The escalation counter resets to 0 when the Digimon switches out, but the status itself persists.

### Resistance-Based Status Immunities

Status immunities are determined by the target's effective resistance to the associated element. If `get_effective_resistance()` returns ≤ 0.5 (resistant or immune), the status is blocked.

| Element   | Immune To                      | Threshold        |
|-----------|--------------------------------|------------------|
| Fire      | Burned, Badly Burned           | resistance ≤ 0.5 |
| Ice       | Frostbitten, Frozen            | resistance ≤ 0.5 |
| Dark      | Poisoned, Badly Poisoned       | resistance ≤ 0.5 |
| Lightning | Paralysed                      | resistance ≤ 0.5 |
| Plant     | Seeded                         | resistance ≤ 0.5 |

Specific abilities may also grant status immunities regardless of resistance.

---

## 11. Field Mechanics

### Weather

- **One active at a time** — new weather replaces the current one
- Set by techniques (possibly abilities too)
- Effects: damage multipliers, accuracy changes, energy cost modifications, healing per turn, etc.

### Terrain

- **One active at a time** — new terrain replaces the current one
- Affects grounded Digimon
- Effects: element power boosts, status immunity, HP recovery, etc.

### Hazards

- **Stackable** — multiple can exist on each side
- Trigger on switch-in
- Can be removed by specific techniques
- Examples: damage on entry, status on entry, stat drops on entry

### Field Effects

- **Stackable** — multiple global effects simultaneously
- Affect the entire field (both sides), or one side
- Examples: speed inversion, grounding field (prevents airborne), etc.

---

## 12. Item System

### Categories (8)

| Category     | Combat Use | Description                                          |
|--------------|------------|------------------------------------------------------|
| General      | No         | Non-combat items, sellables, world interaction       |
| Capture/Scan | Yes        | Scanning equipment for data collection               |
| Medicine     | Yes        | HP/energy/status healing, combat usable              |
| Performance  | No         | IV/TV/level/evolution manipulation                   |
| Gear         | Passive    | Equipable + consumable, one each per Digimon         |
| Key          | No         | Story progression, passive effects                   |
| Quest        | No         | Location-specific quest items                        |
| Card         | No         | Teach techniques to specific Digimon                 |

### Data Layer

- **`ItemData`** (`data/item/item_data.gd`): Base item resource with key, name, description, category, is_consumable, is_combat_usable, is_revive, buy_price, sell_price, icon_texture, bricks
- **`GearData`** (`data/item/gear_data.gd`): Extends ItemData with gear_slot, trigger, stack_limit, trigger_condition (mirrors AbilityData fields)
- **`BagState`** (`scripts/systems/battle/bag_state.gd`): Battle-specific item bag tracking quantities per key. Methods: add_item, remove_item, has_item, get_quantity, get_combat_usable_items, get_items_in_category, to_dict/from_dict
- **`SideState.bag`**: Optional `BagState` per side, injected via `BattleConfig.side_configs[i]["bag"]`

### Medicine Resolution

Medicine items target party members by roster index (`BattleAction.item_target_party_index`). The roster is built as: active slot Digimon first, then party reserves.

- **Non-revive medicines**: Target non-fainted party members (including active ones). Execute healing/statModifier bricks via `BrickExecutor`
- **Revive medicines** (`is_revive = true`): Target fainted party members only. For reserve DigimonState, healing is applied directly to `current_hp`
- **Healing brick types**: `fixed` (flat HP), `percentage` (% of max HP), `energy_fixed` (flat energy), `energy_percentage` (% of max energy), optional `cureStatus` (string or array of status keys)
- Item actions resolve at `Priority.MAXIMUM` (before techniques), same as Pokemon

### Gear System

Each Digimon has two gear slots:
- **Equipable** (`GearSlot.EQUIPABLE`): Persistent passive effect via `equipped_gear_key`
- **Consumable** (`GearSlot.CONSUMABLE`): Single-use triggered effect via `equipped_consumable_key`

Gear effects are defined via bricks (same system as techniques and abilities). GearData has trigger, stack_limit, and trigger_condition fields identical to AbilityData.

### Gear Triggers

`_fire_gear_trigger()` in BattleEngine mirrors `_fire_ability_trigger()`:
- Fires alongside every ability trigger call (ON_TURN_START, ON_BEFORE_TECHNIQUE, ON_DEAL_DAMAGE, ON_TAKE_DAMAGE, ON_AFTER_TECHNIQUE, ON_ENTRY, ON_TURN_END)
- Checks both `equipped_gear_key` and `equipped_consumable_key` per Digimon
- Enforces stack limits via `BattleDigimonState.gear_trigger_counts` (separate from ability trigger counts)
- **CONTINUOUS gear**: Damage modifiers collected in `_collect_damage_modifiers()` (user's offensive gear + target's defensive gear)
- **Consumable gear consumption**: When a consumable gear fires, `equipped_consumable_key` is cleared and a "consumed" message emitted
- **Suppression**: All gear effects blocked by `has_status(&"dazed")` or `field.has_global_effect(&"gear_suppression")`
- **Write-back**: `equipped_consumable_key` persists to `DigimonState` on battle end

### Scan Mechanic

Instead of capture balls, players scan wild Digimon:
- Each scan attempt accumulates data percentage
- At sufficient percentage, Digimon can be recreated at a terminal
- Scan progress stored in `GameState.scan_log`

---

## 13. Autoloads

### Settings (`autoload/settings.gd`)

Player display preferences, persisted to `user://settings.cfg`:
- `display_preference: DisplayPreference` — `JAPANESE` or `DUB` (default: `DUB`)
- `use_game_names: bool` — enable game-specific custom names (default: `true`)
- Signals: `display_preference_changed`, `use_game_names_changed`
- Auto-saves on change, auto-loads on `_ready()`

### Registry (`autoload/registry.gd`)

Central enum registry containing all game enums and constants:

**Enums**: Attribute, Element, Stat, GameMode, EvolutionLevel, TechniqueClass, Targeting, Priority, BrickType, TechniqueFlag, AbilityTrigger, StackLimit, StatusCondition, StatusCategory, BattleStat, BrickTarget, BattleCounter, EvolutionType, ItemCategory, GearSlot, GrowthRate

**Constants**:
- `STAT_STAGE_MULTIPLIERS`: Dictionary mapping stage (-6 to +6) to multiplier
- `PRIORITY_SPEED_MULTIPLIERS`: Dictionary mapping priority tier to speed multiplier
- `BRICK_STAT_MAP`: Dictionary mapping dex stat abbreviations to BattleStat enum
- `CRIT_STAGE_RATES`: Dictionary mapping crit stage (0-3) to crit chance
- `CRIT_DAMAGE_MULTIPLIER`: float (1.5)
- `WEATHER_TYPES`, `TERRAIN_TYPES`, `HAZARD_TYPES`, `GLOBAL_EFFECT_TYPES`, `SIDE_EFFECT_TYPES`, `SHIELD_TYPES`, `SEMI_INVULNERABLE_STATES`: Constant arrays of valid battle effect names
- `DEX_PRIORITY_MAP`: Dictionary mapping dex priority integers (-4 to 4) to `Priority` enum values

Each enum has a corresponding `_labels` dictionary using `tr()` for localisation.

### Atlas (`autoload/atlas.gd`)

Data resource loader with typed dictionaries:
- `digimon`, `techniques`, `abilities`, `evolutions`, `elements`, `items`, `status_effects`, `personalities`, `tamers`, `shops`
- Loads all `.tres` files from `data/` folders on `_ready()`
- Resources keyed by their `key` field

### Game (`autoload/game.gd`)

Game lifecycle manager:
- `state: GameState` — current game state (null if no game)
- `game_mode: Registry.GameMode` — current mode (TEST or STORY)
- `screen_context: Dictionary` — context passed to the current screen
- `screen_result: Variant` — result from the current screen (null on cancel)
- `new_game()` — creates fresh GameState
- `load_game(slot)` — loads from save file (passes `game_mode` to SaveManager)
- `save_game(slot)` — saves current state (passes `game_mode` to SaveManager)
- `return_to_menu()` — clears state, returns to main menu

### SceneManager (`autoload/scene_manager.gd`)

Scene transitions with fade:
- CanvasLayer 100 with ColorRect overlay
- `change_scene(path, fade_duration)` — tween-based fade transition
- `change_scene_instant(path)` — no fade
- Signals: `transition_started`, `transition_finished`

---

## 14. Data Ingestion Pipeline

Data flows from digimon-dex to this game:

```
digimon-dex API → Dex Importer Plugin → .tres resources + translation CSVs
```

### Field Mapping

| Dex Table           | Game Resource          | Key Mapping                     |
|---------------------|------------------------|---------------------------------|
| `Digimon`           | `DigimonData`          | `game_id` -> `key`              |
| `Attack`            | `TechniqueData`        | `game_id` -> `key`              |
| `Ability`           | `AbilityData`          | `game_id` -> `key`              |
| `Item`              | `ItemData` / `GearData`| `game_id` -> `key`              |
| `DigimonEvolution`  | `EvolutionLinkData`    | composite -> `key`              |
| `Element`           | element definitions    | `name` -> `key`                 |
| `Attribute`         | `Registry.Attribute`   | `name` -> enum value            |

**Terminology**: What the dex calls "attacks" (Attack table, AttackClass enum) maps to "techniques" in this game (TechniqueData, TechniqueClass enum).

---

## 15. Translation System

### Three-Tier Naming

Most named entities have three name fields:
1. `jp_name` — Original Japanese name
2. `dub_name` — Official English localisation name
3. `custom_name` — Optional game-specific override

Resolution: `custom_name > dub_name > jp_name`

### CSV Internationalisation

Translation CSV files live in `data/locale/`. All user-facing text uses `tr()` for translation readiness. Enum labels are pre-mapped to translation keys (e.g., `tr("attribute.vaccine")`).

---

## 16. Save System

### Architecture

```
GameState (root)
├── tamer_name: String
├── tamer_id: StringName
├── play_time: int
├── party: PartyState
│   └── members: Array[DigimonState]
├── storage: StorageState
│   └── boxes: Array[Dictionary]  (100 boxes × 50 slots each)
│       └── { "name": String, "slots": Array[DigimonState | null] }
├── inventory: InventoryState
│   ├── items: Dictionary[StringName, int]
│   └── bits: int
├── story_flags: Dictionary
└── scan_log: Dictionary[StringName, float]
```

### Serialisation Strategy: Source Data Only

**Principle**: Only save data that cannot be derived. Recalculate derived values on load.

**Saved**: key, nickname, level, XP, personality_key, IVs, TVs, known techniques, equipped techniques, active ability slot, gear keys, scan data

**Recalculated on load**: All stat values (from stat formula), display names (from Atlas)

### SaveManager

Mode-based save directories — saves are segregated by game mode:

```gdscript
# All methods accept a mode parameter (defaults to TEST)
SaveManager.save_game(state, "slot1", mode)              # JSON (dev)
SaveManager.save_game(state, "slot1", mode, true)        # Binary (production)
SaveManager.load_game("slot1", mode)                     # Auto-detects format
SaveManager.save_exists("slot1", mode)
SaveManager.delete_save("slot1", mode)
SaveManager.get_save_slots(mode)
SaveManager.get_save_metadata("slot1", mode)             # Read metadata only
SaveManager.get_save_dir(mode)                           # Returns directory path
```

Save directories: `user://saves/test/` (TEST mode), `user://saves/story/` (STORY mode).

Save files use a metadata envelope format:
```json
{
  "meta": {
    "tamer_name": "...", "play_time": 0, "saved_at": 0,
    "party_keys": [...], "party_levels": [...], "mode": 0
  },
  "state": { ... }  // GameState.to_dict()
}
```

Backward-compatible: `_load_json`/`_load_binary` handle both envelope and flat (legacy) formats.

### Serialisation Pattern

All state classes implement `to_dict()` and `from_dict()`:

```gdscript
func to_dict() -> Dictionary:
    return {"key": key, "level": level, ...}

static func from_dict(data: Dictionary) -> DigimonState:
    var state := DigimonState.new()
    state.key = StringName(data.get("key", ""))
    state.level = data.get("level", 1)
    return state
```

---

## 17. Overworld System

### 2D Top-Down

- TileMapLayer-based maps
- Player character with 4-directional movement
- NPCs with dialogue
- Area transitions via SceneManager

### Wild Encounters

- Encounters trigger in designated zones
- Encounter rate and available Digimon vary by area
- Transitions to the single battle scene with encounter data

---

## 18. Multi-Side Battle Architecture

### Field → Side → Slot Hierarchy

The battle state uses a three-level hierarchy modelled after Pokemon Showdown's architecture:

```
BattleState
├── format: BattleFormat { side_count, slots_per_side, team_assignments, party_size }
├── field: FieldState
│   ├── weather: { key, duration, setter_side }
│   ├── terrain: { key, duration, setter_side }
│   └── global_effects: Array[{ key, duration }]
├── sides: Array[SideState]  (2-4)
│   ├── team_index: int
│   ├── side_effects: Array[{ key, duration }]
│   ├── hazards: Array[{ key, layers }]
│   ├── retired_battle_digimon: Array[BattleDigimonState]  (switched-out, for XP)
│   └── slots: Array[SlotState]  (1-3)
│       └── digimon: BattleDigimonState
├── action_queue: Array[BattleAction]
└── turn_number: int
```

### Side and Team Model

A "side" = one tamer's field presence. A "team" = a group of allied sides. Sides with the same `team_assignments` value are allies; different values are foes.

| Format | side_count | slots_per_side | team_assignments | Description |
|---|---|---|---|---|
| Singles 1v1 | 2 | 1 | [0, 1] | Standard single battle |
| Doubles 2v2 (1 tamer each) | 2 | 2 | [0, 1] | Each tamer controls 2 slots |
| Doubles 2v2 (2 tamers per team) | 4 | 1 | [0, 0, 1, 1] | 4 tamers, 2 per team |
| Triples 3v3 | 2 | 3 | [0, 1] | Each tamer controls 3 slots |
| 3-player FFA | 3 | 1 | [0, 1, 2] | Every tamer for themselves |
| 4-player FFA | 4 | 1 | [0, 1, 2, 3] | Every tamer for themselves |
| 2v1 Boss | 2 | varies | [0, 1] | Boss side has fewer but stronger Digimon |

### Effect Scope Rules

| Effect Type | Scope | Example |
|---|---|---|
| Weather, terrain | Whole field (all sides) | Rain affects everyone |
| Global effects | Whole field (all sides) | Speed inversion affects everyone |
| Side effects | Per-side (one tamer) | Physical barrier protects only that tamer's Digimon |
| Hazards | Per-side (one tamer) | Entry damage affects only that tamer's switch-ins |
| Targeting "all foes" | All slots on all foe-team sides | Hits every enemy Digimon on field |
| Targeting "all allies" | All slots on all allied-team sides | Hits every ally including self |

No adjacency restrictions — all targets are reachable regardless of slot position.

### Technique Execution Pipeline

1. **Pre-execution**: Check requirements, energy, taunt/disable/encore
2. **Targeting**: Resolve Targeting enum to actual slots
3. **Per-target**: Accuracy → Base power → Crit check → Damage calc → Modifiers → Apply
4. **Secondary effects**: Status, stat changes from bricks
5. **Self-effects**: Recoil, self stat changes, healing, switch-out
6. **Post-execution**: Contact ability triggers, item consumption, faint checks

### Event System

Abilities, status conditions, field effects, and gear register event handlers. The engine calls `run_event(event_type, context)` at each pipeline stage. Handlers are priority-sorted and can modify, block, or relay data.

---

## 19. Battle Constants

### Configurable via GameBalance

| Constant | Default | Description |
|---|---|---|
| `default_weather_duration` | 5 | Turns weather lasts |
| `default_terrain_duration` | 5 | Turns terrain lasts |
| `default_global_effect_duration` | 5 | Turns global effects last |
| `default_side_effect_duration` | 5 | Turns side effects last |
| `sleep_min_turns` / `sleep_max_turns` | 2 / 5 | Sleep duration range |
| `freeze_min_turns` / `freeze_max_turns` | 1 / 3 | Freeze duration range |
| `confusion_min_turns` / `confusion_max_turns` | 2 / 5 | Confusion duration range |
| `encore_duration` | 3 | Encore status duration |
| `taunt_duration` | 3 | Taunt status duration |
| `disable_duration` | 4 | Disable status duration |
| `perish_countdown` | 3 | Perishing countdown |
| `protection_fail_escalation` | 0.5 | Protection fail chance per consecutive use |
| `decoy_hp_cost_percent` | 0.25 | HP cost to create decoy |
| `crit_damage_multiplier` | 1.5 | Critical hit damage multiplier |
| `element_stab_multiplier` | 1.5 | STAB bonus when technique element matches user's element traits |
| `max_sides` | 4 | Maximum sides in a battle |
| `max_slots_per_side` | 3 | Maximum active Digimon per side |

### Hardcoded in Registry

| Constant | Values |
|---|---|
| `CRIT_STAGE_RATES` | 0: 1/24, 1: 1/8, 2: 1/2, 3: 1/1 |
| `WEATHER_TYPES` | sun, rain, sandstorm, hail, snow, fog |
| `TERRAIN_TYPES` | flooded, blooming |
| `HAZARD_TYPES` | entry_damage, entry_stat_reduction |
| `GLOBAL_EFFECT_TYPES` | grounding_field, speed_inversion, gear_suppression, defence_swap |
| `SIDE_EFFECT_TYPES` | physical_barrier, special_barrier, dual_barrier, stat_drop_immunity, status_immunity, speed_boost, crit_immunity, spread_protection, priority_protection, first_turn_protection |
| `SHIELD_TYPES` | hp_decoy, intact_form_guard, endure, last_stand, negate_one_move_class |
| `SEMI_INVULNERABLE_STATES` | sky, underground, underwater, shadow, intangible |

---

## 20. Testing Architecture

### Framework

Tests use the **GUT** (Godot Unit Test) addon in `addons/gut/`. Tests run headless via:

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Configuration is in `.gutconfig.json` pointing to `res://tests/`.

### Test Data Factory

`TestBattleFactory` (`tests/helpers/test_battle_factory.gd`) injects synthetic resources directly into Atlas dictionaries at runtime:

- 5 test Digimon species (test_agumon, test_gabumon, test_patamon, test_tank, test_speedster)
- 12+ test techniques covering all classes, elements, targeting types, and flags
- 6 test abilities covering all trigger types and stack limits
- 12 test items: 7 medicine (potion, super_potion, energy_drink, burn_heal, full_heal, revive, x_attack), 4 gear (power_band, counter_gem, heal_berry, element_guard), 1 capture (scanner)
- 3 test personalities (neutral, brave, modest)

All test keys are prefixed with `test_` and cleaned up via `clear_test_data()`.

`TestScreenFactory` (`tests/helpers/test_screen_factory.gd`) provides screen-specific test data: `create_test_game_state()`, `create_test_party()`, `create_test_inventory()`, `create_test_storage()`, `create_test_shop()`. Delegates Atlas injection/cleanup to TestBattleFactory.

### Test Data Isolation

Tests **never** use imported dex data. This ensures tests remain stable regardless of balance changes to real game data. `inject_all_test_data()` runs in `before_all()`, `clear_test_data()` in `after_all()`.

### Deterministic RNG

All battles use a fixed seed (default `12345`) passed to `BattleFactory.create_battle()`. Different seeds produce different outcomes (e.g., hit vs miss). Tests that depend on specific RNG outcomes document which seed produces which result.

### Test Structure

```
tests/
  helpers/
    test_battle_factory.gd   # Synthetic test data + battle creation helpers
    test_screen_factory.gd   # Screen test data helpers (delegates to TestBattleFactory)
  unit/                       # Non-battle unit tests
    test_stat_calculator.gd
    test_digimon_state.gd
    test_storage_state.gd
    test_inventory_state.gd
    test_training_calculator.gd
    test_evolution_checker.gd
  battle/
    unit/                     # Battle-specific unit tests
      test_damage_calculator.gd
      test_action_sorter.gd
      test_xp_calculator.gd
      test_battle_digimon_state.gd
      test_brick_executor.gd
      test_field_state.gd
      test_side_state.gd
      test_bag_state.gd
      ... (25 test files)
    integration/              # Engine + signals + full turn loop
      test_battle_engine_core.gd
      test_technique_execution.gd
      test_status_conditions.gd
      ... (18 test files)
  screens/                    # Screen tests (future)
```

### Signal Verification

Integration tests use GUT's `watch_signals()` + `assert_signal_emitted()` / `assert_signal_emit_count()`. For parameter checking, tests connect lambdas to capture values before asserting.

---

## Post-Battle System

### XP Award Algorithm

XP is calculated by `XPCalculator.calculate_xp_awards(battle, exp_share_enabled)` after a battle ends with a winner:

1. **Determine winning team** from `battle.result.winning_team`. Draw/fled = no XP.
2. **Collect defeated foes** from all losing sides — both active slots and `side.retired_battle_digimon` where `is_fainted == true`.
3. **Collect winning-side Digimon** — active slots + retired (deduplicated by `source_state`).
4. **Skip fainted winners** — fainted allies on the winning team receive no XP.
5. **Per winner × per defeated foe**:
   - If `foe_unique_id in participated_against_ids`: full XP, split by participant count.
   - If NOT participated AND `exp_share_enabled`: 50% XP (not split by participants).
   - Otherwise: 0 XP for this foe.
6. **Capture pre-XP state** (`old_level`, `old_experience`, `old_stats`) before calling `apply_xp`.
7. **Apply XP** — levels up, learns new techniques, returns award dict.

### Participation Tracking

- `BattleDigimonState.participated_against_ids` tracks the unique IDs of foes a Digimon has participated against.
- When a Digimon switches out, its `BattleDigimonState` is preserved in `SideState.retired_battle_digimon`.
- When a Digimon switches back in, its previous participation data is carried forward from the retired entry.
- `_count_participants` counts both active and retired Digimon when splitting XP.

### BattleConfig Extensions

- `exp_share_enabled: bool` — when true, non-participants receive 50% XP. Serialised in `to_dict()`/`from_dict()`.

### BattleResult Extensions

- `party_digimon: Array[DigimonState]` — all DigimonState on the winning side, for post-battle display (active + reserves, deduplicated).
- `xp_awards` dict now includes: `digimon_state`, `xp`, `old_level`, `old_experience`, `old_stats`, `levels_gained`, `new_techniques`, `participated`.

### Post-Battle Screen Flow

1. Show outcome and turn count.
2. Build `XPAwardRow` for each party Digimon — full row if XP earned, greyed out if no XP.
3. Auto-equip new techniques if equipped slots have room (`< max_equipped_techniques`).
4. Queue technique swap popups for any new technique when slots are full.
5. Animate all XP bars (tween through level-ups).
6. Process technique swap queue sequentially (one popup at a time).
7. Enable continue button after all animations and swaps resolve.

### Technique Swap Flow

When a Digimon learns a new technique at level-up and already has `max_equipped_techniques` equipped:
- `TechniqueSwapPopup` shows all currently equipped techniques + the new one.
- Player can click an equipped technique to forget it (replaced by the new one).
- Player can click "Don't Learn" to keep current setup (new technique remains in `known_technique_keys` only).
- The forgotten technique is NOT removed from `known_technique_keys` — it can be re-equipped later.

---

## Tamer System

### TamerData Resource

Immutable template defining an NPC tamer (`data/tamer/tamer_data.gd`):

| Field | Type | Description |
|---|---|---|
| `key` | `StringName` | Unique identifier |
| `name` | `String` | Display name |
| `title` | `String` | Title (e.g. "Gym Leader") |
| `party_config` | `Array[Dictionary]` | Party build config per Digimon |
| `item_keys` | `Array[StringName]` | Items for battle use |
| `ai_type` | `StringName` | AI behaviour key |
| `sprite_key` | `StringName` | Overworld/battle sprite |
| `battle_dialogue` | `Dictionary` | intro/win/lose dialogue |
| `reward_bits` | `int` | Currency reward on defeat |
| `reward_items` | `Array[Dictionary]` | Item rewards on defeat |

### TamerState Runtime

Built from `TamerData` via `TamerState.from_tamer_data(data)`:
- Creates party via `DigimonFactory.create_digimon()` for each `party_config` entry
- Applies overrides: `ability_slot`, `technique_keys`, `gear_key`, `consumable_key`
- `to_battle_side_config()` returns a Dictionary suitable for `BattleConfig.side_configs`

### ShopData Resource

Immutable shop template (`data/shop/shop_data.gd`):

| Field | Type | Description |
|---|---|---|
| `key` | `StringName` | Unique identifier |
| `name` | `String` | Display name |
| `stock` | `Array[Dictionary]` | `{ item_key, price, quantity }` (-1 = unlimited) |
| `buy_multiplier` | `float` | Price multiplier for buying (1.0 = base) |
| `sell_multiplier` | `float` | Price multiplier for selling (0.5 = half) |

---

## Utility Classes

### TrainingCalculator (`scripts/utilities/training_calculator.gd`)

Pure static utility for Digimon stat training courses. Reads course config from `GameBalance.training_courses`.

- `run_course(difficulty, rng)` → `{ "steps": Array[bool], "tv_gained": int }` — 3 steps per course, each pass/fail based on `pass_rate`
- `get_tp_cost(difficulty)`, `get_tv_per_step(difficulty)`, `get_pass_rate(difficulty)` — lookup helpers

Training course tiers (from GameBalance):
| Difficulty | TP Cost | TV/Step | Pass Rate |
|---|---|---|---|
| basic | 1 | 2 | 90% |
| intermediate | 3 | 5 | 60% |
| advanced | 5 | 10 | 30% |

### EvolutionChecker (`scripts/utilities/evolution_checker.gd`)

Pure static utility for checking evolution requirements against a DigimonState and inventory.

- `check_requirements(link, digimon, inventory)` → `Array[Dictionary]` with `{ type, description, met }`
- `can_evolve(link, digimon, inventory)` → `bool` (true only if all requirements met)
- Handles all 7 requirement types: `level`, `stat`, `stat_highest_of`, `spirit`, `digimental`, `x_antibody`, `description` (always unmet)
- Uses `StatCalculator.calculate_stat()` for computed stat comparisons

### FormatUtils (`scripts/utilities/format_utils.gd`)

Shared formatting utilities extracted from screen scripts to eliminate duplication.

- `format_bits(amount)` → comma-separated number string (e.g. `1234567` → `"1,234,567"`)
- `format_play_time(seconds)` → `"h:mm:ss"` format
- `format_saved_at(unix)` → `"DD-MM-YYYY HH:MM"` or `"Unknown"` for invalid timestamps
- `build_party_text(meta)` → `"Name Lv.X, Name Lv.Y"` from save metadata dictionary

### ItemApplicator (`scripts/utilities/item_applicator.gd`)

Applies item bricks to a DigimonState outside of battle. Handles healing bricks (bug-fixed from original `bag_screen._apply_medicine()`) and `outOfBattleEffect` bricks.

- `apply(item_data, digimon, max_hp, max_energy)` → `bool` — iterates bricks, delegates to type handlers
- `get_max_stats(digimon)` → `{ "max_hp": int, "max_energy": int }` — personality-aware stat calculation
- Healing type discrimination uses `brick.get("type")` (not `"subtype"`) and `percent / 100.0` scaling
- `cureStatus` field handled as both String and Array
- `outOfBattleEffect` brick effects: `toggleAbility`, `switchSecretAbility`, `addTv`, `removeTv`, `addIv`, `removeIv`, `changePersonality`, `clearPersonality`, `addTp`

---

## Screen Navigation System

### Navigation Flow

```
Title Screen → Save Screen (select) → Mode Screen (hub)
                                         ├→ Party Screen → context menu → Summary Screen → Party Screen
                                         │               → context menu → Bag Screen (select) → Party Screen
                                         ├→ Bag Screen → Use → Party Screen (select) → Bag Screen (medicine applied)
                                         ├→ Battle Builder → Battle → Battle Builder → Mode Screen
                                         ├→ Save Screen (save) → Mode Screen
                                         ├→ Settings → Mode Screen
                                         └→ [Storage, Wild Battle, Shop, Training — disabled for now]
Title Screen → Settings → Title Screen
```

### `Game.screen_context` Pattern

Screens communicate via `Game.screen_context`, a Dictionary set before navigating:

```gdscript
# Navigating TO a screen — set context before calling change_scene:
Game.screen_context = {
    "action": "select",
    "mode": Registry.GameMode.TEST,
    "return_scene": "res://scenes/main/main.tscn",
}
SceneManager.change_scene("res://scenes/screens/save_screen.tscn")

# The receiving screen reads context in _ready():
var action: String = Game.screen_context.get("action", "select")
var return_scene: String = Game.screen_context.get("return_scene", "")
```

Context persists across sub-navigation (e.g. Mode Screen → Battle Builder → Battle → Builder — the builder's `return_scene` survives the full cycle).

### Screens

**Title Screen** (`scenes/main/main.tscn`): Test Mode button → Save Screen (select), Story Mode (disabled), Settings.

**Save Screen** (`scenes/screens/save_screen.tscn`): Three-slot save management. Context `action` determines behaviour:
- `"select"` — from Title: shows Load/Delete on occupied slots, New Game on empty
- `"save"` — from Mode Screen: shows Save/Delete on occupied, Save on empty
- `"load"` — shows Load/Delete on occupied, nothing on empty

**Mode Screen** (`scenes/screens/mode_screen.tscn`): Central hub. Shows tamer name, bits, party strip. Button grid: Party, Bag, Save, Battle Builder, Settings (enabled); Storage, Wild Battle, Shop, Training (disabled — Coming Soon). TEST mode shows battle/wild/shop/training buttons; STORY mode hides them.

**Party Screen** (`scenes/screens/party_screen.tscn`): View/manage active party. DigimonSlotPanels with context menus (Summary, Item, Switch, Evolution). Supports select mode for cross-screen flows (e.g. Bag "Use" picks a target Digimon). Context: `mode`, `select_mode`, `select_filter`, `select_prompt`, `return_scene`. Result: `{"party_index": int, "digimon": DigimonState}` or `null`.

**Bag Screen** (`scenes/screens/bag_screen.tscn`): View/manage inventory. Category tabs, item list with detail panel. Actions: Use (medicine applicator), Toss. "Give" disabled (Coming Soon — needs Held Items page). Use flow: Bag → Party Screen (select) → Bag (applies medicine via `_bag_pending_use` round-trip in `screen_context`).

**Summary Screen** (`scenes/screens/summary_screen.tscn`): Four-page Digimon detail view. Page 1 (Info): sprite, name, species, attribute, elements, personality (with override display if set), active ability section, OT, level/XP, TP. Page 2 (Stats): 7 stat rows with personality colouring (uses effective personality), IV/TV labels, BST total. Page 3 (Techniques): equipped list with unequip, known list with equip/swap. Page 4 (Held Items): gear and consumable slots with item details and remove buttons. Party navigation arrows cycle through party members.

### Select Mode Pattern

Several screens support a "select mode" for cross-screen data exchange:
1. The initiating screen sets `Game.screen_context` with `select_mode: true`, `select_filter: Callable`, `select_prompt: String`
2. The target screen shows filtered options; user picks one
3. The target screen sets `Game.screen_result` with the selection and navigates back
4. The initiating screen reads `Game.screen_result` in `_ready()` to handle the response
5. For round-trips (Bag → Party → Bag), the Bag stores pending state in `screen_context` keys prefixed with `_bag_`

### Medicine Applicator

Out-of-battle item use is handled by `BagScreen._apply_medicine()`. Interprets healing bricks from `ItemData.bricks`:
- `"fixed"` — add flat HP
- `"percentage"` — add % of max HP
- `"energy_fixed"` / `"energy_percentage"` — heal energy
- `"status"` — heal HP + cure specified statuses
- `"full_restore"` — max HP, max energy, clear all statuses
- `"revive"` — restore fainted Digimon to % of max HP

---

## Important Technical Notes

- **Godot Version**: 4.6 (GDScript only, no C#)
- **No 3D**: This is a pure 2D project
- **British English**: All code, comments, and docs
- **Tabs**: GDScript uses tabs (not spaces)
- **Key references**: StringName keys between resources, never direct resource paths
- **Atlas lookup**: `Atlas.digimon[key]`, `Atlas.techniques[key]`, etc.
- **Registry access**: `Registry.Attribute.VACCINE`, `Registry.STAT_STAGE_MULTIPLIERS[-3]`
- **Combat Roles**: Exist only in digimon-dex for base stat generation. NOT needed in this game — only the resulting base stats matter.
- **No `%` unique name syntax**: `%NodeName` does not work reliably in hand-edited .tscn files. Always use `$Path/To/Node` or `get_node("Path/To/Node")` instead. Use path constants for deeply nested nodes (e.g. `const _GRID := "MarginContainer/VBox/ButtonGrid"`).

---

*Last Updated: 2026-02-12*

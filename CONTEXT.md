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
| `level`                   | `int`                    | Evolution level (1-10)             |
| `attribute`               | `Registry.Attribute`     | Vaccine, Virus, Data, etc.         |
| `type_tag`                | `String`                 | Descriptive tag (e.g., "Dragon")   |
| `base_hp` through `base_speed` | `int`              | 7 base stat values                 |
| `bst`                     | `int`                    | Base Stat Total                    |
| `resistances`             | `Dictionary`             | Element key -> float multiplier    |
| `innate_technique_keys`   | `Array[StringName]`      | Signature techniques               |
| `learnable_technique_keys`| `Array[StringName]`      | All learnable techniques           |
| `ability_slot_1_key`      | `StringName`             | Standard ability slot 1            |
| `ability_slot_2_key`      | `StringName`             | Standard ability slot 2            |
| `ability_slot_3_key`      | `StringName`             | Hidden/secret ability              |

### DigimonState Runtime

| Field                    | Type                | Description                         |
|--------------------------|---------------------|-------------------------------------|
| `key`                    | `StringName`        | Which DigimonData template          |
| `nickname`               | `String`            | Player-given name                   |
| `level`                  | `int`               | Current level                       |
| `experience`             | `int`               | Current XP                          |
| `personality_key`        | `StringName`        | Personality reference               |
| `ivs`                    | `Dictionary`        | Stat key -> 0-50 (permanent)        |
| `tvs`                    | `Dictionary`        | Stat key -> 0-500 (earned)          |
| `current_hp`             | `int`               | Current hit points                  |
| `current_energy`         | `int`               | Current energy                      |
| `known_technique_keys`   | `Array[StringName]` | All known techniques                |
| `equipped_technique_keys`| `Array[StringName]` | Active techniques (max 4)           |
| `active_ability_slot`    | `int`               | Which slot is active (1, 2, or 3)   |
| `equipped_gear_key`      | `StringName`        | Equipable gear                      |
| `equipped_consumable_key`| `StringName`        | Consumable gear                     |
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

Each Digimon has individual resistance values per element (stored in `DigimonData.resistances`). Digimon do **NOT** have an elemental type — only attributes (Vaccine/Virus/Data) and per-element resistances. There is no STAB equivalent. This may be revisited later.

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

### Damage Formula

```
damage = power * (atk_stat / def_stat) * attribute_mult * element_mult * personality * variance
```

Where:
- `power` = technique base power
- `atk_stat / def_stat` = ATK/DEF for Physical, SPATK/SPDEF for Special
- `attribute_mult` = from attribute triangle (0.5, 1.0, or 1.5)
- `element_mult` = target's resistance to technique's element
- `personality` = personality modifier applied to relevant stat
- `variance` = random factor between 0.85 and 1.0

**Note**: Digimon don't have elemental types, only attributes and resistances. No STAB. May be revisited.

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
| `accuracy`             | `int`                     | Hit chance (100 = always hits)   |
| `energy_cost`          | `int`                     | Energy to use                    |
| `priority`             | `Registry.Priority`       | Priority tier                    |
| `tags`                 | `Array[TechniqueTag]`     | Sound, Wind, Contact, etc.       |
| `charge_required`      | `int`                     | Charges needed (0 = instant)     |
| `charge_conditions`    | `Array[Dictionary]`       | How charges are gained           |
| `bricks`               | `Array[Dictionary]`       | Modular effect definitions       |

### Brick Types (28)

The brick system enables modular effect composition. Each brick is a dictionary with a `brick` type field:

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
| `requirement`        | Move fails if condition not met                  |
| `conditional`        | Bonus effects under certain conditions           |
| `protection`         | Protects from attacks (Protect-like)             |
| `priorityOverride`   | Changes move priority conditionally              |
| `typeModifier`       | Changes types/elements                           |
| `flags`              | Move flags for ability interactions              |
| `criticalHit`        | Modifies critical hit rate                       |
| `resource`           | Interacts with held items                        |
| `useRandomMove`      | Uses a random technique                          |
| `transform`          | Transforms into target                           |
| `shield`             | Creates protective shields (Substitute-like)     |
| `copyMove`           | Copies or mimics techniques                      |
| `abilityManipulation`| Copies, swaps, or suppresses abilities           |
| `turnOrder`          | Manipulates turn order                           |

### Technique Tags

Tags are metadata on techniques that interact with abilities and status effects:

| Tag       | Description                                      |
|-----------|--------------------------------------------------|
| Sound     | Sound-based — may bypass substitutes             |
| Wind      | Wind-based — interacts with airborne states      |
| Explosive | Explosion — may hit semi-invulnerable targets    |
| Contact   | Makes physical contact — triggers contact abilities |
| Punch     | Punch-based — boosted by fist-related abilities  |
| Kick      | Kick-based                                       |
| Bite      | Bite-based — boosted by jaw-related abilities    |
| Beam      | Beam-based                                       |

### Targeting

| Value              | Description                              |
|--------------------|------------------------------------------|
| Self               | Targets the user only                    |
| Single Target      | One target (ally or foe)                 |
| Single Other       | One target that isn't the user           |
| Single Side        | One side of the field                    |
| Single Side or Ally| One side or a specific ally              |
| All                | All Digimon on the field                 |
| All Other          | All Digimon except the user              |

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
| `trigger_condition`    | `Dictionary`              | Optional condition details       |
| `bricks`               | `Array[Dictionary]`       | Effect definitions (same system) |

### Trigger Events

| Trigger            | When it fires                              |
|--------------------|--------------------------------------------|
| `ON_ENTRY`         | When Digimon enters the field              |
| `ON_EXIT`          | When Digimon leaves the field              |
| `ON_TURN_START`    | At the start of the Digimon's turn         |
| `ON_TURN_END`      | At the end of the Digimon's turn           |
| `ON_BEFORE_ATTACK` | Before the Digimon uses a technique        |
| `ON_AFTER_ATTACK`  | After the Digimon uses a technique         |
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

Some thematic overrides still apply:
- **Burned** removes Frostbitten and Frozen
- **Frostbitten** removes Burned
- Applying **Frostbitten** to an already Frostbitten Digimon upgrades to **Frozen**

### Full Status Table

| Status       | Category | Mechanics                                              |
|--------------|----------|--------------------------------------------------------|
| Asleep       | Negative | Cannot act. Wakes after 1-3 turns or when hit.        |
| Burned       | Negative | Fire DoT. Physical ATK reduced.                       |
| Frostbitten  | Negative | Ice DoT. Special ATK reduced.                         |
| Frozen       | Negative | Cannot act. Thaws after 1-3 turns or fire hit.        |
| Exhausted    | Negative | SPD halved. Energy regen halved.                      |
| Poisoned     | Negative | DoT (escalating or fixed).                            |
| Dazed        | Negative | Accuracy reduced. May fail to act.                    |
| Trapped      | Negative | Cannot switch out.                                    |
| Confused     | Negative | May hit self instead of target.                       |
| Blinded      | Negative | Accuracy significantly reduced.                       |
| Paralysed    | Negative | SPD reduced. May fail to act.                         |
| Bleeding     | Negative | DoT. Damage increases with physical actions.          |
| Regenerating | Positive | Restores HP each turn.                                |
| Vitalised    | Positive | Immune to negative status conditions.                 |
| Nullified    | Neutral  | Ability is suppressed.                                |
| Reversed     | Neutral  | Stat changes are inverted.                            |

### Element-Based Immunities

*Note: Since Digimon don't have elemental types, these immunities will be implemented through specific abilities or resistance thresholds rather than innate type immunity.*

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
- Affect the entire field (both sides)
- Examples: speed reversal (trick room), gravity (prevents airborne), etc.

---

## 12. Item System

### Categories (8)

| Category     | Combat Use | Description                                          |
|--------------|------------|------------------------------------------------------|
| General      | No         | Non-combat items, sellables, world interaction       |
| Capture/Scan | No         | Scanning equipment for data collection               |
| Medicine     | Yes        | HP/status healing, combat usable                     |
| Performance  | No         | IV/TV/level/evolution manipulation                   |
| Gear         | Passive    | Equipable + consumable, one each per Digimon         |
| Key          | No         | Story progression, passive effects                   |
| Quest        | No         | Location-specific quest items                        |
| Card         | No         | Teach techniques to specific Digimon                 |

### Gear System

Each Digimon has two gear slots:
- **Equipable** (`GearSlot.EQUIPABLE`): Persistent passive effect
- **Consumable** (`GearSlot.CONSUMABLE`): Single-use triggered effect

Gear effects are defined via bricks (same system as techniques and abilities).

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

**Enums**: Attribute, Element, Stat, EvolutionLevel, TechniqueClass, Targeting, Priority, BrickType, TechniqueTag, AbilityTrigger, StackLimit, StatusCondition, StatusCategory, EvolutionType, ItemCategory, GearSlot

**Constants**:
- `STAT_STAGE_MULTIPLIERS`: Dictionary mapping stage (-6 to +6) to multiplier
- `PRIORITY_SPEED_MULTIPLIERS`: Dictionary mapping priority tier to speed multiplier

Each enum has a corresponding `_labels` dictionary using `tr()` for localisation.

### Atlas (`autoload/atlas.gd`)

Data resource loader with typed dictionaries:
- `digimon`, `techniques`, `abilities`, `evolutions`, `elements`, `items`, `status_effects`, `personalities`
- Loads all `.tres` files from `data/` folders on `_ready()`
- Resources keyed by their `key` field

### Game (`autoload/game.gd`)

Game lifecycle manager:
- `state: GameState` — current game state (null if no game)
- `new_game()` — creates fresh GameState
- `load_game(slot)` — loads from save file
- `save_game(slot)` — saves current state
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
├── party: PartyState
│   └── members: Array[DigimonState]
├── storage: Array[DigimonState]
├── inventory: InventoryState
│   ├── items: Dictionary[StringName, int]
│   └── money: int
├── story_flags: Dictionary
└── scan_log: Dictionary[StringName, float]
```

### Serialisation Strategy: Source Data Only

**Principle**: Only save data that cannot be derived. Recalculate derived values on load.

**Saved**: key, nickname, level, XP, personality_key, IVs, TVs, known techniques, equipped techniques, active ability slot, gear keys, scan data

**Recalculated on load**: All stat values (from stat formula), display names (from Atlas)

### SaveManager

```gdscript
SaveManager.save_game(state, "slot1")        # JSON (dev)
SaveManager.save_game(state, "slot1", true)   # Binary (production)
SaveManager.load_game("slot1")                # Auto-detects format
SaveManager.save_exists("slot1")
SaveManager.delete_save("slot1")
SaveManager.get_save_slots()
```

Save files stored in `user://saves/` with `.json` (dev) or `.sav` (binary) extension.

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

## Important Technical Notes

- **Godot Version**: 4.6 (GDScript only, no C#)
- **No 3D**: This is a pure 2D project
- **British English**: All code, comments, and docs
- **Tabs**: GDScript uses tabs (not spaces)
- **Key references**: StringName keys between resources, never direct resource paths
- **Atlas lookup**: `Atlas.digimon[key]`, `Atlas.techniques[key]`, etc.
- **Registry access**: `Registry.Attribute.VACCINE`, `Registry.STAT_STAGE_MULTIPLIERS[-3]`
- **Combat Roles**: Exist only in digimon-dex for base stat generation. NOT needed in this game — only the resulting base stats matter.

---

*Last Updated: 2026-02-08*

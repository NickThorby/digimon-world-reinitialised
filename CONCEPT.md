# Digimon World: Reinitialised — Game Concept

> **Vision Document**: The design philosophy and gameplay systems for this Digimon RPG.

---

## Premise

A fan game inspired by **Digimon World 3**, reimagined with Pokemon-style battles and a modern data-driven architecture. Players explore a 2D overworld, build a team of Digimon through battling and evolution, and progress through a story-driven adventure across themed regions.

The game features 1,375 Digimon sourced from the [digimon-dex](../digimon-dex) sister project, each with unique base stats, element resistances, ability slots, and technique pools.

---

## Gameplay Overview

The game at its heart is a **2D top-down RPG** with a focus on building and evolving your Digimon team.

**Core Loop**:
1. Explore the overworld and encounter wild Digimon
2. Battle using a deep technique, ability, and element system
3. Scan and recruit new Digimon to your team
4. Evolve Digimon through branching evolution paths
5. Progress through story areas with increasing challenge
6. Manage your party composition and equipment

**Two Gameplay Modes**:
- **Overworld**: 2D top-down exploration, NPC interaction, wild encounters
- **Battle**: Pokemon-style turn-based combat (single data-driven battle scene)

---

## Battle System

### Attribute Triangle

Every Digimon has an **attribute** that determines type advantage in combat:

```
Vaccine > Virus > Data > Vaccine
```

- **Advantage**: 1.5x damage multiplier
- **Disadvantage**: 0.5x damage multiplier
- **Neutral/Special attributes** (Free, Variable, None, Unknown): 1.0x

### Elements (11)

Elements determine technique damage and interact with per-Digimon resistances:

**Null, Fire, Water, Air, Earth, Ice, Lightning, Plant, Metal, Dark, Light**

Each Digimon has individual resistance values per element:
- **0.0** — Immune
- **0.5** — Resistant
- **1.0** — Neutral
- **1.5** — Weak
- **2.0** — Very Weak

**Key Design Note**: Digimon have **attributes** (Vaccine/Virus/Data) and individual **element resistances**, but they do NOT have an elemental "type". There is no STAB (Same-Type Attack Bonus) equivalent. This may be revisited later.

### Technique Classification

Techniques (what digimon-dex calls "attacks") fall into three classes:

| Class      | Description                        | Stats Used         |
|------------|------------------------------------|--------------------|
| Physical   | Contact-based damage               | ATK vs DEF         |
| Special    | Ranged/energy-based damage         | SPATK vs SPDEF     |
| Status     | No damage — applies effects only   | N/A                |

### Stat Stages

Stats can be raised or lowered in battle through techniques and abilities:

| Stage | Multiplier | Stage | Multiplier |
|-------|------------|-------|------------|
| -6    | 25%        | +1    | 150%       |
| -5    | 29%        | +2    | 200%       |
| -4    | 33%        | +3    | 250%       |
| -3    | 40%        | +4    | 300%       |
| -2    | 50%        | +5    | 350%       |
| -1    | 67%        | +6    | 400%       |
| 0     | 100%       |       |            |

Stat stages affect: ATK, DEF, SPATK, SPDEF, SPD.

### Priority System

Techniques have a priority tier that determines turn order before speed is considered:

| Tier      | Speed Multiplier | Description                          |
|-----------|------------------|--------------------------------------|
| Maximum   | Moves first      | Always goes first (e.g., Protect)    |
| Instant   | Moves first      | Near-guaranteed first action         |
| Very High | 2.0x             | Significantly faster                 |
| High      | 1.5x             | Faster than normal                   |
| Normal    | 1.0x             | Standard speed calculation           |
| Low       | 0.5x             | Slower than normal                   |
| Very Low  | 0.25x            | Significantly slower                 |
| Negative  | Moves last        | Near-guaranteed last action          |
| Minimum   | Moves last        | Always goes last                     |

**Dynamic** priority (not in the enum) allows techniques to calculate priority at runtime based on conditions.

### Energy System

Every technique costs energy to use:

- **Energy Cost**: Each technique has a fixed energy cost
- **Overexertion**: Using a technique when energy is insufficient deals recoil damage to the user
- **Regeneration**:
  - 5% of max energy regenerated per turn
  - 25% of max energy regenerated when resting (skipping a turn)
  - 100% energy restored after battle ends

### Charge Mechanics

Some powerful techniques require charges before they can be used:

- **Charge Required**: Number of charges needed (0 = no charge needed)
- **Charge Conditions**: How charges are gained (turns passed, taking damage, being hit by specific element types)
- **Persistence**: Charges persist through Digimon switches
- **Reset**: Charges reset when the technique is used or when the battle ends

### Technique Tags

Techniques can have tags that interact with abilities and status effects:

**Sound, Wind, Explosive, Contact, Punch, Kick, Bite, Beam**

For example, a Sound-tagged technique might bypass certain shields, or a Contact-tagged technique might trigger a thorns-like ability.

---

## Stat System

### Seven Stats

| Stat           | Key              | Purpose                    |
|----------------|------------------|----------------------------|
| HP             | `hp`             | Hit points                 |
| Energy         | `energy`         | Technique cost resource    |
| Attack         | `attack`         | Physical damage            |
| Defence        | `defence`        | Physical damage reduction  |
| Special Attack | `special_attack` | Special damage             |
| Special Defence| `special_defence`| Special damage reduction   |
| Speed          | `speed`          | Turn order determination   |

### Stat Formula

```
FLOOR((((2 * BASE + IV + (TV / 5)) * LEVEL) / 100)) + LEVEL + 10
```

- **BASE**: From the DigimonData template (determined by dex)
- **IV**: Individual Value (0-50, random at creation, permanent)
- **TV**: Training Value (0-500, earned through training)
- **LEVEL**: Current Digimon level

HP and Energy may receive unique formulae in future if balance requires it.

### Individual Values (IVs)

- Random 0-50 per stat, rolled when a Digimon is created
- Permanent — cannot be changed (except by special performance items)
- Represent innate potential

### Training Values (TVs)

- Range 0-500 per stat
- Earned through battling, training, and special items
- Represent earned growth

---

## Personality System

Each Digimon has a personality that provides +10%/-10% stat modifiers:

- **Boosted stat**: Receives +10% bonus
- **Reduced stat**: Receives -10% penalty
- When boosted and reduced are the **same stat**, the personality is effectively neutral

---

## Status Conditions

There is **no stacking limit** — multiple different status conditions can be active simultaneously. Status stacking is a valid strategy.

### Negative Status Conditions

| Status      | Effect                                                          |
|-------------|-----------------------------------------------------------------|
| Asleep      | Cannot act. Wakes after 1-3 turns or when hit.                 |
| Burned      | Takes fire damage each turn. Physical attack reduced.           |
| Frostbitten | Takes ice damage each turn. Special attack reduced.             |
| Frozen      | Cannot act. Thaws after 1-3 turns or when hit by fire.          |
| Exhausted   | Speed halved. Energy regeneration halved.                       |
| Poisoned    | Takes damage each turn (escalating or fixed).                   |
| Dazed       | Accuracy reduced. May fail to act.                              |
| Trapped     | Cannot switch out.                                              |
| Confused    | May hit self instead of target.                                 |
| Blinded     | Accuracy significantly reduced.                                 |
| Paralysed   | Speed reduced. May fail to act.                                 |
| Bleeding    | Takes damage each turn. Damage increases with physical actions. |

### Positive Status Conditions

| Status       | Effect                                    |
|--------------|-------------------------------------------|
| Regenerating | Restores HP each turn.                    |
| Vitalised    | Immune to negative status conditions.     |

### Neutral Status Conditions

| Status    | Effect                                             |
|-----------|----------------------------------------------------|
| Nullified | Ability is suppressed.                             |
| Reversed  | Stat changes are inverted (boosts become drops).   |

### Override Rules

Some status conditions override others thematically:
- **Burned** removes Frostbitten and Frozen
- **Frostbitten** removes Burned
- Applying **Frostbitten** to an already Frostbitten Digimon upgrades it to **Frozen**

### Element Immunities

- Fire-element Digimon are immune to Burned
- Ice-element Digimon are immune to Frostbitten and Frozen
- Miasma/Metal-element Digimon are immune to Poisoned

*Note: "Element immunities" here refers to future consideration — since Digimon don't currently have elemental types, this will be tied to specific abilities or resistances instead.*

---

## Field Mechanics

### Weather

- **One active at a time** — setting a new weather replaces the current one
- Set by techniques (and potentially abilities)
- Affects damage multipliers, accuracy, energy costs, etc.

### Terrain

- **One active at a time** — setting a new terrain replaces the current one
- Affects grounded Digimon with various effects
- Set by techniques

### Hazards

- **Stackable** — multiple hazards can exist on each side of the field
- Entry hazards trigger when a Digimon switches in
- Examples: spikes, toxic spikes, stealth rocks equivalent

### Field Effects

- **Stackable** — multiple global effects can be active simultaneously
- Affect the entire field (both sides)
- Examples: gravity, trick room equivalent

---

## Evolution System

### Evolution Levels (10)

| Level | Name            | Tier     |
|-------|-----------------|----------|
| 1     | Baby I          | Fresh    |
| 2     | Baby II         | In-Training |
| 3     | Child           | Rookie   |
| 4     | Adult           | Champion |
| 5     | Perfect         | Ultimate |
| 6     | Ultimate        | Mega     |
| 7     | Super Ultimate  | Ultra    |
| 8     | Armor           | Armor    |
| 9     | Hybrid          | Hybrid   |
| 10    | Unknown         | Unknown  |

### Evolution Types (7)

| Type        | Description                                    |
|-------------|------------------------------------------------|
| Standard    | Normal evolution path                          |
| Spirit      | Spirit-based transformation                    |
| Armor       | Digi-Egg armour evolution                      |
| Slide       | Horizontal evolution (same level)              |
| X-Antibody  | X-Antibody enhanced form                       |
| Jogress     | Fusion of two or more Digimon                  |
| Mode Change | Alternate form (same Digimon)                  |

### Evolution Requirements

Each evolution path has requirements that must **ALL** be met (AND logic):
- Level threshold
- Stat requirements (specific stat must reach a value)
- Stat comparison (e.g., ATK must be highest stat)
- Special items (spirits, digimentals, X-antibody)
- Jogress partner (specific Digimon must be in party)

### Branching Paths

Digimon can evolve into multiple different forms depending on which requirements are met. A single Child-level Digimon might have 5+ possible Adult evolutions, each with different requirements.

---

## Ability System

Every Digimon has **three ability slots**:
- **Slot 1**: Standard ability
- **Slot 2**: Standard ability (alternate)
- **Slot 3**: Secret/hidden ability

Only **one ability is active** at a time (stored as `active_ability_slot` on DigimonState).

### Ability Triggers

Abilities activate on specific events: entry, exit, turn start/end, before/after attacking, before/after being hit, dealing/taking damage, fainting, status applied, stat change, weather/terrain change, HP threshold, or continuously.

### Ability Effects

Abilities use the same **brick system** as techniques — modular effect definitions that can compose complex behaviours. Combined with trigger conditions and stack limits, this allows for a wide variety of passive effects.

---

## Item System

### Item Categories (8)

| Category     | Description                                          | Combat Use |
|--------------|------------------------------------------------------|------------|
| General      | Sellables, world interaction items                   | No         |
| Capture/Scan | Data scanning equipment                              | No         |
| Medicine     | HP/status healing                                    | Yes        |
| Performance  | IV/TV/level/evolution manipulation                   | No         |
| Gear         | Equipable and consumable gear with brick effects     | Passive    |
| Key          | Story progression, passive effects                   | No         |
| Quest        | Location-specific quest items                        | No         |
| Card         | Teach techniques to specific Digimon                 | No         |

### Gear System

Each Digimon can equip **one equipable** and **one consumable** gear item:
- **Equipable**: Persistent passive effects (defined via bricks)
- **Consumable**: Single-use in combat (triggered by conditions or manually)

### Scan Mechanic

Instead of catching Digimon in capsules, players **scan** wild Digimon during battle:
- Scanning accumulates a data percentage (0-100%)
- At high enough percentage, the Digimon can be recreated at a terminal
- Replaces the traditional "capture" mechanic with a data-collection theme

---

## Data-Driven Philosophy

The game is heavily data-driven:
- **1,375 Digimon** with full stat lines, resistances, technique pools, and ability slots
- **Brick system** for modular effect composition (techniques, abilities, and gear all use bricks)
- **Translation-ready** with three-tier naming (jp_name, dub_name, custom_name) and CSV i18n
- **Sister project** (digimon-dex) provides the authoritative data source via an ingestion pipeline

---

## World Design

The overworld consists of themed areas inspired by Digimon World 3's regions:
- Towns with NPCs, shops, and services
- Wild areas with encounters based on area level and element themes
- Dungeons with puzzles and boss encounters
- Terminals for recreating scanned Digimon

---

*This is a living document and will evolve as the game develops.*

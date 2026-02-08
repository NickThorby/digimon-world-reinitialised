# Digimon World: Reinitialised

> A 2D top-down Digimon RPG with Pokemon-style battles, built in Godot 4.6.

Inspired by Digimon World 3, reimagined with a modern data-driven architecture. Explore an overworld, battle Digimon using a deep technique and ability system, evolve your team through branching paths, and progress through a story-driven adventure.

---

## Project Structure

```plaintext
res://
├── addons/
│   └── dex_importer/               # Future: editor plugin for digimon-dex ingestion
├── assets/
│   ├── sprites/
│   │   ├── digimon/                # Battle sprites keyed by game_id
│   │   ├── characters/             # Player/NPC overworld sprites
│   │   ├── effects/                # Battle effect sprites
│   │   └── ui/                     # UI sprites and icons
│   ├── tilesets/                   # TileMapLayer tilesets
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/
├── autoload/                       # Autoloaded singletons
├── data/
│   ├── config/                     # Game balance, tunable settings
│   ├── digimon/                    # DigimonData .tres resources
│   ├── technique/                  # TechniqueData .tres resources
│   ├── ability/                    # AbilityData .tres resources
│   ├── evolution/                  # EvolutionLinkData .tres resources
│   ├── element/                    # ElementData definitions
│   ├── item/                       # Item definitions
│   │   ├── gear/                   # Equipable/consumable gear
│   │   ├── medicine/               # Combat medicine
│   │   ├── performance/            # IV/TV/evolution items
│   │   ├── card/                   # Technique teaching cards
│   │   └── general/                # Sellables, key items, etc.
│   ├── status_effect/              # Status effect definitions
│   ├── personality/                # Personality definitions
│   └── locale/                     # Translation CSV files
├── entities/
│   ├── digimon/                    # Digimon entity scenes
│   ├── player/                     # Player character
│   └── npc/                        # NPCs
├── scenes/
│   ├── main/                       # Entry point + main menu
│   ├── battle/                     # Battle scene (single, data-driven)
│   ├── overworld/                  # Overworld exploration scenes
│   └── common/                     # Shared prefabs
│       └── prefabs/
├── scripts/
│   ├── systems/
│   │   ├── battle/                 # Battle engine
│   │   ├── digimon/                # Digimon state management
│   │   ├── evolution/              # Evolution system
│   │   ├── party/                  # Party management
│   │   ├── inventory/              # Item/inventory management
│   │   ├── game/                   # Save/load, game state
│   │   └── brick/                  # Brick effect resolution
│   ├── ai/                         # Battle AI
│   └── utilities/                  # Helpers, constants
├── ui/
│   ├── components/                 # Reusable widgets
│   ├── menus/                      # Menu screens
│   ├── battle_hud/                 # Battle UI overlay
│   ├── dialogue/                   # Dialogue UI
│   └── themes/                     # Godot Theme resources
└── tests/                          # Debug/test scenes
```

---

## GDScript Style Guide Summary (Godot 4.6)

This project follows the [official GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) with project-specific additions.

### Formatting

- **Indentation**: Use tabs (width 4).
- **Line Length**: Limit to 100 characters per line.
- **Blank Lines**: Separate functions and logical blocks with blank lines.

### Language

This project uses **British English** for all code, comments, documentation, and naming (e.g., `colour`, `defence`, `armour`, `behaviour`, `serialisation`).

### Naming Conventions

| Element       | Style          | Example                    |
|---------------|----------------|----------------------------|
| Classes       | `PascalCase`   | `DigimonFactory`           |
| Variables     | `snake_case`   | `current_hp`               |
| Functions     | `snake_case`   | `calculate_damage()`       |
| Constants     | `UPPER_SNAKE`  | `MAX_PARTY_SIZE`           |
| Signals       | `snake_case`   | `hp_changed`               |
| Files/Folders | `snake_case`   | `digimon_data.tres`        |
| Enums         | `PascalCase`   | `TechniqueClass`           |
| Enum Values   | `UPPER_SNAKE`  | `SPECIAL_ATTACK`           |

### Class Suffix Conventions

| Suffix        | Purpose                                      | Example              |
|---------------|----------------------------------------------|----------------------|
| `*Data`       | Immutable resource templates (.tres files)   | `DigimonData`        |
| `*State`      | Mutable runtime instances                    | `DigimonState`       |
| `*Result`     | Action/calculation outcomes (readonly)       | `DamageResult`       |
| `*Calculator` | Pure functions, no side effects              | `StatCalculator`     |
| `*Manager`    | Operations with side effects                 | `SaveManager`        |
| `*Factory`    | Creates and initialises new instances        | `DigimonFactory`     |

### Serialisation Strategy

**Source Data Only**: Save only data that cannot be derived. Recalculate derived values on load.

- **Saved**: Key, nickname, level, XP, personality, IVs, TVs, known techniques, equipped techniques, ability slot, gear
- **Recalculated**: All stat values (from formulas), display names (from Atlas lookup)

### Code Order

1. `class_name` and `extends`
2. `signal` declarations
3. `enum` definitions
4. `const` declarations
5. `@export var` declarations
6. Member variables
7. `_init()` constructor
8. Built-in callbacks (`_ready()`, `_process()`)
9. Public methods
10. Private methods (prefixed with `_`)

### Static Typing

Use static typing everywhere to improve clarity and catch errors early.

```gdscript
var current_hp: int = 100

func take_damage(amount: int) -> void:
    current_hp -= amount
```

### Comments and Documentation

Use `##` doc comments for public functions and classes. Use `#` for inline clarifications.

```gdscript
## Calculates the damage dealt based on the technique's power.
func calculate_damage(power: int, multiplier: float) -> int:
    return floori(power * multiplier)
```

### Signal-Based Decoupling

Use signals to decouple systems. Prefer signals over direct method calls between unrelated systems.

```gdscript
signal hp_changed(new_hp: int)

func apply_damage(amount: int) -> void:
    current_hp -= amount
    hp_changed.emit(current_hp)
```

---

## Sister Project

This game sources its data from [digimon-dex](../digimon-dex), a companion database application containing all 1,375 Digimon, their techniques (called "attacks" in the dex), abilities, evolutions, and element data. A future ingestion pipeline will convert dex API data into `.tres` resources and translation CSVs.

**Key terminology mapping**: What digimon-dex calls "attacks" are called **"techniques"** in this game.

---

*See `CONCEPT.md` for game design vision and `CONTEXT.md` for technical architecture.*

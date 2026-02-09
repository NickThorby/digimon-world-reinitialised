# CLAUDE.md — AI Development Instructions

## Quick Start

1. Read `README.md` for project structure and style guide
2. Read `CONTEXT.md` for technical architecture
3. Read `CONCEPT.md` for game design vision

## Project Info

- **Engine**: Godot 4.6 (GDScript, NOT Godot 5)
- **Type**: 2D top-down Digimon RPG with Pokemon-style battles
- **Sister project**: `../digimon-dex` — the authoritative data source for Digimon, techniques, abilities, and evolutions

## Key Terminology

- **"Techniques"** (not "Attacks") — what Digimon use in battle. The digimon-dex calls these "attacks" in its database, but in this game they are always "techniques". The field mapping is: dex `Attack` -> game `TechniqueData`, dex `attack_class` -> game `technique_class`.
- **"Technique Flags"** (not "Technique Tags") — `TechniqueFlag` enum replaced the old `TechniqueTag`. `TechniqueData.flags` (not `.tags`).

## Key Conventions

- **British English** everywhere: `defence`, `colour`, `armour`, `behaviour`, `serialisation`, `initialise`, `organisation`, `analyse`, `recognise`, `paralysed`
- **Static typing** on all variables, parameters, and return types
- **Resource vs State** pattern: `*Data` (immutable .tres) vs `*State` (mutable runtime)
- **Class suffixes**: `*Data`, `*State`, `*Result`, `*Calculator`, `*Manager`, `*Factory`
- **Key-based references** between resources (StringName keys, not resource paths)
- **Tabs** for GDScript indentation, **spaces** for markdown/tres/tscn

## Code Style

- Tabs for indentation (width 4)
- 100-character line limit
- Code order: class_name > extends > signals > enums > consts > @exports > vars > _init > _ready > public > _private
- Doc comments with `##` for public API, `#` for inline clarifications

## Architecture Rules

- **Data resources** live in `data/` — immutable templates loaded from .tres files
- **State classes** live in `scripts/systems/` — mutable runtime instances
- **Atlas** is the data loader — look up data via `Atlas.digimon[key]`, `Atlas.techniques[key]`, etc.
- **Registry** holds all enums and constants — access via `Registry.Attribute.VACCINE`, `Registry.STAT_STAGE_MULTIPLIERS`, etc.
- **tr()** for all user-facing text (translation-ready)
- **Serialisation**: save source data only (IVs, TVs, level, personality, known techniques); recalculate derived stats on load

## Testing

- **Framework**: GUT (Godot Unit Test) in `addons/gut/`
- **Test location**: `tests/unit/` for unit tests, `tests/integration/` for integration tests
- **Test data**: Synthetic data in `tests/helpers/test_battle_factory.gd` — never use imported dex data for tests
- **Running tests**: `godot --headless -s addons/gut/gut_cmdln.gd`
- **Naming**: Files prefixed with `test_`, functions prefixed with `test_`

## When to Write Tests

- **New battle engine features**: Any new brick type, status condition, ability trigger, or battle mechanic MUST have tests
- **Bug fixes**: Regression test for the specific bug (prove it's fixed)
- **New calculators/utilities**: Unit tests for pure functions (StatCalculator, DamageCalculator, etc.)
- **Test data**: If a new feature needs test data not yet in `TestBattleFactory`, add it there with `test_` prefix

## Common Patterns

### Creating a Data Resource
```gdscript
class_name MyThingData
extends Resource

@export var key: StringName = &""
@export var name: String = ""
```

### Creating a State Class
```gdscript
class_name MyThingState
extends RefCounted

var key: StringName = &""
var value: int = 0

func to_dict() -> Dictionary:
    return {"key": key, "value": value}

static func from_dict(data: Dictionary) -> MyThingState:
    var state := MyThingState.new()
    state.key = StringName(data.get("key", ""))
    state.value = data.get("value", 0)
    return state
```

## Do NOT

- Use American English (defense, color, armor, behavior, serialization)
- Use relative resource paths between resources (use StringName keys instead)
- Store derived/calculated data in save files (recalculate on load)
- Skip static typing on variables, parameters, or return types
- Say "attacks" when you mean "techniques" (except when referencing digimon-dex field names)
- Use 3D nodes or physics (this is a 2D game)
- Use spaces for GDScript indentation (use tabs)
- Merge battle engine changes without corresponding tests
- Use imported game data (from `data/`) in tests — use `TestBattleFactory` test data instead
- Write tests that depend on specific RNG output without documenting the seed

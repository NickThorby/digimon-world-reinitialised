# Plan: Dex Importer — Export Endpoint Spec + EditorPlugin

## Context

The game sources all Digimon, technique, ability, and evolution data from the sister project `digimon-dex`. Data is ephemeral — the dex is always the source of truth, edits happen there, and the importer updates the game side. Currently the dex runs locally on Docker with dirty data. When it goes live, the plugin will need to support different sources (live API or dump file).

**Decision**: Build a single `/export/game` endpoint on the dex (user implements) and a Godot EditorPlugin with a dock panel UI to consume it.

**Current dex data state**: 1,375 Digimon with stats/resistances, ~2,302 attacks (bricks all empty), abilities schema exists but NO data seeded, ~1,931 evolution links, locations schema exists but NO data seeded.

---

## Part 1: Export Endpoint Spec

The user will implement this endpoint in `digimon-dex`. This section is the contract.

### `GET /export/game`

Returns the entire game-relevant dataset in a single response. No pagination — this is a bulk export.

### Response Shape

```jsonc
{
  "version": 1,
  "exported_at": "2026-02-08T12:00:00.000Z",

  "lookups": {
    "elements": [
      { "name": "Null" },
      { "name": "Fire" }
      // ... all 11
    ],
    "attributes": [
      { "name": "None" },
      { "name": "Vaccine" }
      // ... all 7
    ],
    "evolution_types": [
      { "name": "Standard" }
      // ... all 7
    ]
  },

  "techniques": [
    {
      "game_id": "pepper_breath",
      "jp_name": "Baby Flame",           // romanised Japanese name
      "dub_name": "Pepper Breath",       // English dub name, nullable
      "name": null,                       // optional override
      "description": null,
      "mechanic_description": null,
      "class": "Physical",               // AttackClass enum value
      "priority": 0,                     // int, -4 to 4
      "targeting": "SingleFoe",          // Targeting enum value
      "energy_cost": 10,
      "accuracy": 95,                    // nullable (null = always hits)
      "element": "Fire",                 // element name, nullable
      "bricks": []                       // raw JSON array
    }
  ],

  "abilities": [
    {
      "game_id": "blaze",
      "name": "Blaze",
      "description": null,
      "mechanic_description": null,
      "trigger": "onHpThreshold",        // AbilityTrigger enum value
      "stack_limit": "oncePerBattle",    // StackLimit enum value
      "trigger_condition": null,          // nullable JSON object
      "bricks": []
    }
  ],

  "digimon": [
    {
      "game_id": "yukidarumon",
      "jp_name": "Yukidarumon",          // romanised Japanese name
      "dub_name": "Frigimon",            // English dub name
      "name": null,                       // optional custom name override
      "type": "Icy",                      // type tag, nullable
      "level": 4,                         // evolution level 1-10, nullable
      "attribute": "Vaccine",             // attribute name, nullable
      "bst": 350,
      "hp": 60,
      "energy": 40,
      "attack": 55,
      "defence": 65,
      "special_attack": 50,
      "special_defence": 55,
      "speed": 40,
      "resistances": {                    // element name -> float multiplier
        "Null": 1.0,
        "Fire": 0.5,
        "Water": 1.5
        // ... all 11 elements
      },
      "techniques": [
        {
          "game_id": "ice_blast",
          "requirements": [{ "type": "innate" }]
        },
        {
          "game_id": "sub_zero_ice_punch",
          "requirements": [{ "type": "level", "value": 15 }]
        }
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
      "evolution_type": "Standard",        // nullable
      "requirements": [
        { "type": "level", "value": 11 }
      ],
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
                "digimon": [
                  { "game_id": "yukidarumon", "rarity": "common" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
```

### Field Notes

- **`jp_name`**: Romanised Japanese name (e.g., "Yukidarumon", "Baby Flame"), NOT Japanese characters. Both `jp_name` and `dub_name` are English text — `jp_name` is the Japanese-origin romanised name, `dub_name` is the English dub localisation. Some are identical (e.g., "Agumon"/"Agumon"), others differ (e.g., "Yukidarumon"/"Frigimon"). The game's `display_name` property resolves: `custom_name > dub_name > jp_name`.
- **`name`** (on Digimon/techniques): Optional override name. Maps to game's `custom_name`. Null for most entries.
- **`accuracy: null`**: Means always-hits (no accuracy check). Game maps to `accuracy = 0`.
- **`priority`**: Integer from -4 to 4 (0 = normal). Game maps to Priority enum.
- **`bricks`**: Raw JSON array from dex. Currently empty for all entries. Will contain modular effect data when populated.
- **`requirements`** on techniques: From `DigimonAttack` junction. Array with OR logic. Entries with `{ "type": "innate" }` are signature/innate techniques.
- **`requirements`** on evolutions: From `DigimonEvolution`. Array with AND logic. All conditions must be met.

### Implementation Notes for Dex Side

- Denormalise all FK relations to name strings (not UUIDs)
- Resistances: flatten the 11 `resist*` columns into a `{ elementName: float }` dictionary
- Techniques on Digimon: include `requirements` from `DigimonAttack` junction (needed to determine innate vs learnable)
- Abilities on Digimon: include `slot` from `DigimonAbility` junction
- Evolutions: resolve `fromDigimon.gameId`, `toDigimon.gameId`, `evolutionType.name`, and `jogressPartners[].partnerDigimon.gameId`
- Locations: nest as `regions > sectors > zones > digimon` (skip entirely if no data)
- Exclude: UUIDs, timestamps, user data, role/roleWeight, hasSprite, isCustom, profile, wikimon data

---

## Part 1b: Export Contract Document

A standalone `addons/dex_importer/EXPORT_CONTRACT.md` will be generated as the **source of truth** for the dex-side implementation. It will contain:

- Full endpoint specification (`GET /export/game`)
- Complete JSON schema with every field, type, and nullability documented
- Field notes (jp_name semantics, accuracy=null, priority int range, etc.)
- All enum value lists the dex must use (matching dex-side naming)
- Resistance field mapping (which `resist*` columns map to which element names)
- Junction table denormalisation rules (DigimonAttack, DigimonAbility, JogressPartner)
- Exclusion list (fields the export must NOT include)
- Example complete response

This document lives in the game repo but serves the dex. The user takes it to `digimon-dex` to implement the endpoint.

---

## Part 2: Game-Side Prerequisite Changes

### 2a. Expand Targeting Enum

The dex has more granular targeting than the current game enum. Expand to match.

**File**: `autoload/registry.gd`

```gdscript
enum Targeting {
    SELF,
    SINGLE_TARGET,
    SINGLE_OTHER,
    SINGLE_ALLY,          # NEW
    SINGLE_FOE,           # NEW
    ALL_ALLIES,           # NEW
    ALL_OTHER_ALLIES,     # NEW
    ALL_FOES,             # NEW
    SINGLE_SIDE,
    ALL,
    ALL_OTHER,
    FIELD,                # NEW
}
```

Remove `SINGLE_SIDE_OR_ALLY` (not in dex). Add corresponding `targeting_labels` entries.

### 2b. Accuracy Convention

Dex `accuracy: null` means always-hits. Game maps this to `accuracy = 0` with the convention that `0 = no accuracy check (always hits)`. Document in CONTEXT.md.

### 2c. Priority Mapping Constant

Add to `registry.gd`:

```gdscript
const DEX_PRIORITY_MAP: Dictionary = {
    -4: Priority.MINIMUM,
    -3: Priority.NEGATIVE,
    -2: Priority.VERY_LOW,
    -1: Priority.LOW,
    0: Priority.NORMAL,
    1: Priority.HIGH,
    2: Priority.VERY_HIGH,
    3: Priority.INSTANT,
    4: Priority.MAXIMUM,
}
```

---

## Part 3: EditorPlugin Implementation

### File Structure

```
addons/dex_importer/
├── plugin.cfg                    # Update script field
├── dex_importer_plugin.gd        # EditorPlugin — registers dock
├── dex_importer_dock.tscn        # Dock panel scene
├── dex_importer_dock.gd          # Dock panel UI + orchestration
├── import/
│   ├── dex_client.gd             # Fetches export data (HTTP or file)
│   ├── dex_mapper.gd             # Maps dex JSON → game Resource instances
│   └── resource_writer.gd        # Saves Resource instances as .tres files
```

### 3a. Plugin Registration (`dex_importer_plugin.gd`)

- `extends EditorPlugin`
- `_enter_tree()`: instantiate dock scene, `add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)`
- `_exit_tree()`: `remove_control_from_docks(dock)`, free dock

### 3b. Dock Panel UI (`dex_importer_dock.tscn` + `.gd`)

VBoxContainer layout:
1. **Header**: "Dex Importer" label
2. **Source section**:
   - OptionButton: "API" / "File" mode toggle
   - LineEdit: URL (default `http://localhost:3000/export/game`) — shown in API mode
   - LineEdit + browse button: file path — shown in File mode
3. **Import options** (CheckBoxes, all checked by default):
   - Digimon, Techniques, Abilities, Evolutions, Locations
4. **Import button**: "Import from Dex"
5. **Progress**: ProgressBar (hidden until import starts)
6. **Log**: RichTextLabel (scrollable, shows import progress/errors)

### 3c. Fetch Client (`dex_client.gd`)

- `extends RefCounted`
- `fetch_from_api(url: String) -> Dictionary`: Uses `HTTPRequest` to GET the URL, parses JSON
- `fetch_from_file(path: String) -> Dictionary`: Reads JSON file from disk
- Returns parsed Dictionary or error

### 3d. Mapper (`dex_mapper.gd`)

- `extends RefCounted`
- Pure mapping functions — no I/O, no side effects
- `map_technique(dex_data: Dictionary) -> TechniqueData`
- `map_ability(dex_data: Dictionary) -> AbilityData`
- `map_digimon(dex_data: Dictionary) -> DigimonData`
- `map_evolution(dex_data: Dictionary) -> EvolutionLinkData`
- Contains all enum/value mapping dictionaries

### 3e. Resource Writer (`resource_writer.gd`)

- `extends RefCounted`
- `write_resource(resource: Resource, folder: String, filename: String) -> Error`
- Uses `ResourceSaver.save()` to write .tres files
- Creates directories if they don't exist

### 3f. Import Flow (orchestrated by `dex_importer_dock.gd`)

Order matters — techniques and abilities before Digimon (key references).

1. Fetch data (API or file)
2. **Import techniques** → `res://data/technique/{game_id}.tres`
3. **Import abilities** → `res://data/ability/{game_id}.tres`
4. **Import Digimon** → `res://data/digimon/{game_id}.tres`
5. **Import evolutions** → `res://data/evolution/{from_key}_to_{to_key}.tres`
6. **Import locations** → `res://data/locale/locations.json` (raw JSON for now — locations need manual scene linking later)
7. Log summary: counts imported, warnings, errors
8. Call `EditorInterface.get_resource_filesystem().scan()` to refresh Godot's file system

**Re-import behaviour**: Overwrites existing .tres files. This is the intended "ephemeral data" design.

---

## Part 4: Field Mapping Tables

### Digimon (`dex → DigimonData`)

| Dex field | Game field | Transform |
|-----------|-----------|-----------|
| `game_id` | `key` | `StringName` |
| `jp_name` | `jp_name` | direct |
| `dub_name` | `dub_name` | `""` if null |
| `name` | `custom_name` | `""` if null |
| `traits` | `size_trait`, `movement_traits`, `type_trait`, `element_traits` | Split by category, `_trait_to_key()` |
| `level` | `level` | `1` if null |
| `attribute` | `attribute` | name → `Registry.Attribute` enum |
| `hp`..`speed` | `base_hp`..`base_speed` | direct |
| `bst` | `bst` | direct |
| `resistances` | `resistances` | element name → lowercase `StringName` key |
| techniques with `{type:"innate"}` | `innate_technique_keys` | `Array[StringName]` |
| all techniques | `learnable_technique_keys` | `Array[StringName]` |
| `abilities[slot=N]` | `ability_slot_N_key` | `StringName`, `&""` if missing |

### Techniques (`dex → TechniqueData`)

| Dex field | Game field | Transform |
|-----------|-----------|-----------|
| `game_id` | `key` | `StringName` |
| `jp_name` | `jp_name` | direct |
| `dub_name` | `dub_name` | `""` if null |
| `name` | `custom_name` | `""` if null |
| `description` | `description` | `""` if null |
| `mechanic_description` | `mechanic_description` | `""` if null |
| `class` | `technique_class` | string → `Registry.TechniqueClass` |
| `targeting` | `targeting` | string → `Registry.Targeting` |
| `element` | `element_key` | lowercase `StringName`, `&""` if null |
| `accuracy` | `accuracy` | `null` → `0` (always hits) |
| `energy_cost` | `energy_cost` | direct |
| `priority` | `priority` | int → `Registry.Priority` via `DEX_PRIORITY_MAP` |
| `bricks` | `bricks` | direct |
| — | `power` | defaults to `0` (future: extract from DAMAGE brick) |
| — | `tags` | defaults to `[]` (future: extract from bricks) |
| — | `charge_required` | defaults to `0` (future: extract from CHARGE_REQUIREMENT brick) |
| — | `charge_conditions` | defaults to `[]` (future: extract from CHARGE_REQUIREMENT brick) |

### Abilities (`dex → AbilityData`)

| Dex field | Game field | Transform |
|-----------|-----------|-----------|
| `game_id` | `key` | `StringName` |
| `name` | `name` | direct |
| `description` | `description` | `""` if null |
| `mechanic_description` | `mechanic_description` | `""` if null |
| `trigger` | `trigger` | camelCase → `Registry.AbilityTrigger` |
| `stack_limit` | `stack_limit` | camelCase → `Registry.StackLimit` |
| `trigger_condition` | `trigger_condition` | direct, `{}` if null |
| `bricks` | `bricks` | direct |

### Evolutions (`dex → EvolutionLinkData`)

| Dex field | Game field | Transform |
|-----------|-----------|-----------|
| composite | `key` | `&"{from}_to_{to}"` |
| `from_game_id` | `from_key` | `StringName` |
| `to_game_id` | `to_key` | `StringName` |
| `evolution_type` | `evolution_type` | name → `Registry.EvolutionType` |
| `requirements` | `requirements` | direct, `[]` if null |
| `jogress_partners` | `jogress_partner_keys` | `Array[StringName]` |

### Enum Mapping Dictionaries (in `dex_mapper.gd`)

**Attribute**: `{ "None": NONE, "Vaccine": VACCINE, "Virus": VIRUS, "Data": DATA, "Free": FREE, "Variable": VARIABLE, "Unknown": UNKNOWN }`

**Targeting**: `{ "Self": SELF, "SingleTarget": SINGLE_TARGET, "SingleOther": SINGLE_OTHER, "SingleAlly": SINGLE_ALLY, "SingleFoe": SINGLE_FOE, "AllAllies": ALL_ALLIES, "AllOtherAllies": ALL_OTHER_ALLIES, "AllFoes": ALL_FOES, "All": ALL, "AllOther": ALL_OTHER, "SingleSide": SINGLE_SIDE, "Field": FIELD }`

**AbilityTrigger**: camelCase → UPPER_SNAKE for all 20 values

**StackLimit**: `{ "unlimited": UNLIMITED, "oncePerTurn": ONCE_PER_TURN, "oncePerSwitch": ONCE_PER_SWITCH, "oncePerBattle": ONCE_PER_BATTLE, "firstOnly": FIRST_ONLY }`

**EvolutionType**: `{ "Standard": STANDARD, "Spirit": SPIRIT, "Armor": ARMOR, "Slide": SLIDE, "X-Antibody": X_ANTIBODY, "Jogress": JOGRESS, "Mode Change": MODE_CHANGE }`

**Element** (name → key): `{ "Null": &"null", "Fire": &"fire", ... }` (lowercase StringName)

---

## Part 5: Files to Create/Modify

### Create (8 new files)

| File | Purpose |
|------|---------|
| `addons/dex_importer/EXPORT_CONTRACT.md` | Detailed export endpoint contract — source of truth for dex implementation |
| `addons/dex_importer/dex_importer_plugin.gd` | EditorPlugin — registers/unregisters dock |
| `addons/dex_importer/dex_importer_dock.tscn` | Dock panel UI scene |
| `addons/dex_importer/dex_importer_dock.gd` | Dock panel logic + import orchestration |
| `addons/dex_importer/import/dex_client.gd` | HTTP/file fetch client |
| `addons/dex_importer/import/dex_mapper.gd` | Dex JSON → game Resource mapper |
| `addons/dex_importer/import/resource_writer.gd` | Saves resources as .tres files |
| `addons/dex_importer/import/.gdkeep` | Preserve directory in git |

### Modify (3 existing files)

| File | Change |
|------|--------|
| `addons/dex_importer/plugin.cfg` | Set `script="dex_importer_plugin.gd"` |
| `autoload/registry.gd` | Expand `Targeting` enum, add `DEX_PRIORITY_MAP`, update labels |
| `CONTEXT.md` | Document accuracy=0 convention, expanded targeting, import pipeline |

---

## Verification

1. **Enable plugin**: Project Settings > Plugins > Enable "Dex Importer" — dock appears
2. **Mock import test**: Create a small test JSON file matching the export schema (5 Digimon, 10 techniques, 0 abilities) and import via "File" mode
3. **Check .tres output**: Verify generated files load correctly in Godot inspector
4. **Check Atlas**: Run the game — Atlas prints correct counts matching imported data
5. **Re-import test**: Import again — files overwritten cleanly, no duplicates
6. **Empty data handling**: Import with abilities=[] and locations empty — completes without errors

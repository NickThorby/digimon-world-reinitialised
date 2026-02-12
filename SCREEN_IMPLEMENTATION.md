# SCREEN_IMPLEMENTATION.md — Game Screen Specification

## 1. Design Philosophy & Rules

### 1.1 Dual-Mode Architecture

Every screen supports two modes controlled by `Registry.GameMode`:

| Aspect | TEST Mode | STORY Mode |
|--------|-----------|------------|
| Source | Battle builder hub | Overworld pause menu |
| Player state | Created fresh or loaded from test save slot | Loaded from story save slot |
| Restrictions | None — free editing, infinite debug access | Enforces real game constraints |
| Storage | `free_mode = true` — "Add Digimon" button visible | `free_mode = false` — no free creation |
| Hub buttons | All visible (Battle, Shop, Training, etc.) | Some hidden (Battle, Shop, Training) |

### 1.2 Screen Configuration Pattern

Screens communicate via the `Game` autoload — never directly. The flow:

```
1. Caller sets Game.screen_context = { ... }  (inputs)
2. Caller calls SceneManager.change_scene(target_path)
3. Target screen reads Game.screen_context in _ready()
4. On exit, screen sets Game.screen_result = ... (outputs) if needed
5. Screen calls SceneManager.change_scene(return_scene)
6. Caller reads Game.screen_result
```

**Context dictionary keys common to all screens:**
- `mode: Registry.GameMode` — TEST or STORY
- `return_scene: String` — scene path to return to on back/cancel

### 1.3 Modularity Rules

- Screens **never** import or reference other screen scripts directly
- All inter-screen data flows through `Game.screen_context` / `Game.screen_result`
- Reusable UI components live in `ui/components/` and communicate via signals
- Scene files live in `scenes/screens/` with matching `.gd` scripts
- Screens must work standalone when given valid context (no hidden state assumptions)

### 1.4 Persistence Rules

- Only **owned-side** data persists to `Game.state` (party, storage, inventory, etc.)
- Wild/tamer opponent data is **ephemeral** — created per battle, discarded after
- After battle, the battle system writes back HP, energy, status, XP, consumable usage to `Game.state`
- Save files use **source-data-only serialisation** — IVs, TVs, level, personality, known techniques, equipped gear; derived stats recalculated on load

### 1.5 Documentation Rules

Every screen `.gd` file must include a header doc comment block:

```gdscript
## [ScreenName]
##
## Purpose: [one-line description]
##
## Context inputs (Game.screen_context):
##   mode: Registry.GameMode — TEST or STORY
##   [screen-specific keys...]
##
## Context outputs (Game.screen_result):
##   [description of what's returned, or "None"]
##
## Signals:
##   [any signals emitted to parent/system]
##
## Configuration:
##   [any export vars or toggleable features]
```

### 1.6 Testing Rules

- Every screen gets tests in `tests/screens/test_[screen_name].gd`
- New state classes get unit tests in `tests/unit/`
- New calculators/utilities get unit tests in `tests/unit/`
- Tests use `TestBattleFactory` + `TestScreenFactory` synthetic data — never real game data
- All test data keys prefixed `test_`
- Each screen test covers: context handling, state mutations, navigation, edge cases

---

## 2. Architecture Changes

### 2.1 New State Classes

#### StorageState — `scripts/systems/game/storage_state.gd`

PC box storage system. 100 boxes × 50 slots.

```
class_name StorageState extends RefCounted

Constants:
  MAX_BOXES: int = 100
  SLOTS_PER_BOX: int = 50

Fields:
  boxes: Array[Array]           # Array of Array[Variant] — DigimonState or null per slot
  box_names: Array[String]      # Custom name per box, default "Box 1" through "Box 100"
  current_box: int = 0          # Last-viewed box index (persisted for UX)

Methods:
  get_digimon(box: int, slot: int) -> DigimonState  # null if empty
  set_digimon(box: int, slot: int, digimon: DigimonState) -> void
  remove_digimon(box: int, slot: int) -> DigimonState  # returns removed, sets slot to null
  swap_digimon(box_a: int, slot_a: int, box_b: int, slot_b: int) -> void
  find_first_empty_slot() -> Dictionary  # {"box": int, "slot": int} or {} if full
  get_box_count(box: int) -> int  # number of non-null slots in box
  get_total_stored() -> int
  to_dict() -> Dictionary
  static from_dict(data: Dictionary) -> StorageState
```

Initialises all 100 boxes with 50 null slots and default names on construction.

#### TamerData — `data/tamer/tamer_data.gd`

Immutable resource for configuring NPC tamers. Used in story mode for tamer battles and in test mode for quick opponent setup.

```
class_name TamerData extends Resource

@export var key: StringName = &""
@export var name: String = ""
@export var title: String = ""                        # e.g. "Bug Catcher", "Arena Champion"
@export var party_config: Array[Dictionary] = []      # [{key, level, ability_slot, techniques, gear_key, consumable_key}]
@export var item_keys: Array[Dictionary] = []         # [{key, quantity}]  — bag contents for battle
@export var ai_type: StringName = &"default"          # AI strategy key
@export var sprite_key: StringName = &""
@export var battle_dialogue: Dictionary = {}          # {"intro": String, "win": String, "lose": String}
@export var reward_bits: int = 0
@export var reward_items: Array[Dictionary] = []      # [{key, quantity}]
```

#### TamerState — `scripts/systems/game/tamer_state.gd`

Runtime tamer state created from TamerData. Ephemeral — not persisted after battle.

```
class_name TamerState extends RefCounted

Fields:
  key: StringName = &""
  name: String = ""
  party: PartyState = PartyState.new()
  inventory: InventoryState = InventoryState.new()
  ai_type: StringName = &"default"

Methods:
  static from_tamer_data(data: TamerData) -> TamerState
    # Creates DigimonState instances via DigimonFactory for each party_config entry
    # Populates inventory from item_keys
  to_battle_side_config() -> Dictionary
    # Returns a side_configs entry: {controller: AI, party, is_wild: false, is_owned: false, bag}
```

#### ShopData — `data/shop/shop_data.gd`

Configurable shop inventory. Each shop has a stock list and price modifiers.

```
class_name ShopData extends Resource

@export var key: StringName = &""
@export var name: String = ""
@export var stock: Array[Dictionary] = []    # [{key: StringName, price_override: int}]
                                              # price_override -1 = use ItemData.buy_price
@export var buy_multiplier: float = 1.0      # Price multiplier for buying
@export var sell_multiplier: float = 0.5     # Sell price = ItemData.buy_price * sell_multiplier
```

A special `test_shop` will be created programmatically containing every item in `Atlas.items` at price 0.

#### TrainingCalculator — `scripts/utilities/training_calculator.gd`

Pure utility for training mechanics. No state — all static functions.

```
class_name TrainingCalculator extends RefCounted

## Run a training course. Returns { "steps": Array[bool], "tv_gained": int }.
## Each step is an independent pass/fail roll.
static func run_course(
  difficulty: int,          # 0=basic, 1=standard, 2=advanced
  rng: RandomNumberGenerator = null,
) -> Dictionary

## Get the TP cost for a difficulty tier.
static func get_tp_cost(difficulty: int) -> int

## Get the TV gained per successful step for a difficulty tier.
static func get_tv_per_step(difficulty: int) -> int

## Get the pass rate for a difficulty tier.
static func get_pass_rate(difficulty: int) -> float
```

#### EvolutionChecker — `scripts/utilities/evolution_checker.gd`

Checks evolution requirements against a Digimon's current state.

```
class_name EvolutionChecker extends RefCounted

## Check all requirements for an evolution link.
## Returns Array[Dictionary]: [{"type": String, "description": String, "met": bool}]
static func check_requirements(
  link: EvolutionLinkData,
  digimon: DigimonState,
  inventory: InventoryState,
) -> Array[Dictionary]

## Check if ALL requirements are met.
static func can_evolve(
  link: EvolutionLinkData,
  digimon: DigimonState,
  inventory: InventoryState,
) -> bool
```

#### ZoneData — `scripts/systems/world/zone_data.gd`

Parsed from `data/locale/locations.json` at runtime. Holds encounter info only. Not a Resource (parsed from JSON, not .tres). Battlefield environment is **not** stored here — it will be determined dynamically by a future BattlefieldFactory based on zone context, real-time conditions, and other factors.

```
class_name ZoneData extends RefCounted

Fields:
  key: StringName                       # Composite: "region/sector/zone" e.g. "grassy_plains/north/clearing"
  name: String
  region_name: String
  sector_name: String
  description: String

  # Encounter table
  encounter_entries: Array[Dictionary]  # [{digimon_key, rarity, min_level, max_level}]
                                        # min_level/max_level: -1 = use zone defaults
  default_min_level: int = 1
  default_max_level: int = 5
  format_weights: Dictionary = {}       # {BattleConfig.FormatPreset -> int weight}
                                        # Empty = 100% SINGLES_1V1

  # Future hooks
  boss_entries: Array[Dictionary] = []  # [{digimon_key, level, boss_type}] — special encounters
  sos_enabled: bool = false

Methods:
  get_encounter_level_range(entry: Dictionary) -> Dictionary
    # Returns {"min": int, "max": int} — entry override or zone default

  static parse_from_json(region: Dictionary, sector: Dictionary, zone: Dictionary) -> ZoneData
    # Parses a single zone from the locations.json structure
```

#### EncounterTableData — `data/encounter/encounter_table_data.gd`

Resource version for the **test screen** (saveable/loadable presets). Story mode uses ZoneData directly. Same encounter fields as ZoneData but as a Resource with @exports.

```
class_name EncounterTableData extends Resource

@export var key: StringName = &""
@export var name: String = ""
@export var entries: Array[Dictionary] = []          # [{digimon_key, rarity, min_level, max_level}]
@export var default_min_level: int = 1
@export var default_max_level: int = 5
@export var format_weights: Dictionary = {}          # {int(FormatPreset) -> int weight}
@export var boss_entries: Array[Dictionary] = []
@export var sos_enabled: bool = false

Methods:
  to_zone_data() -> ZoneData
    # Converts to ZoneData for use with WildBattleFactory
```

#### WildBattleFactory — `scripts/systems/battle/wild_battle_factory.gd`

Pure utility. All static functions. Creates wild encounter BattleConfigs. **Only populates combatant sides** — does NOT set field effects (weather, terrain, hazards). Those are the responsibility of a future BattlefieldFactory that runs after encounter generation.

```
class_name WildBattleFactory extends RefCounted

## Create a wild encounter BattleConfig from zone data.
## Returns a BattleConfig with player side and wild side populated.
## Field effects are NOT set — caller (or future BattlefieldFactory) handles that.
static func create_encounter(
  zone: ZoneData,
  player_party: Array[DigimonState],
  player_bag: BagState,
  rng: RandomNumberGenerator = null,
) -> BattleConfig
  # 1. Roll battle format from zone.format_weights
  # 2. Determine wild side slot count from format
  # 3. For each wild slot: roll species from entries (weighted by rarity), roll level
  # 4. Create DigimonState via DigimonFactory for each
  # 5. Build BattleConfig: player side (is_owned: true), wild side (is_wild: true, controller: AI)
  # 6. Return config (no field effects applied)

## Roll a single species from encounter entries using rarity weights.
## Returns the entry Dictionary, or {} if entries empty.
static func roll_species(
  entries: Array[Dictionary],
  rng: RandomNumberGenerator = null,
) -> Dictionary

## Roll a level within an entry's range (with zone default fallback).
static func roll_level(
  entry: Dictionary,
  zone: ZoneData,
  rng: RandomNumberGenerator = null,
) -> int

## Roll a battle format from weight distribution.
## Returns a FormatPreset. Defaults to SINGLES_1V1 if weights empty.
static func roll_format(
  format_weights: Dictionary,
  rng: RandomNumberGenerator = null,
) -> BattleConfig.FormatPreset
```

**Rarity → weight mapping** (configurable in GameBalance):

| Rarity | Default Weight |
|--------|---------------|
| COMMON | 50 |
| UNCOMMON | 30 |
| RARE | 15 |
| VERY_RARE | 4 |
| LEGENDARY | 1 |

Multiple entries of the same rarity stack. E.g. 3 COMMON species each get weight 50, so each has 50/(50+50+50) = 33% within the COMMON tier. Total pool: 2 COMMON (50 each) + 1 RARE (15) → probabilities 50/115, 50/115, 15/115.

#### Future: BattlefieldFactory (not built now — documented for context)

A third factory, built later, will be responsible for applying environmental conditions to **any** BattleConfig (wild or tamer). It will consider:
- Zone identity (volcanic zones tend toward heat, ocean zones toward rain, etc.)
- Real-time / in-game time factors
- Story progression flags
- Random variation

This is why neither WildBattleFactory nor TamerState touches `preset_field_effects` / `preset_side_effects` / `preset_hazards`. The test screen provides manual field effect configuration as a stand-in until BattlefieldFactory exists.

### 2.2 Modifications to Existing Classes

#### DigimonState — add training points

```gdscript
var training_points: int = 0  # TP — gained 5 per level-up, spent on training courses
```

Add to `to_dict()` and `from_dict()`.

#### GameState — storage migration + new fields

```gdscript
# CHANGE: var storage: Array[DigimonState] = []
#      -> var storage: StorageState = StorageState.new()
var tamer_name: String = ""           # Player's chosen name
var tamer_id: StringName = &""        # Player's tamer ID (generated on new game)
var play_time: int = 0                # Seconds played (for save metadata)
```

Update `to_dict()` / `from_dict()`. The old `storage` array format is not supported (no production saves exist).

#### InventoryState — rename money to bits

```gdscript
# CHANGE: var money: int = 0
#      -> var bits: int = 0
```

Update `to_dict()` / `from_dict()` to use `"bits"` key.

#### GameBalance — add new constants

```gdscript
# Training
@export var training_points_per_level: int = 5
@export var max_training_points: int = 999
@export var training_courses: Array[Dictionary] = [
  {"cost": 1, "tv_per_step": 2, "pass_rate": 0.9},    # Basic
  {"cost": 5, "tv_per_step": 5, "pass_rate": 0.7},     # Standard
  {"cost": 10, "tv_per_step": 10, "pass_rate": 0.5},   # Advanced
]
# Storage
@export var storage_box_count: int = 100
@export var storage_slots_per_box: int = 50
# Save
@export var save_slot_count: int = 3
# Wild encounters
@export var rarity_weights: Dictionary = {
  0: 50,   # COMMON
  1: 30,   # UNCOMMON
  2: 15,   # RARE
  3: 4,    # VERY_RARE
  4: 1,    # LEGENDARY
}
@export var default_encounter_min_level: int = 1
@export var default_encounter_max_level: int = 5
@export var default_format_weights: Dictionary = {
  0: 85,   # SINGLES_1V1
  1: 15,   # DOUBLES_2V2
}
```

All training courses have **3 steps**. Each step is an independent pass/fail roll at the course's pass rate. TV gained = successful_steps × tv_per_step.

#### XPCalculator — grant TP on level-up

In `apply_xp()`, after incrementing `state.level`:
```gdscript
state.training_points += balance.training_points_per_level
```

#### Game autoload — screen navigation + mode

```gdscript
var game_mode: Registry.GameMode = Registry.GameMode.TEST
var screen_context: Dictionary = {}
var screen_result: Variant = null
```

Keep existing `picker_context`/`picker_result`/`builder_context` until the battle builder is fully replaced by the Start Battle Screen, then remove them.

#### Atlas autoload — load new data types

```gdscript
var tamers: Dictionary = {}   # StringName -> TamerData
var shops: Dictionary = {}    # StringName -> ShopData
```

Load from `data/tamer/` and `data/shop/` directories.

```gdscript
var zones: Dictionary = {}  # StringName -> ZoneData (keyed by composite "region/sector/zone")
```

Parsed from `data/locale/locations.json` on load. Zone keys are snake_case composite paths.

#### SaveManager — mode-based directories + metadata

```gdscript
const TEST_SAVE_DIR := "user://saves/test/"
const STORY_SAVE_DIR := "user://saves/story/"

static func get_save_dir(mode: Registry.GameMode) -> String

## Save with metadata envelope for slot preview.
static func save_game(state: GameState, slot: String, mode: Registry.GameMode) -> bool

## Load metadata only (tamer name, party keys/levels, play time, timestamp).
static func get_save_metadata(slot: String, mode: Registry.GameMode) -> Dictionary
```

#### Registry — add GameMode and Rarity enums

```gdscript
enum GameMode {
  TEST,
  STORY,
}

enum Rarity {
  COMMON,
  UNCOMMON,
  RARE,
  VERY_RARE,
  LEGENDARY,
}
```

### 2.3 UI Component Changes

#### DigimonSlotPanel — flipped sprite option

Add an export or method to display the sprite flipped horizontally (`flip_h = true`), matching the enemy battler convention used in `battlefield_display.gd`. This is the standard display style for party/storage views.

#### New: StorageSlot — `ui/components/storage_slot.tscn`

Small panel (~64×64) for a single box slot. Shows Digimon sprite thumbnail (flipped) or empty state. Supports:
- Click to select
- Drag-and-drop (start drag, accept drop)
- Hover tooltip (name + level)
- Highlight border when selected
- Signals: `slot_clicked(box: int, slot: int)`, `slot_drag_started(box: int, slot: int)`, `slot_drop_received(box: int, slot: int)`

---

## 3. Screen Specifications

### 3.1 Title Screen Updates

**Purpose**: Add New Game / Continue flow before the hub.

**File**: `scenes/main/main.tscn` + `scenes/main/main.gd` (modify existing)

**Layout changes**:
- "Battle Builder" button → **"Test Mode"** button
- Add **"Story Mode"** button (greyed out / "Coming Soon" until story content exists)
- "Test Mode" flow: opens Save Screen with `action: "select"` for test mode slots
- Save Screen offers: "New Game" (creates fresh GameState) or pick an existing slot to load
- After selection, navigates to Mode Screen

**No separate scene needed** — modify existing `main.gd`.

---

### 3.2 Mode Screen (Hub)

**Purpose**: Central navigation hub. The in-game menu for both test mode and story mode.

**Scene**: `scenes/screens/mode_screen.tscn`
**Script**: `scenes/screens/mode_screen.gd`

**Context inputs**:
```gdscript
{
  "mode": Registry.GameMode,  # Determines which buttons are visible
}
```

**Context outputs**: None (navigates directly to target screens).

**Layout**:
- **Header bar**: Tamer name, party icon strip (first 6 Digimon mini-sprites), bits display
- **Button grid** (3 columns, centred): Each button is an icon (TextureRect) + label (Label) underneath
- **Back button**: Returns to title screen (with "Save before quitting?" confirmation if unsaved changes)

**Buttons and visibility**:

| Button | Icon placeholder | Test Mode | Story Mode |
|--------|-----------------|-----------|------------|
| Party | party_icon | Yes | Yes |
| Bag | bag_icon | Yes | Yes |
| Storage | storage_icon | Yes | Yes |
| Save | save_icon | Yes | Yes |
| Battle | battle_icon | Yes | **No** |
| Wild Battle | wild_icon | Yes | **No** |
| Shop | shop_icon | Yes | **No** |
| Training | training_icon | Yes | **No** |
| Settings | settings_icon | Yes | Yes |

Icons will be provided later — use placeholder `Texture2D` for now.

**Behaviour**:
- Each button sets `Game.screen_context` with appropriate values and navigates to the target
- Disabled buttons show a tooltip explaining why (e.g. "Available from the overworld")
- Party count shown in header updates when returning from other screens
- Bits display updates when returning from shop

**Dependencies**: `Game.state` must be non-null.

---

### 3.3 Save Screen

**Purpose**: Slot-based save/load system. Accessible from Mode Screen (save action) or title screen (load/new game action).

**Scene**: `scenes/screens/save_screen.tscn`
**Script**: `scenes/screens/save_screen.gd`

**Context inputs**:
```gdscript
{
  "action": String,             # "save", "load", or "select" (new game OR load)
  "mode": Registry.GameMode,    # Determines save directory
  "return_scene": String,       # Scene path for back/cancel
}
```

**Context outputs**:
- For "save": None (saves and returns)
- For "load"/"select": `Game.state` is populated, navigates to Mode Screen

**Layout**:
- Header: "Save Game" / "Load Game" / "Select Slot"
- 3 slot panels (PanelContainer), each showing:
  - **Occupied**: tamer name, party sprites (up to 6 mini icons), play time, date saved
  - **Empty**: "Empty Slot" label
- Per-slot buttons:
  - Save mode: "Save" (with "Overwrite?" confirmation if occupied), "Delete"
  - Load mode: "Load" (disabled if empty), "Delete"
  - Select mode: "New Game" (on empty slots), "Load" (on occupied slots), "Delete"
- Back button

**Save file structure** (JSON):
```json
{
  "meta": {
    "tamer_name": "Marcus",
    "play_time": 3600,
    "saved_at": 1707753600,
    "party_keys": ["agumon", "gabumon"],
    "party_levels": [25, 23],
    "mode": "test"
  },
  "state": { ... }
}
```

**Save directories**:
- Test mode: `user://saves/test/slot_1.json` through `slot_3.json`
- Story mode: `user://saves/story/slot_1.json` through `slot_3.json`

**Key files**:
- `scenes/screens/save_screen.tscn` + `.gd` (new)
- `scripts/systems/game/save_manager.gd` (modify)

---

### 3.4 Start Battle Screen

**Purpose**: Replace the existing battle builder. Player side is **read-only** (managed via Party and Storage screens). Opponent sides are fully editable. Launches battles.

**Scene**: `scenes/screens/start_battle_screen.tscn`
**Script**: `scenes/screens/start_battle_screen.gd`

**Context inputs**:
```gdscript
{
  "mode": Registry.GameMode,
}
```

**Context outputs**: None (launches battle scene, writes back to `Game.state` on return).

**Layout**:
- **Left panel — Player Preview** (read-only):
  - "Your Team" header
  - Party list using DigimonSlotPanel (non-interactive, no edit/remove buttons)
  - Shows current `Game.state.party.members`
- **Right panel — Opponent Configuration** (tabs, same as current builder):
  - **Opponents tab**: Side tabs, per-side Digimon list with Add/Edit/Remove, Save/Load team buttons
  - **Settings tab**: Format selector, XP toggle, EXP Share toggle, per-side controller/wild/owned toggles
  - **Field Effects tab**: Weather, terrain, global effects (unchanged from builder)
  - **Side Presets tab**: Side effects, hazards (unchanged from builder)
  - **Bag tab**: Per-side item management (opponent sides only)
- **Validation label**: Shows errors from `BattleConfig.validate()`
- **Bottom bar**: "Start Battle" button, "Back" button

**Key behaviour**:
- Player side (`is_owned: true`) is constructed from `Game.state.party.members` and `Game.state.inventory`
- Opponent sides are configured on-screen (same as current builder functionality)
- On "Start Battle": builds `BattleConfig`, player side uses real `Game.state` data
- After battle: owned-side write-back updates `Game.state` (HP, energy, status, XP, consumables)
- On return to Mode Screen, `Game.state` reflects battle outcomes
- Save/Load team functionality remains for opponent sides only

**Migration from battle_builder.gd**:
- Extract opponent-configuration code from current `battle_builder.gd`
- Player side panel becomes a read-only preview
- Remove player-side Add/Edit/Remove functionality
- Keep format selection, field effects, side presets, bag tabs
- Keep team save/load for opponent sides

**Key files**:
- `scenes/screens/start_battle_screen.tscn` + `.gd` (new, replaces `battle_builder.tscn`)
- `scenes/battle/battle_builder.tscn` + `.gd` (delete or archive after migration)

---

### 3.5 Storage Screen (PC Boxes)

**Purpose**: Manage Digimon storage across 100 boxes of 50 slots each. Transfer between party and boxes.

**Scene**: `scenes/screens/storage_screen.tscn`
**Script**: `scenes/screens/storage_screen.gd`

**Context inputs**:
```gdscript
{
  "mode": Registry.GameMode,
  "free_mode": bool,  # true in TEST mode — shows "Add Digimon" button
}
```

**Context outputs**: None (modifies `Game.state` directly).

**Layout**:
- **Left panel** (~300px, fixed):
  - "Party" header
  - 6 party slots (DigimonSlotPanel, flipped sprite) — shows current party
  - Party count: "3/6"
- **Right panel** (fills remaining):
  - **Box header bar**:
    - Left arrow button (previous box)
    - Box name label (editable on double-click) — e.g. "Box 1"
    - Right arrow button (next box)
    - Click box name to open jump-to list (popup with all 100 box names, click to jump)
  - **Box grid**: 10 columns × 5 rows = 50 StorageSlot components
    - Each shows Digimon sprite thumbnail (flipped) or empty state
    - Box count label: "12/50"
- **Bottom bar**:
  - "Add Digimon" button (TEST mode only, `free_mode`) — opens DigimonPicker
  - "Back" button

**Drag-and-drop behaviour**:
- Drag from party → box slot: deposit (fails if last party member)
- Drag from box → party slot: withdraw (fails if party full at 6)
- Drag within box: move to empty slot, or swap if target occupied
- Drag between party slots: reorder
- Drag box → box (different box): change box, then place in slot
- When dropping a Digimon on an occupied slot: swap — the displaced Digimon becomes "held" (cursor shows it), click an empty slot to place it, or click another occupied slot to chain-swap

**Click context menu** (on occupied slot or party member):
- **Summary** → navigates to Summary Screen with this Digimon
- **Item** → submenu: Take Gear / Take Consumable / Give Item (opens Bag Screen in select mode)
- **Evolution** → navigates to Evolution Screen for this Digimon
- **Move** → picks up the Digimon (for drag, supports controller)
- **Release** → confirmation popup, then deletes the Digimon permanently (disabled for last party member)

**Constraints**:
- Party must always have at least 1 Digimon (once one exists)
- Cannot deposit last party member
- "Release" requires confirmation dialog

**Key files**:
- `scenes/screens/storage_screen.tscn` + `.gd` (new)
- `ui/components/storage_slot.tscn` + `.gd` (new)
- `scripts/systems/game/storage_state.gd` (new)

---

### 3.6 Party Screen

**Purpose**: View and manage the active party (up to 6 Digimon). Reorder, access context menus.

**Scene**: `scenes/screens/party_screen.tscn`
**Script**: `scenes/screens/party_screen.gd`

**Context inputs**:
```gdscript
{
  "mode": Registry.GameMode,
  "select_mode": bool,          # If true, clicking a Digimon returns it as screen_result
  "select_filter": Callable,    # Optional: func(state: DigimonState) -> bool
  "select_prompt": String,      # e.g. "Choose a Digimon to give the item to"
  "return_scene": String,
}
```

**Context outputs**:
- Normal mode: None (modifies `Game.state.party` directly)
- Select mode: `Game.screen_result = {"party_index": int, "digimon": DigimonState}` or `null` on cancel

**Layout**:
- **Header**: "Party" (or `select_prompt` if in select mode)
- **6 party slots** (vertical list, DigimonSlotPanel with flipped sprite):
  - Each shows: sprite (flipped), name, level, element icons, HP bar, energy bar, status icons
  - Drag-and-drop reordering (built into DigimonSlotPanel already)
- **Back button**

**Click context menu** (normal mode):
- **Summary** → navigates to Summary Screen
- **Item** → submenu: Take Gear / Take Consumable / Give Item (opens Bag in select mode)
- **Switch** → enters swap mode (pick another party member to swap positions with)
- **Evolution** → navigates to Evolution Screen (greyed if no available evolutions)

**Select mode**: Clicking a valid Digimon (passes `select_filter`) sets `Game.screen_result` and returns. Invalid Digimon are greyed out. Used by item "Use" flow, item "Give" flow, etc.

**Key files**:
- `scenes/screens/party_screen.tscn` + `.gd` (new)

---

### 3.7 Digimon Summary Screen

**Purpose**: Full detail view of a single Digimon. Multi-page layout.

**Scene**: `scenes/screens/summary_screen.tscn`
**Script**: `scenes/screens/summary_screen.gd`

**Context inputs**:
```gdscript
{
  "digimon": DigimonState,       # The Digimon to display
  "party_index": int,            # Index in party (-1 if from storage)
  "editable": bool,              # Whether techniques/ability can be changed
  "party_navigation": bool,      # If true, left/right arrows cycle through party members
  "return_scene": String,
}
```

**Context outputs**: None (modifies DigimonState in-place for technique/ability changes).

**Pages** (navigated via left/right arrows or tab buttons):

**Page 1 — Info**:
- Sprite (large, flipped), name / nickname
- Species name, evolution level label (e.g. "Adult")
- Attribute icon + label (e.g. "Vaccine")
- Element trait icons
- Personality: name + effect ("Brave: +ATK / -DEF"), boosted stat in blue, reduced in red
- OT (Original Tamer): name + display_id
- Level + XP bar (current XP / XP to next level)
- Training Points: "TP: 45"

**Page 2 — Stats**:
- 7 stat rows: stat name, calculated value, bar visualisation
- Personality-affected stats highlighted (blue for boosted, red for reduced)
- IV / TV breakdown shown on hover or as sub-labels
- BST (Base Stat Total) at bottom

**Page 3 — Techniques**:
- **Equipped techniques** (up to 4 slots):
  - Each: name, element icon, technique class icon (Physical/Special/Status), power, accuracy, energy cost
  - Full description + mechanic description on selection
  - If `editable`: swap buttons / drag to reorder
- **Known techniques** (scrollable list below):
  - Each: name, element icon, class icon, power, energy cost
  - If `editable` and equipped slots < max: click to equip
  - If `editable`: click to swap with an equipped technique

**Page 4 — Abilities**:
- 3 ability slots displayed vertically
- Active slot highlighted with accent colour
- Each slot: ability name, trigger type label, description, mechanic_description
- If `editable`: click inactive slot to switch active ability
- Slot 3 (hidden ability) shown with special styling

**Page 5 — Held Items**:
- Equipable gear slot: item name + icon, description, "Take" / "Swap" button
- Consumable slot: item name + icon, description, "Take" / "Swap" button
- "Swap" opens Bag Screen in select mode filtered to appropriate gear slot
- Empty slots show "None" with a "Give" button

**Party navigation**: When `party_navigation = true`, left/right arrows at the edges of the screen cycle through `Game.state.party.members` (wrapping around). This mirrors the Pokemon summary flow.

**Key files**:
- `scenes/screens/summary_screen.tscn` + `.gd` (new)

---

### 3.8 Bag Screen

**Purpose**: View and manage inventory items. Tabbed by category. Use / give / toss items.

**Scene**: `scenes/screens/bag_screen.tscn`
**Script**: `scenes/screens/bag_screen.gd`

**Context inputs**:
```gdscript
{
  "mode": Registry.GameMode,
  "select_mode": bool,            # If true, selecting an item returns it
  "select_filter": Callable,      # Optional: func(item: ItemData) -> bool
  "select_prompt": String,        # e.g. "Choose an item to give"
  "return_scene": String,
}
```

**Context outputs**:
- Normal mode: None (modifies `Game.state.inventory` directly)
- Select mode: `Game.screen_result = {"item_key": StringName}` or `null` on cancel

**Layout**:
- **Tab bar** (top): All | Medicine | Gear | Performance | Card | Key | General | Quest
  - Maps to `Registry.ItemCategory` values
  - "All" shows everything
- **Item list** (left, scrollable):
  - Each row: icon, item name, "×N" quantity
  - Selected item highlighted
  - Sort toggle: A-Z / Manual (drag-and-drop order)
- **Detail panel** (right):
  - Item icon (large), name, category label
  - Full description
  - Buy / Sell price
  - Action buttons:
    - **Use** (if `is_combat_usable` or usable outside battle) → opens Party Screen in select mode → applies effect
    - **Give** (gear items) → opens Party Screen in select mode → equips to gear/consumable slot
    - **Toss** → quantity selector + confirmation → removes from inventory
- **Bits display** (bottom): "Bits: 12,500"
- **Back button**

**Select mode**: When `select_mode = true`, clicking an item sets `Game.screen_result` and returns. Used when giving items from Party/Storage/Summary context menus.

**Key files**:
- `scenes/screens/bag_screen.tscn` + `.gd` (new)

---

### 3.9 Shop Screen

**Purpose**: Buy/sell items using bits. Configurable stock via ShopData.

**Scene**: `scenes/screens/shop_screen.tscn`
**Script**: `scenes/screens/shop_screen.gd`

**Context inputs**:
```gdscript
{
  "shop_key": StringName,        # Key into Atlas.shops (or &"test_shop" for test shop)
  "mode": Registry.GameMode,
  "return_scene": String,
}
```

**Context outputs**: None (modifies `Game.state.inventory` directly).

**Layout**:
- **Tab bar**: "Buy" | "Sell"
- **Buy tab**:
  - Item list from `ShopData.stock`: icon, name, price, "Owned: N"
  - Detail panel: description, quantity selector (+/- or spinner), total cost
  - "Buy" button (disabled if insufficient bits, shows red warning)
- **Sell tab**:
  - Player's sellable items (excludes Key category): icon, name, sell price, "Owned: N"
  - Detail panel: description, quantity selector, total value
  - "Sell" button
- **Bits display** (persistent header): updates in real-time on buy/sell
- **Back button**

**Test Shop**: Created at runtime if `shop_key == &"test_shop"`:
```gdscript
# Populate stock with every item in Atlas.items at price 0
```

**Key files**:
- `scenes/screens/shop_screen.tscn` + `.gd` (new)
- `data/shop/shop_data.gd` (new)

---

### 3.10 Training Screen

**Purpose**: Spend TP on stat training courses. Digimon World 3-style UI with pass/fail per step.

**Scene**: `scenes/screens/training_screen.tscn`
**Script**: `scenes/screens/training_screen.gd`

**Context inputs**:
```gdscript
{
  "party_index": int,            # Index in Game.state.party.members
  "mode": Registry.GameMode,
  "return_scene": String,
}
```

**Context outputs**: None (modifies DigimonState directly).

**Layout**:
- **Digimon panel** (top): sprite (flipped), name, level, current TP display ("TP: 45")
- **Stat course grid** (7 rows, one per stat):
  - Stat name + current TV value + TV bar (0–500)
  - 3 course buttons per row:
    - "Basic (1 TP)" — high pass rate, low TV gain
    - "Standard (5 TP)" — medium pass rate, medium TV gain
    - "Advanced (10 TP)" — low pass rate, high TV gain
  - Buttons disabled if insufficient TP or TV already at max (500)
- **Training animation area** (modal overlay or bottom panel):
  - 3 step indicators (circles)
  - Each step animates: green O (pass) or red X (fail), sequential 0.3s each
  - Running total: "TV gained: +6"
  - "Done!" button to dismiss

**Training mechanics** (all courses have 3 steps):

| Tier | TP Cost | TV per Pass | Pass Rate | Max TV Gain |
|------|---------|-------------|-----------|-------------|
| Basic | 1 | 2 | 90% | 6 |
| Standard | 5 | 5 | 70% | 15 |
| Advanced | 10 | 10 | 50% | 30 |

Each step rolls independently. TV capped at `GameBalance.max_tv` (500) per stat. TP deducted on course start (not refunded on failures).

**Key files**:
- `scenes/screens/training_screen.tscn` + `.gd` (new)
- `scripts/utilities/training_calculator.gd` (new)

---

### 3.11 Evolution Screen

**Purpose**: View available evolutions, check requirements, and evolve.

**Scene**: `scenes/screens/evolution_screen.tscn`
**Script**: `scenes/screens/evolution_screen.gd`

**Context inputs**:
```gdscript
{
  "party_index": int,            # or -1 if from storage
  "storage_box": int,            # box index (if from storage)
  "storage_slot": int,           # slot index (if from storage)
  "mode": Registry.GameMode,
  "return_scene": String,
}
```

**Context outputs**: None (modifies DigimonState in-place).

**Layout**:
- **Current Digimon panel** (left): sprite (flipped), name, level, evolution level label, current stats summary
- **Evolution list** (centre, scrollable):
  - Each available evolution as a card:
    - Target sprite + name + evolution level label
    - Evolution type badge ("Standard", "Jogress", "Spirit", etc.)
    - Requirements checklist:
      - Each requirement: description text + green tick / red cross icon
    - "Evolve!" button (enabled only when ALL requirements met)
    - Unmet evolutions shown greyed/dimmed but still visible
- **Target preview** (right, shown when evolution card selected):
  - Full stat comparison: current → new base stats (with arrows showing change)
  - New element traits
  - New abilities
  - New innate techniques

**Evolution logic** (executed on "Evolve!"):
1. Store reference to old `DigimonData`
2. Set `digimon.key = link.to_key`
3. Look up new `DigimonData` from Atlas
4. Recalculate stats via `StatCalculator.calculate_all_stats()`
5. Adjust HP/energy proportionally: `new_current = (old_current / old_max) * new_max`
6. Add new innate techniques to `known_technique_keys` (don't remove existing)
7. If any equipped technique is not in new species' technique list, it stays equipped but once forgotten cannot be re-equipped
8. Consume required items (spirits, digimentals, X-Antibody) from inventory
9. Play evolution animation (sprite crossfade with particle effect)
10. Update personality-adjusted stats

**Test mode**: "Force Evolve" button bypasses all requirements (useful for testing).

**Key files**:
- `scenes/screens/evolution_screen.tscn` + `.gd` (new)
- `scripts/utilities/evolution_checker.gd` (new)

---

### 3.12 Wild Battle Test Screen

**Purpose**: Test-mode-only screen for configuring and simulating wild encounters. Lets users build custom encounter tables, configure format weights, and launch wild battles through the WildBattleFactory. Also allows manual field effect configuration as a stand-in for the future BattlefieldFactory.

**Scene**: `scenes/screens/wild_battle_test_screen.tscn`
**Script**: `scenes/screens/wild_battle_test_screen.gd`

**Context inputs**:
```gdscript
{
  "mode": Registry.GameMode,  # Always TEST
}
```

**Context outputs**: None (launches battle scene, writes back to Game.state on return).

**Layout**:
- **Left panel — Encounter Table Builder**:
  - "Encounter Table" header
  - Entry list (scrollable):
    - Each row: Digimon sprite + name, rarity dropdown, level range (min-max spinners, blank = zone default)
    - Remove button per entry
  - "Add Digimon" button → opens DigimonPicker → adds entry with COMMON default
  - Zone-wide defaults:
    - "Default Level Range" — min/max spinners
  - Save/Load table buttons (saves as EncounterTableData .tres)

- **Right panel — Battle Settings** (tabs):
  - **Format tab**:
    - Format weight sliders (1v1, 2v2, 3v3) — each 0-100, shown as percentages
    - Preview: "85% Singles, 15% Doubles"
  - **Battlefield tab** (manual stand-in for future BattlefieldFactory):
    - Weather selector (same as existing builder field effects)
    - Terrain selector
    - Global effects list (add/remove)
    - Side effects / Hazards (reuse existing builder components)
    - Note: in story mode these will be determined by BattlefieldFactory, not configured manually
  - **Special tab** (future):
    - Boss encounter toggle + config
    - SOS battle toggle

- **Bottom bar**:
  - "Roll Encounter" button — runs factory, shows preview panel:
    - Rolled species + level per wild slot
    - Rolled format
    - "Accept & Battle" / "Re-roll" / "Cancel"
  - "Quick Battle" button — runs factory and starts battle immediately
  - "Back" button

**Key behaviour**:
- Player side auto-populated from `Game.state.party` (read-only, same as Start Battle Screen)
- WildBattleFactory produces the BattleConfig with combatant sides
- Test screen manually applies any configured field effects to the BattleConfig before launching
- After battle: owned-side write-back updates `Game.state`
- Save/Load persists EncounterTableData resources to `user://encounter_tables/`

---

## 4. Implementation Order

### Phase 0 — Infrastructure

Must be completed first. No UI — only state classes, field additions, and test reorganisation.

| Task | Files | Notes |
|------|-------|-------|
| Add `Registry.GameMode` enum | `autoload/registry.gd` | |
| Create `StorageState` | `scripts/systems/game/storage_state.gd` | + unit tests |
| Migrate `GameState.storage` | `scripts/systems/game/game_state.gd` | Array → StorageState |
| Add `DigimonState.training_points` | `scripts/systems/digimon/digimon_state.gd` | + serialisation |
| Rename `InventoryState.money` → `bits` | `scripts/systems/inventory/inventory_state.gd` | |
| Add GameBalance training/storage constants | `data/config/game_balance.tres` + `.gd` | |
| Grant TP on level-up in `XPCalculator` | `scripts/systems/battle/xp_calculator.gd` | + test update |
| Add `Game.screen_context/result/game_mode` | `autoload/game.gd` | |
| Update `SaveManager` for mode directories + metadata | `scripts/systems/game/save_manager.gd` | |
| Create `TamerData` resource | `data/tamer/tamer_data.gd` | |
| Create `TamerState` | `scripts/systems/game/tamer_state.gd` | |
| Create `ShopData` resource | `data/shop/shop_data.gd` | |
| Create `TrainingCalculator` | `scripts/utilities/training_calculator.gd` | + unit tests |
| Create `EvolutionChecker` | `scripts/utilities/evolution_checker.gd` | + unit tests |
| Add `Atlas.tamers` and `Atlas.shops` loading | `autoload/atlas.gd` | |
| Add `GameState.tamer_name/tamer_id/play_time` | `scripts/systems/game/game_state.gd` | |
| Reorganise test folders | `tests/` | See §5 |
| Create `TestScreenFactory` helper | `tests/helpers/test_screen_factory.gd` | |
| Update `CONTEXT.md` | `CONTEXT.md` | Document new state classes |

### Phase 1 — Foundation Screens

| Order | Screen | Dependencies |
|-------|--------|-------------|
| 1a | Title Screen updates | Phase 0 (SaveManager) |
| 1b | Save Screen | Phase 0 (SaveManager metadata) |
| 1c | Mode Screen (Hub) | Phase 0 (Game.screen_context, GameMode) |

### Phase 2 — Core Management Screens

| Order | Screen | Dependencies |
|-------|--------|-------------|
| 2a | Party Screen | Phase 1 (Mode Screen navigation) |
| 2b | Bag Screen | Phase 1 (Mode Screen navigation) |
| 2c | Digimon Summary Screen | Phase 2a (opened from Party) |

### Phase 3 — Advanced Screens

| Order | Screen | Dependencies |
|-------|--------|-------------|
| 3a | Storage Screen | Phase 0 (StorageState), Phase 2a (Party concepts) |
| 3b | Shop Screen | Phase 0 (ShopData), Phase 2b (Bag interaction) |
| 3c | Training Screen | Phase 0 (TP, TrainingCalculator), Phase 2a (Party select) |
| 3d | Evolution Screen | Phase 0 (EvolutionChecker), Phase 2c (Summary for stat display) |

### Phase 4 — Battle Integration

| Order | Screen | Dependencies |
|-------|--------|-------------|
| 4a | Start Battle Screen | Phase 1 (Mode), Phase 2a (Party), replaces old builder |

### Phase 5 — Wild Battle System

| Order | Task | Dependencies |
|-------|------|-------------|
| 5a | Add `Registry.Rarity` enum | Phase 0 |
| 5b | Create `ZoneData` class | Phase 0 |
| 5c | Add `Atlas.zones` parsing from locations.json | 5b |
| 5d | Create `EncounterTableData` resource | 5a |
| 5e | Add GameBalance wild encounter constants | Phase 0 |
| 5f | Create `WildBattleFactory` | 5b, 5e, DigimonFactory, BattleConfig |
| 5g | Create Wild Battle Test Screen | 5d, 5f, Phase 1 (Mode Screen), Phase 2a (Party) |
| 5h | Add "Wild Battle" button to Mode Screen | 5g, Phase 1c |

### Integration Passes (after each phase)

After each phase, return to previously-built screens to wire up cross-references:
- After Phase 2c: add "Summary" to Party context menu
- After Phase 2b: add "Item → Give" flow from Party/Storage to Bag
- After Phase 3a: add "Storage" navigation from Mode Screen
- After Phase 3d: add "Evolution" to Party and Storage context menus

---

## 5. Testing Strategy

### 5.1 Test Folder Reorganisation

Move all battle-specific tests into `tests/battle/` with `unit/` and `integration/` subfolders. Non-battle tests remain in `tests/unit/`. New screen tests go in `tests/screens/`.

```
tests/
├── helpers/
│   ├── test_battle_factory.gd        # Existing — battle test data
│   └── test_screen_factory.gd        # NEW — screen test data (GameState, party, inventory, storage)
├── unit/                              # Non-battle unit tests
│   ├── test_stat_calculator.gd
│   ├── test_digimon_state.gd
│   ├── test_storage_state.gd          # NEW
│   ├── test_training_calculator.gd    # NEW
│   ├── test_evolution_checker.gd      # NEW
│   ├── test_inventory_state.gd        # NEW (bits rename verification)
│   ├── test_wild_battle_factory.gd    # NEW
│   └── test_zone_data.gd             # NEW
├── battle/
│   ├── unit/                          # Moved from tests/unit/ (battle-specific)
│   │   ├── test_damage_calculator.gd
│   │   ├── test_xp_calculator.gd
│   │   ├── test_bag_state.gd
│   │   ├── ... (all brick/field/status unit tests)
│   └── integration/                   # Moved from tests/integration/
│       ├── test_battle_engine_core.gd
│       ├── test_technique_execution.gd
│       ├── ... (all battle integration tests)
└── screens/                           # NEW — per-screen tests
    ├── test_mode_screen.gd
    ├── test_save_screen.gd
    ├── test_party_screen.gd
    ├── test_bag_screen.gd
    ├── test_storage_screen.gd
    ├── test_shop_screen.gd
    ├── test_training_screen.gd
    ├── test_evolution_screen.gd
    ├── test_summary_screen.gd
    ├── test_start_battle_screen.gd
    └── test_wild_battle_test_screen.gd
```

GUT's recursive directory scan will pick up all subfolders — no `.gutconfig.json` changes needed beyond ensuring `"dirs": ["res://tests/"]`.

### 5.2 TestScreenFactory

```gdscript
class_name TestScreenFactory extends RefCounted

static func create_test_game_state() -> GameState
  # Fresh state with 3 test Digimon in party, some in storage, 10000 bits

static func create_test_party(count: int = 3, level: int = 50) -> PartyState

static func create_test_inventory(bits: int = 10000) -> InventoryState
  # Includes some test items of each category

static func create_test_storage(box_count: int = 1, per_box: int = 5) -> StorageState

static func create_test_shop() -> ShopData
  # All test items at price 0

static func inject_screen_test_data() -> void
  # Calls TestBattleFactory.inject_all_test_data() + adds screen-specific data

static func create_test_encounter_table(entry_count: int = 5) -> EncounterTableData

static func create_test_zone_data() -> ZoneData

static func clear_screen_test_data() -> void
```

### 5.3 Per-Screen Test Coverage

| Screen | Unit Tests | Integration Tests |
|--------|-----------|-------------------|
| Save Screen | SaveManager metadata, mode directories | Save/load round-trip, slot overwrite, delete |
| Mode Screen | Button visibility per mode | Navigation to each screen, context passing |
| Party Screen | Reorder logic | Context menu actions, select mode filter |
| Bag Screen | Category filter, item sort | Use item flow, give item flow, toss |
| Summary Screen | Stat calculation display | Page navigation, technique swap, ability swap |
| Storage Screen | StorageState CRUD, box navigation | Deposit/withdraw, last-member guard, release |
| Shop Screen | Price calculation, buy/sell | Transaction, insufficient funds, test shop |
| Training Screen | TrainingCalculator RNG, TP deduction | Course execution, TV cap, animation complete |
| Evolution Screen | EvolutionChecker requirements | Evolve action, stat recalc, item consumption |
| Start Battle Screen | BattleConfig construction from state | Battle launch, post-battle write-back to Game.state |
| Wild Battle Test Screen | EncounterTableData save/load, format weight normalisation | Roll encounter preview, battle launch, post-battle write-back |

---

## 6. Cross-Reference: Existing Files Affected

| File | Changes |
|------|---------|
| `autoload/game.gd` | Add `screen_context`, `screen_result`, `game_mode` |
| `autoload/registry.gd` | Add `GameMode` enum |
| `autoload/atlas.gd` | Add `tamers`, `shops` dictionaries + loading |
| `scripts/systems/game/game_state.gd` | Storage migration, tamer fields, play_time |
| `scripts/systems/game/save_manager.gd` | Mode directories, metadata support |
| `scripts/systems/inventory/inventory_state.gd` | Rename `money` → `bits` |
| `scripts/systems/digimon/digimon_state.gd` | Add `training_points` |
| `scripts/systems/battle/xp_calculator.gd` | Grant TP on level-up |
| `data/config/game_balance.gd` + `.tres` | Training + storage constants |
| `ui/components/digimon_slot_panel.gd` | Add flipped sprite support |
| `scenes/main/main.gd` + `.tscn` | Title screen flow changes |
| `autoload/registry.gd` | Add `Rarity` enum |
| `autoload/atlas.gd` | Add `zones` dictionary, parse locations.json |
| `data/config/game_balance.gd` + `.tres` | Rarity weights, encounter defaults |
| `scripts/systems/battle/wild_battle_factory.gd` | New |
| `scripts/systems/world/zone_data.gd` | New |
| `data/encounter/encounter_table_data.gd` | New |
| `scenes/screens/wild_battle_test_screen.tscn` + `.gd` | New |
| `scenes/screens/mode_screen.gd` | Add "Wild Battle" button |
| `CONTEXT.md` | Document all new state classes and screen architecture |

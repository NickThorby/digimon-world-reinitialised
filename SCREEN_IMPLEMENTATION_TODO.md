# Screen Implementation Checklist

Progress tracker for [SCREEN_IMPLEMENTATION.md](SCREEN_IMPLEMENTATION.md). Tick items as completed.

---

## Phase 0 — Infrastructure

No UI — state classes, field additions, and test reorganisation.

- [x] Add `Registry.GameMode` enum — `autoload/registry.gd`
- [x] Create `StorageState` — `scripts/systems/game/storage_state.gd` (+ unit tests)
- [x] Migrate `GameState.storage` from Array to StorageState — `scripts/systems/game/game_state.gd`
- [x] Add `DigimonState.training_points` — `scripts/systems/digimon/digimon_state.gd` (+ serialisation)
- [x] Rename `InventoryState.money` to `bits` — `scripts/systems/inventory/inventory_state.gd` (+ serialisation)
- [x] Add GameBalance training/storage constants — `data/config/game_balance.gd` + `.tres`
- [x] Grant TP on level-up in `XPCalculator` — `scripts/systems/battle/xp_calculator.gd` (+ test update)
- [x] Add `Game.screen_context` / `screen_result` / `game_mode` — `autoload/game.gd`
- [x] Update `SaveManager` for mode directories + metadata — `scripts/systems/game/save_manager.gd`
- [x] Create `TamerData` resource — `data/tamer/tamer_data.gd`
- [x] Create `TamerState` — `scripts/systems/game/tamer_state.gd`
- [x] Create `ShopData` resource — `data/shop/shop_data.gd`
- [x] Create `TrainingCalculator` — `scripts/utilities/training_calculator.gd` (+ unit tests)
- [x] Create `EvolutionChecker` — `scripts/utilities/evolution_checker.gd` (+ unit tests)
- [x] Add `Atlas.tamers` and `Atlas.shops` loading — `autoload/atlas.gd`
- [x] Add `GameState.tamer_name` / `tamer_id` / `play_time` — `scripts/systems/game/game_state.gd`
- [x] Reorganise test folders — `tests/` (see §5.1)
- [x] Create `TestScreenFactory` helper — `tests/helpers/test_screen_factory.gd`
- [x] Update `CONTEXT.md` — document new state classes

## Phase 1 — Foundation Screens

- [x] **1a** Title Screen updates — `scenes/main/main.gd` + `.tscn` | depends on: SaveManager
- [x] **1b** Save Screen — `scenes/screens/save_screen.tscn` + `.gd` | depends on: SaveManager metadata
- [x] **1c** Mode Screen (Hub) — `scenes/screens/mode_screen.tscn` + `.gd` | depends on: Game.screen_context, GameMode

## Phase 2 — Core Management Screens

- [x] **2a** Party Screen — `scenes/screens/party_screen.tscn` + `.gd` | depends on: Mode Screen navigation
- [x] **2b** Bag Screen — `scenes/screens/bag_screen.tscn` + `.gd` | depends on: Mode Screen navigation
- [x] **2c** Digimon Summary Screen — `scenes/screens/summary_screen.tscn` + `.gd` | depends on: Party Screen

## Phase 3 — Advanced Screens

- [ ] **3a** Storage Screen — `scenes/screens/storage_screen.tscn` + `.gd`, `ui/components/storage_slot.tscn` + `.gd` | depends on: StorageState, Party concepts
- [ ] **3b** Shop Screen — `scenes/screens/shop_screen.tscn` + `.gd` | depends on: ShopData, Bag interaction
- [ ] **3c** Training Screen — `scenes/screens/training_screen.tscn` + `.gd` | depends on: TP, TrainingCalculator, Party select
- [ ] **3d** Evolution Screen — `scenes/screens/evolution_screen.tscn` + `.gd` | depends on: EvolutionChecker, Summary (stat display)

## Phase 4 — Battle Integration

- [ ] **4a** Start Battle Screen — `scenes/screens/start_battle_screen.tscn` + `.gd` (replaces `battle_builder`) | depends on: Mode Screen, Party Screen

## Phase 5 — Wild Battle System

- [ ] **5a** Add `Registry.Rarity` enum — `autoload/registry.gd`
- [ ] **5b** Create `ZoneData` class — `scripts/systems/world/zone_data.gd`
- [ ] **5c** Add `Atlas.zones` parsing from `locations.json` — `autoload/atlas.gd` | depends on: 5b
- [ ] **5d** Create `EncounterTableData` resource — `data/encounter/encounter_table_data.gd` | depends on: 5a
- [ ] **5e** Add GameBalance wild encounter constants — `data/config/game_balance.gd` + `.tres`
- [ ] **5f** Create `WildBattleFactory` — `scripts/systems/battle/wild_battle_factory.gd` | depends on: 5b, 5e, DigimonFactory, BattleConfig
- [ ] **5g** Create Wild Battle Test Screen — `scenes/screens/wild_battle_test_screen.tscn` + `.gd` | depends on: 5d, 5f, Mode Screen, Party Screen
- [ ] **5h** Add "Wild Battle" button to Mode Screen — `scenes/screens/mode_screen.gd` | depends on: 5g

## Integration Passes

Wire up cross-references after each phase:

- [x] After Phase 2c: add "Summary" to Party context menu
- [ ] After Phase 2b: add "Item → Give" flow from Party/Storage to Bag
- [ ] After Phase 3a: add "Storage" navigation from Mode Screen
- [ ] After Phase 3d: add "Evolution" to Party and Storage context menus

## Testing

### Test Folder Reorganisation (Phase 0)

- [x] Create `tests/battle/unit/` — move battle-specific unit tests from `tests/unit/`
- [x] Create `tests/battle/integration/` — move from `tests/integration/`
- [x] Create `tests/screens/` directory
- [x] Verify GUT recursive scan picks up all subfolders

### TestScreenFactory (Phase 0)

- [x] `create_test_game_state()` — fresh state with 3 test Digimon, storage, 10000 bits
- [x] `create_test_party()` / `create_test_inventory()` / `create_test_storage()`
- [ ] `create_test_shop()` / `create_test_encounter_table()` / `create_test_zone_data()` (shop done; encounter_table + zone_data deferred to Phase 5)
- [x] `inject_screen_test_data()` / `clear_screen_test_data()`

### Per-Screen Tests

- [x] `tests/unit/test_storage_state.gd` — CRUD, box navigation, edge cases
- [x] `tests/unit/test_training_calculator.gd` — RNG, TP deduction, TV cap
- [x] `tests/unit/test_evolution_checker.gd` — requirement checks, can_evolve
- [x] `tests/unit/test_inventory_state.gd` — bits rename verification
- [ ] `tests/unit/test_wild_battle_factory.gd` — species roll, level roll, format roll
- [ ] `tests/unit/test_zone_data.gd` — JSON parsing, level range fallback
- [x] `tests/screens/test_format_utils.gd` — format_bits, format_play_time, format_saved_at, build_party_text
- [x] `tests/screens/test_save_screen_logic.gd` — SaveManager round-trip, metadata, delete, slot isolation
- [x] `tests/screens/test_party_screen_logic.gd` — swap, take gear/consumable, select filter
- [x] `tests/screens/test_bag_screen_logic.gd` — toss, consume, use filters
- [x] `tests/screens/test_summary_screen_logic.gd` — technique equip/unequip/swap, personality colour, remove gear/consumable
- [x] `tests/screens/test_item_applicator.gd` — healing bugs fixed, outOfBattleEffect processing
- [x] `tests/unit/test_personality_override.gd` — effective key, serialisation, stat calc
- [ ] `tests/screens/test_mode_screen.gd` — button visibility per mode, navigation, context passing
- [ ] `tests/screens/test_save_screen.gd` — full save/load UI round-trip
- [ ] `tests/screens/test_party_screen.gd` — full UI reorder, context menu
- [ ] `tests/screens/test_bag_screen.gd` — full UI category filter, item sort, use/give/toss
- [ ] `tests/screens/test_summary_screen.gd` — full UI page navigation, ability swap
- [ ] `tests/screens/test_storage_screen.gd` — deposit/withdraw, last-member guard, release
- [ ] `tests/screens/test_shop_screen.gd` — price calc, buy/sell, insufficient funds, test shop
- [ ] `tests/screens/test_training_screen.gd` — course execution, TV cap, animation complete
- [ ] `tests/screens/test_evolution_screen.gd` — evolve action, stat recalc, item consumption
- [ ] `tests/screens/test_start_battle_screen.gd` — BattleConfig construction, battle launch, post-battle write-back
- [ ] `tests/screens/test_wild_battle_test_screen.gd` — encounter table save/load, format weights, roll preview, battle launch

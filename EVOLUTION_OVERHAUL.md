# Evolution System Overhaul — Specification

> **Status**: Implemented
> **Date**: 2026-02-13

---

## Data Model Changes

### DigimonState — New Fields

| Field | Type | Default | Purpose |
|---|---|---|---|
| `evolution_history` | `Array[Dictionary]` | `[]` | Chain of evolutions this Digimon has undergone. |
| `evolution_item_key` | `StringName` | `&""` | Item held due to evolution (spirit/digimental/mode change). Hidden from UI. |
| `x_antibody` | `int` | `0` | Accumulated X-Antibody value. Gained via items, checked by evo requirements. |

### History Entry Shape

```gdscript
{
    "from_key": StringName,        # Species before this evolution
    "to_key": StringName,          # Species after this evolution
    "evolution_type": int,         # Registry.EvolutionType enum value
    "evolution_item_key": StringName,  # Item consumed (armor/spirit/mode change)
    "jogress_partners": Array,     # Full DigimonState.to_dict() snapshots (jogress only)
    "synthesised": bool,           # true for factory-generated partner stubs (optional)
}
```

### Serialisation

All three fields are included in `to_dict()` and loaded via `from_dict()` with backward-compatible `.get()` defaults. Existing saves load cleanly with empty history, no item, and zero x_antibody.

---

## Evolution Execution Rules

### EvolutionExecutor

Static utility at `scripts/utilities/evolution_executor.gd`. All evolution mutations go through this class.

### Standard / X-Antibody

1. Capture old key, compute old stats
2. Mutate `digimon.key` to new species
3. Scale HP/energy proportionally
4. Learn innate techniques from new form
5. **Append** history entry (no item holding)

### Armor / Spirit

1. Same as standard, plus:
2. Extract item key from requirements (`spirit` or `digimental`)
3. Remove item from inventory, set `digimon.evolution_item_key`
4. **Append** history entry (with `evolution_item_key` populated)

### Jogress

1. Store partner snapshots (full `to_dict()`)
2. Consume partners from party/storage
3. Mutate species, scale stats, learn techniques
4. **Append** history entry (with `jogress_partners`)

### Slide / Mode Change

1. Return old held item to inventory (if any)
2. Extract new item key from requirements (may be empty = free)
3. If new item exists: remove from inventory, set `evolution_item_key`
4. Mutate species, scale stats, learn techniques
5. **Replace** last history entry (keep `from_key`, update rest)
   - If history empty: append instead

### De-digivolution

1. If `evolution_history` empty: return failure
2. Pop last entry
3. Return held item to inventory, clear `evolution_item_key`
4. Set `digimon.key` to `entry.from_key`
5. For Jogress entries: restore partners via `DigimonState.from_dict()`
   - Add to party (or first free storage slot if party full)
6. Scale HP/energy proportionally
7. Learn innate techniques from reverted form
8. Update `evolution_item_key` from new last history entry (if any)

---

## X-Antibody System

X-Antibody is now a **Digimon stat** (`digimon.x_antibody`), not an inventory count.

- Gained via items with `gain_xantibody` outOfBattleEffect brick
- Checked by `EvolutionChecker` against `digimon.x_antibody >= needed`
- Not consumed during evolution (permanent accumulation)

---

## Factory History Backfilling

`DigimonFactory.create_digimon_with_history()` generates plausible evolution chains:

1. Build reverse index: `to_key -> Array[EvolutionLinkData]`
2. Walk backward from current species to Baby I
3. At each step: 95% standard, 5% non-standard (excluding slide/mode change)
4. For jogress entries: synthesise partner Digimon (marked `synthesised: true`)
5. Set `evolution_item_key` and `x_antibody` based on history

Used by `WildBattleFactory` for wild encounter Digimon.

---

## Importer Changes

### Duplicate Path Support

Evolution keys now include type suffix: `{from}_to_{to}_{type}` (e.g. `agumon_to_greymon_standard`). Filenames follow the same pattern. This allows multiple evolution paths between the same pair (e.g. standard + jogress).

### Contract Version

Bumped to version 6. Added `mode_change` requirement type, `operator` field on `stat` requirements, `amount` field on `x_antibody` requirements.

---

## Migration Notes

- Existing saves: evolution_history will be empty, evolution_item_key empty, x_antibody 0. All backward compatible.
- Existing evolution .tres files: stale file cleanup will remove old-format filenames on next import.
- `jogress_partners` field on DigimonState is deprecated but still loaded for backward compat.

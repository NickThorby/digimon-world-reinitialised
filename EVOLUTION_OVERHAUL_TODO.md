# Evolution Overhaul — Remaining Tasks

> **Date**: 2026-02-13

---

## Game Team Tasks (this project)

- [x] Add "De-digivolve" option to party/mode screen when `digimon.evolution_history` is non-empty
- [x] Wire de-digivolution UI to `EvolutionExecutor.execute_de_digivolution()`
- [x] Add X-Antibody item(s) to item data with `gain_xantibody` outOfBattleEffect
- [x] Add digimental items with `digimental` outOfBattleEffect tag
- [x] Add spirit items with `spirit` outOfBattleEffect tag
- [x] Add mode change items with `modeChange` outOfBattleEffect tag
- [x] Add UI for viewing evolution history on Digimon summary screen
- [x] Integration test: full evolution → de-evolution round trip in editor
- [x] Integration test: wild battle factory generates Digimon with history

---

## Dex Team Tasks (digimon-dex) — DONE

- [x] Add `operator` field to `stat` evolution requirements export (default `>=`)
- [x] Add `amount` field to `x_antibody` evolution requirements export
- [x] Add `mode_change` requirement type (with optional `item` field)
- [x] Normalise `spirit` requirement to use `item` field (backward compat: old `spirit` field still accepted)
- [x] Normalise `digimental` requirement to use `item` field (backward compat: old `digimental` field still accepted)
- [x] Support `stat_highest_of` requirement on Armor/Spirit evolutions
- [x] Add mode change items as items with `modeChange` outOfBattleEffect brick
- [x] Add X-Antibody items with `gain_xantibody` outOfBattleEffect brick
- [x] Export duplicate evolution paths (same from/to, different types) as separate entries
- [x] Bump export version to 6

---

*Last Updated: 2026-02-13*

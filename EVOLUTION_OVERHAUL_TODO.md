# Evolution Overhaul — Remaining Tasks

> **Date**: 2026-02-13

---

## Game Team Tasks (this project)

- [ ] Add "De-digivolve" option to party/mode screen when `digimon.evolution_history` is non-empty
- [ ] Wire de-digivolution UI to `EvolutionExecutor.execute_de_digivolution()`
- [ ] Add X-Antibody item(s) to item data with `gain_xantibody` outOfBattleEffect
- [ ] Add digimental items with `digimental` outOfBattleEffect tag
- [ ] Add spirit items with `spirit` outOfBattleEffect tag
- [ ] Add mode change items with `modeChange` outOfBattleEffect tag
- [ ] Add UI for viewing evolution history on Digimon summary screen
- [ ] Integration test: full evolution → de-evolution round trip in editor
- [ ] Integration test: wild battle factory generates Digimon with history

---

## Dex Team Tasks (digimon-dex)

- [ ] Add `operator` field to `stat` evolution requirements export (default `>=`)
- [ ] Add `amount` field to `x_antibody` evolution requirements export
- [ ] Add `mode_change` requirement type (with optional `item` field)
- [ ] Normalise `spirit` requirement to use `item` field (backward compat: old `spirit` field still accepted)
- [ ] Normalise `digimental` requirement to use `item` field (backward compat: old `digimental` field still accepted)
- [ ] Support `stat_highest_of` requirement on Armor/Spirit evolutions
- [ ] Add mode change items as items with `modeChange` outOfBattleEffect brick
- [ ] Add X-Antibody items with `gain_xantibody` outOfBattleEffect brick
- [ ] Export duplicate evolution paths (same from/to, different types) as separate entries
- [ ] Bump export version to 6

---

*Last Updated: 2026-02-13*

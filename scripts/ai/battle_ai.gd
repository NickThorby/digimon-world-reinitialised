class_name BattleAI
extends RefCounted
## Simple AI that picks random valid moves for AI-controlled sides.


var _battle: BattleState = null


## Initialise with the current battle state.
func initialise(battle: BattleState) -> void:
	_battle = battle


## Generate actions for all active slots on a given side.
func generate_actions(side_index: int) -> Array[BattleAction]:
	var actions: Array[BattleAction] = []

	if _battle == null or side_index < 0 or side_index >= _battle.sides.size():
		return actions

	var side: SideState = _battle.sides[side_index]

	for slot: SlotState in side.slots:
		if slot.digimon == null or slot.digimon.is_fainted:
			continue

		var action: BattleAction = _pick_action(slot.digimon, side)
		if action != null:
			actions.append(action)

	return actions


## Pick a single action for a Digimon.
func _pick_action(digimon: BattleDigimonState, side: SideState) -> BattleAction:
	# Consider evolution before techniques (70% chance if available)
	if not digimon.evolved_in_battle:
		var evo_action: BattleAction = _try_evolution(digimon, side)
		if evo_action != null and _battle.rng.randf() < 0.7:
			return evo_action

	# Try to use a random technique
	var usable_techniques: Array[StringName] = _get_usable_techniques(digimon)

	if usable_techniques.size() > 0:
		var tech_key: StringName = usable_techniques[
			_battle.rng.randi() % usable_techniques.size()
		]
		var tech: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		if tech:
			var tech_action := BattleAction.new()
			tech_action.action_type = BattleAction.ActionType.TECHNIQUE
			tech_action.user_side = digimon.side_index
			tech_action.user_slot = digimon.slot_index
			tech_action.technique_key = tech_key

			# Pick a valid target
			var target: Dictionary = _pick_target(digimon, tech)
			tech_action.target_side = int(target.get("side", 0))
			tech_action.target_slot = int(target.get("slot", 0))
			return tech_action

	# Fallback to rest
	var rest_action := BattleAction.new()
	rest_action.action_type = BattleAction.ActionType.REST
	rest_action.user_side = digimon.side_index
	rest_action.user_slot = digimon.slot_index
	return rest_action


## Get techniques that can be used (equipped and not disabled/encored).
func _get_usable_techniques(digimon: BattleDigimonState) -> Array[StringName]:
	var usable: Array[StringName] = []

	# Encore forces a specific technique
	var encore_key: StringName = digimon.volatiles.get(
		"encore_technique_key", &""
	) as StringName
	if encore_key != &"" and encore_key in digimon.equipped_technique_keys:
		usable.append(encore_key)
		return usable

	var disabled_key: StringName = digimon.volatiles.get(
		"disabled_technique_key", &""
	) as StringName

	for tech_key: StringName in digimon.equipped_technique_keys:
		if tech_key == disabled_key:
			continue

		var tech: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		if tech == null:
			continue

		# Skip techniques that would cause overexertion
		if tech.energy_cost > digimon.current_energy:
			continue

		# Taunt: can only use damaging techniques
		if digimon.has_status(&"taunted"):
			if tech.technique_class == Registry.TechniqueClass.STATUS:
				continue

		usable.append(tech_key)

	return usable


## Pick a valid target for a technique.
func _pick_target(
	user: BattleDigimonState,
	technique: TechniqueData,
) -> Dictionary:
	match technique.targeting:
		Registry.Targeting.SELF:
			return {"side": user.side_index, "slot": user.slot_index}

		Registry.Targeting.SINGLE_FOE:
			return _pick_random_foe(user)

		Registry.Targeting.SINGLE_ALLY:
			return _pick_random_ally(user)

		Registry.Targeting.SINGLE_TARGET, \
		Registry.Targeting.SINGLE_OTHER:
			# Prefer foes for offensive techniques
			if technique.technique_class != Registry.TechniqueClass.STATUS:
				return _pick_random_foe(user)
			return _pick_random_foe(user)

		_:
			# Multi-target techniques don't need specific target selection
			return {"side": user.side_index, "slot": user.slot_index}


## Pick a random living foe.
func _pick_random_foe(user: BattleDigimonState) -> Dictionary:
	var foes: Array[Dictionary] = []
	for side: SideState in _battle.sides:
		if _battle.are_foes(user.side_index, side.side_index):
			for slot: SlotState in side.slots:
				if slot.digimon != null and not slot.digimon.is_fainted:
					foes.append({"side": side.side_index, "slot": slot.slot_index})

	if foes.size() > 0:
		return foes[_battle.rng.randi() % foes.size()]
	return {"side": 0, "slot": 0}


## Pick a random living ally (not self).
func _pick_random_ally(user: BattleDigimonState) -> Dictionary:
	var allies: Array[Dictionary] = []
	for side: SideState in _battle.sides:
		if _battle.are_allies(user.side_index, side.side_index):
			for slot: SlotState in side.slots:
				if slot.digimon != null and not slot.digimon.is_fainted:
					if slot.digimon != user:
						allies.append({"side": side.side_index, "slot": slot.slot_index})

	if allies.size() > 0:
		return allies[_battle.rng.randi() % allies.size()]
	return {"side": user.side_index, "slot": user.slot_index}


## Try to build an evolution action for this Digimon.
## Returns null if no evolution is available.
func _try_evolution(
	digimon: BattleDigimonState, side: SideState,
) -> BattleAction:
	var source: DigimonState = digimon.source_state
	if source == null:
		return null

	# Cannot evolve while transformed
	var transform_backup: Variant = digimon.volatiles.get("transform_backup", {})
	if transform_backup is Dictionary \
			and not (transform_backup as Dictionary).is_empty():
		return null

	var inv := InventoryState.new()
	var party := PartyState.new()
	party.members = []
	for reserve: DigimonState in side.party:
		party.members.append(reserve)

	# Check standard evolutions first
	var links: Array[EvolutionLinkData] = EvolutionService.find_available_evolutions(
		source,
	)
	for link: EvolutionLinkData in links:
		if not EvolutionChecker.can_evolve(link, source, inv, party, null):
			continue

		var action := BattleAction.new()
		action.action_type = BattleAction.ActionType.EVOLVE
		action.user_side = digimon.side_index
		action.user_slot = digimon.slot_index
		action.evolution_link_key = link.key

		# Jogress: pick first valid partner combo from reserves
		if not link.jogress_partner_keys.is_empty():
			var candidates: Dictionary = EvolutionChecker.find_jogress_candidates(
				link, source, party, null,
			)
			var partner_indices: Array[int] = []
			var all_found: bool = true
			for pkey: StringName in link.jogress_partner_keys:
				var cands: Array = candidates.get(pkey, []) as Array
				if cands.is_empty():
					all_found = false
					break
				var cand: Dictionary = cands[0]
				partner_indices.append(int(cand.get("party_index", -1)))
			if not all_found:
				continue
			action.jogress_partner_indices = partner_indices

		return action

	# Check warp evolutions
	var warps: Array[Dictionary] = EvolutionService.find_warp_evolutions(
		source, inv, party, null,
	)
	if not warps.is_empty():
		var warp: Dictionary = warps[
			_battle.rng.randi() % warps.size()
		]
		var chain: Array = warp.get("chain", [])
		var warp_keys: Array[StringName] = []
		for link_data: Variant in chain:
			if link_data is EvolutionLinkData:
				warp_keys.append((link_data as EvolutionLinkData).key)
		if not warp_keys.is_empty():
			var action := BattleAction.new()
			action.action_type = BattleAction.ActionType.EVOLVE
			action.user_side = digimon.side_index
			action.user_slot = digimon.slot_index
			action.is_warp = true
			action.warp_link_keys = warp_keys
			return action

	return null

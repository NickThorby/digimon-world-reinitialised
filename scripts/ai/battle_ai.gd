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
func _pick_action(digimon: BattleDigimonState, _side: SideState) -> BattleAction:
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

class_name BrickExecutor
extends RefCounted
## Dispatches brick dictionaries to handler functions.
## Extensible: add new brick types as match arms + handler methods.


## Execute a single brick. Returns a result dictionary (brick-type-specific).
static func execute_brick(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	var brick_type: String = brick.get("brick", "")
	match brick_type:
		"damage":
			return _execute_damage(brick, user, target, technique, battle)
		"statusEffect":
			return _execute_status_effect(brick, user, target, battle)
		"flags":
			# Consumed at import time; no runtime execution needed
			return {"handled": true}
		_:
			push_warning("BrickExecutor: Unimplemented brick type '%s'" % brick_type)
			return {"handled": false, "brick_type": brick_type}


## Execute all bricks in order. Returns array of results.
static func execute_bricks(
	bricks: Array[Dictionary],
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for brick: Dictionary in bricks:
		results.append(execute_brick(brick, user, target, technique, battle))
	return results


## --- Brick Handlers ---


## Handle "damage" brick (standard subtype).
static func _execute_damage(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	technique: TechniqueData,
	battle: BattleState,
) -> Dictionary:
	var subtype: String = brick.get("type", "standard")
	if subtype != "standard":
		push_warning("BrickExecutor: Unimplemented damage subtype '%s'" % subtype)
		return {"handled": false, "subtype": subtype}

	var damage_result: DamageResult = DamageCalculator.calculate_damage(
		user, target, technique, battle.rng,
	)

	var actual_damage: int = target.apply_damage(damage_result.final_damage)
	target.counters["times_hit"] = int(target.counters.get("times_hit", 0)) + 1

	return {
		"handled": true,
		"damage": actual_damage,
		"was_critical": damage_result.was_critical,
		"effectiveness": damage_result.effectiveness,
		"raw_damage": damage_result.raw_damage,
	}


## Handle "statusEffect" brick — apply or remove a status condition.
static func _execute_status_effect(
	brick: Dictionary,
	user: BattleDigimonState,
	target: BattleDigimonState,
	battle: BattleState,
) -> Dictionary:
	var action: String = brick.get("action", "apply")
	var status_key: StringName = StringName(brick.get("status", ""))
	var chance: float = float(brick.get("chance", 100)) / 100.0

	if status_key == &"":
		return {"handled": false, "reason": "no_status_key"}

	# Resolve target based on brick target field
	var brick_target: String = brick.get("target", "target")
	var actual_target: BattleDigimonState = target
	if brick_target == "self":
		actual_target = user

	if action == "remove":
		actual_target.remove_status(status_key)
		return {"handled": true, "action": "remove", "status": status_key}

	# Apply with chance check
	if battle.rng.randf() > chance:
		return {"handled": true, "action": "apply", "missed": true, "status": status_key}

	# Status override rules
	_apply_status_overrides(actual_target, status_key)

	var duration: int = brick.get("duration", -1)
	var extra: Dictionary = {}
	if brick.has("extra"):
		extra = brick["extra"] as Dictionary

	var applied: bool = actual_target.add_status(status_key, duration, extra)

	return {
		"handled": true,
		"action": "apply",
		"applied": applied,
		"status": status_key,
	}


## Apply status override rules (Burned removes Frostbitten/Frozen, etc.).
static func _apply_status_overrides(
	target: BattleDigimonState,
	new_status: StringName,
) -> void:
	match str(new_status).to_lower():
		"burned":
			target.remove_status(&"frostbitten")
			target.remove_status(&"frozen")
		"frostbitten":
			target.remove_status(&"burned")
			# Frostbitten on already Frostbitten -> upgrade to Frozen
			if target.has_status(&"frostbitten"):
				target.remove_status(&"frostbitten")
				target.add_status(&"frozen")

class_name GearData
extends ItemData
## Equipable gear item with a designated slot. Inherits bricks from ItemData.

@export var gear_slot: _Reg.GearSlot = _Reg.GearSlot.EQUIPABLE
@export var trigger: _Reg.AbilityTrigger = _Reg.AbilityTrigger.CONTINUOUS
@export var stack_limit: _Reg.StackLimit = _Reg.StackLimit.UNLIMITED
@export var trigger_condition: String = ""

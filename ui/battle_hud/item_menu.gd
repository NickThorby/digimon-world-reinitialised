class_name ItemMenu
extends PanelContainer
## Shows combat-usable items with quantities. Emits selection.


signal item_chosen(item_key: StringName)
signal back_pressed

@onready var _item_container: VBoxContainer = $VBox/ScrollContainer/ItemContainer
@onready var _back_button: Button = $VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Populate with combat-usable items from the bag.
func populate(bag: BagState) -> void:
	for child: Node in _item_container.get_children():
		child.queue_free()

	if bag == null:
		return

	var items: Array[Dictionary] = bag.get_combat_usable_items()
	for entry: Dictionary in items:
		var key: StringName = entry.get("key", &"") as StringName
		var quantity: int = int(entry.get("quantity", 0))
		var item: ItemData = Atlas.items.get(key) as ItemData
		if item == null:
			continue

		var button := Button.new()
		button.text = "%s  x%d" % [item.name, quantity]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(
			func() -> void: item_chosen.emit(key)
		)
		_item_container.add_child(button)

extends Control
## Save Screen — handles save, load, and slot selection.

const MODE_SCREEN_PATH := "res://scenes/screens/mode_screen.tscn"
const SLOT_NAMES: Array[String] = ["slot_1", "slot_2", "slot_3"]

var _action: String = "select"
var _mode: Registry.GameMode = Registry.GameMode.TEST
var _return_scene: String = "res://scenes/main/main.tscn"

@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/BackButton
@onready var _title_label: Label = $MarginContainer/VBox/HeaderBar/TitleLabel
@onready var _slot_container: VBoxContainer = $MarginContainer/VBox/SlotContainer


func _ready() -> void:
	_action = Game.screen_context.get("action", "select")
	_mode = Game.screen_context.get("mode", Registry.GameMode.TEST)
	_return_scene = Game.screen_context.get(
		"return_scene", "res://scenes/main/main.tscn"
	)

	match _action:
		"save":
			_title_label.text = tr("Save Game")
		"load":
			_title_label.text = tr("Load Game")
		_:
			_title_label.text = tr("Select Slot")

	_back_button.pressed.connect(_on_back)

	for i: int in SLOT_NAMES.size():
		_rebuild_slot(i)


func _rebuild_slot(slot_idx: int) -> void:
	var panel: PanelContainer = _slot_container.get_child(slot_idx)
	# Clear existing children.
	for child: Node in panel.get_children():
		child.queue_free()

	var meta: Dictionary = SaveManager.get_save_metadata(
		SLOT_NAMES[slot_idx], _mode
	)
	var occupied: bool = not meta.is_empty()

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 12)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(panel_margin)

	var hbox := HBoxContainer.new()
	panel_margin.add_child(hbox)

	if occupied:
		_build_occupied_slot(hbox, slot_idx, meta)
	else:
		_build_empty_slot(hbox, slot_idx)


func _build_occupied_slot(
	hbox: HBoxContainer, slot_idx: int, meta: Dictionary,
) -> void:
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var tamer_label := Label.new()
	tamer_label.text = meta.get("tamer_name", "Unknown")
	tamer_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(tamer_label)

	var party_label := Label.new()
	party_label.text = FormatUtils.build_party_text(meta)
	party_label.add_theme_font_size_override("font_size", 13)
	party_label.add_theme_color_override(
		"font_color", Color(0.631, 0.631, 0.667, 1)
	)
	info_vbox.add_child(party_label)

	var time_label := Label.new()
	var play_time_str: String = FormatUtils.format_play_time(
		meta.get("play_time", 0)
	)
	var saved_at_str: String = FormatUtils.format_saved_at(
		meta.get("saved_at", 0.0)
	)
	time_label.text = "Play Time: %s  |  Saved: %s" % [
		play_time_str, saved_at_str,
	]
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override(
		"font_color", Color(0.443, 0.443, 0.478, 1)
	)
	info_vbox.add_child(time_label)

	var button_vbox := VBoxContainer.new()
	button_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	button_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(button_vbox)

	match _action:
		"save":
			var save_btn := Button.new()
			save_btn.text = tr("Save")
			save_btn.custom_minimum_size = Vector2(100, 0)
			save_btn.pressed.connect(_on_save.bind(slot_idx))
			button_vbox.add_child(save_btn)

			var delete_btn := Button.new()
			delete_btn.text = tr("Delete")
			delete_btn.custom_minimum_size = Vector2(100, 0)
			delete_btn.pressed.connect(_on_delete.bind(slot_idx))
			button_vbox.add_child(delete_btn)
		"load":
			var load_btn := Button.new()
			load_btn.text = tr("Load")
			load_btn.custom_minimum_size = Vector2(100, 0)
			load_btn.pressed.connect(_on_load.bind(slot_idx))
			button_vbox.add_child(load_btn)

			var delete_btn := Button.new()
			delete_btn.text = tr("Delete")
			delete_btn.custom_minimum_size = Vector2(100, 0)
			delete_btn.pressed.connect(_on_delete.bind(slot_idx))
			button_vbox.add_child(delete_btn)
		"select":
			var load_btn := Button.new()
			load_btn.text = tr("Load")
			load_btn.custom_minimum_size = Vector2(100, 0)
			load_btn.pressed.connect(_on_load.bind(slot_idx))
			button_vbox.add_child(load_btn)

			var delete_btn := Button.new()
			delete_btn.text = tr("Delete")
			delete_btn.custom_minimum_size = Vector2(100, 0)
			delete_btn.pressed.connect(_on_delete.bind(slot_idx))
			button_vbox.add_child(delete_btn)


func _build_empty_slot(hbox: HBoxContainer, slot_idx: int) -> void:
	var empty_label := Label.new()
	empty_label.text = tr("Empty Slot")
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_label.add_theme_color_override(
		"font_color", Color(0.443, 0.443, 0.478, 1)
	)
	hbox.add_child(empty_label)

	var button_vbox := VBoxContainer.new()
	button_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(button_vbox)

	match _action:
		"save":
			var save_btn := Button.new()
			save_btn.text = tr("Save")
			save_btn.custom_minimum_size = Vector2(100, 0)
			save_btn.pressed.connect(_on_save.bind(slot_idx))
			button_vbox.add_child(save_btn)
		"select":
			var new_btn := Button.new()
			new_btn.text = tr("New Game")
			new_btn.custom_minimum_size = Vector2(100, 0)
			new_btn.pressed.connect(_on_new_game.bind(slot_idx))
			button_vbox.add_child(new_btn)
		# "load" — no buttons on empty slots


func _on_save(slot_idx: int) -> void:
	var meta: Dictionary = SaveManager.get_save_metadata(
		SLOT_NAMES[slot_idx], _mode
	)
	if not meta.is_empty():
		_show_confirm(
			"Overwrite Save",
			"Are you sure you want to overwrite this save?",
			func() -> void: _do_save(slot_idx),
		)
	else:
		_do_save(slot_idx)


func _do_save(slot_idx: int) -> void:
	Game.save_game(SLOT_NAMES[slot_idx])
	_rebuild_slot(slot_idx)


func _on_load(slot_idx: int) -> void:
	Game.load_game(SLOT_NAMES[slot_idx])
	Game.game_mode = _mode
	SceneManager.change_scene(MODE_SCREEN_PATH)


func _on_new_game(_slot_idx: int) -> void:
	Game.new_game()
	Game.game_mode = _mode
	SceneManager.change_scene(MODE_SCREEN_PATH)


func _on_delete(slot_idx: int) -> void:
	_show_confirm(
		"Delete Save",
		"Are you sure you want to delete this save? This cannot be undone.",
		func() -> void:
			SaveManager.delete_save(SLOT_NAMES[slot_idx], _mode)
			_rebuild_slot(slot_idx),
	)


func _on_back() -> void:
	SceneManager.change_scene(_return_scene)


func _show_confirm(
	title: String, message: String, on_confirm: Callable,
) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.confirmed.connect(func() -> void:
		on_confirm.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()



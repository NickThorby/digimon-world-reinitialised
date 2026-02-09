class_name TeamSavePopup
extends Window
## Popup for saving, loading, overwriting, and deleting builder teams.


signal team_loaded(team: BuilderTeamState)
signal team_saved(slot_name: String, team_name: String)
signal cancelled

enum PopupMode { SAVE, LOAD }

@onready var _save_row: HBoxContainer = $MarginContainer/VBox/SaveRow
@onready var _name_edit: LineEdit = $MarginContainer/VBox/SaveRow/NameEdit
@onready var _save_new_button: Button = $MarginContainer/VBox/SaveRow/SaveNewButton
@onready var _header_label: Label = $MarginContainer/VBox/HeaderLabel
@onready var _scroll: ScrollContainer = $MarginContainer/VBox/ScrollContainer
@onready var _team_list: VBoxContainer = $MarginContainer/VBox/ScrollContainer/TeamList
@onready var _empty_label: Label = $MarginContainer/VBox/EmptyLabel
@onready var _cancel_button: Button = $MarginContainer/VBox/BottomRow/CancelButton

var _mode: PopupMode = PopupMode.LOAD
var _team_to_save: BuilderTeamState = null


func _ready() -> void:
	_save_new_button.pressed.connect(_on_save_new)
	_cancel_button.pressed.connect(_on_cancel)
	close_requested.connect(_on_cancel)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_save_new())


## Open in the given mode. For SAVE mode, pass the team to save.
func setup(mode: PopupMode, team: BuilderTeamState = null) -> void:
	_mode = mode
	_team_to_save = team
	title = "Save Team" if mode == PopupMode.SAVE else "Load Team"
	_save_row.visible = (mode == PopupMode.SAVE)
	if mode == PopupMode.SAVE and team:
		_name_edit.text = team.name if team.name != "" else ""
		_name_edit.placeholder_text = "Enter team name..."
	_refresh_list()


func _refresh_list() -> void:
	for child: Node in _team_list.get_children():
		child.queue_free()

	var summaries: Array[Dictionary] = BuilderSaveManager.get_team_summaries()
	_empty_label.visible = summaries.is_empty()
	_scroll.visible = not summaries.is_empty()

	for summary: Dictionary in summaries:
		_add_team_row(summary)


func _add_team_row(summary: Dictionary) -> void:
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = summary["name"] as String
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	var members_label := Label.new()
	var member_names: Array = summary["member_names"] as Array
	members_label.text = ", ".join(member_names) if member_names.size() > 0 else "Empty team"
	members_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(members_label)

	var saved_at: int = summary["saved_at"] as int
	if saved_at > 0:
		var date_label := Label.new()
		var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(saved_at)
		date_label.text = "Saved: %02d/%02d/%d %02d:%02d" % [
			datetime["day"], datetime["month"], datetime["year"],
			datetime["hour"], datetime["minute"],
		]
		date_label.add_theme_font_size_override("font_size", 12)
		date_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		info_vbox.add_child(date_label)

	hbox.add_child(info_vbox)

	# Button column
	var button_vbox := VBoxContainer.new()

	var slot: String = summary["slot"] as String
	if _mode == PopupMode.LOAD:
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.pressed.connect(_on_load_slot.bind(slot))
		button_vbox.add_child(load_button)
	else:
		var overwrite_button := Button.new()
		overwrite_button.text = "Overwrite"
		overwrite_button.pressed.connect(_on_overwrite_slot.bind(slot, summary["name"] as String))
		button_vbox.add_child(overwrite_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_on_delete_slot.bind(slot))
	button_vbox.add_child(delete_button)

	hbox.add_child(button_vbox)
	_team_list.add_child(panel)


func _on_save_new() -> void:
	if _team_to_save == null:
		return
	var display_name: String = _name_edit.text.strip_edges()
	if display_name == "":
		display_name = "Unnamed Team"
	_team_to_save.name = display_name
	var slot: String = BuilderSaveManager.sanitise_slot_name(display_name)
	BuilderSaveManager.save_team(_team_to_save, slot)
	team_saved.emit(slot, display_name)
	hide()


func _on_load_slot(slot: String) -> void:
	var team: BuilderTeamState = BuilderSaveManager.load_team(slot)
	if team:
		team_loaded.emit(team)
		hide()


func _on_overwrite_slot(slot: String, team_name: String) -> void:
	if _team_to_save == null:
		return
	_team_to_save.name = team_name
	BuilderSaveManager.save_team(_team_to_save, slot)
	team_saved.emit(slot, team_name)
	hide()


func _on_delete_slot(slot: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Delete this saved team?"
	dialog.confirmed.connect(func() -> void:
		BuilderSaveManager.delete_team(slot)
		_refresh_list()
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()


func _on_cancel() -> void:
	cancelled.emit()
	hide()

extends Control
## Wild Battle Test Screen — configure encounter tables and launch wild battles
## using the player's current party from Game.state.
## Allows building custom encounter tables, adjusting format weights, setting
## field effects, rolling encounters with preview, and quick-launching battles.

const WILD_BATTLE_SCREEN_PATH := "res://scenes/screens/wild_battle_test_screen.tscn"
const BATTLE_SCENE_PATH := "res://scenes/battle/battle_scene.tscn"
const PICKER_SCENE_PATH := "res://scenes/battle/digimon_picker.tscn"
const SLOT_PANEL_SCENE := preload("res://ui/components/digimon_slot_panel.tscn")
const ENCOUNTER_TABLES_DIR := "user://encounter_tables/"

# --- Left panel ---

@onready var _encounter_list: VBoxContainer = $MarginContainer/VBox/HSplit/LeftPanel/EncounterScroll/EncounterList
@onready var _add_digimon_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/AddDigimonButton
@onready var _save_table_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TableButtonRow/SaveTableButton
@onready var _load_table_button: Button = $MarginContainer/VBox/HSplit/LeftPanel/TableButtonRow/LoadTableButton
@onready var _min_level_spin: SpinBox = $MarginContainer/VBox/HSplit/LeftPanel/ZoneLevelRow/MinLevelSpin
@onready var _max_level_spin: SpinBox = $MarginContainer/VBox/HSplit/LeftPanel/ZoneLevelRow/MaxLevelSpin
@onready var _player_team_list: VBoxContainer = $MarginContainer/VBox/HSplit/LeftPanel/PlayerTeamList

# --- Right panel ---

# Format tab
@onready var _singles_spin: SpinBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Format/SinglesRow/SinglesSpin
@onready var _doubles_spin: SpinBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Format/DoublesRow/DoublesSpin
@onready var _triples_spin: SpinBox = $MarginContainer/VBox/HSplit/RightPanel/RightTabs/Format/TriplesRow/TriplesSpin

# Field Effects tab
@onready var _weather_option: OptionButton = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/WeatherRow/WeatherOption"
@onready var _weather_permanent: CheckBox = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/WeatherRow/WeatherPermanent"
@onready var _terrain_option: OptionButton = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/TerrainRow/TerrainOption"
@onready var _terrain_permanent: CheckBox = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/TerrainRow/TerrainPermanent"
@onready var _global_effects_list: VBoxContainer = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Field Effects/FieldContent/GlobalEffectsList"

# Side Presets tab
@onready var _side_preset_selector: TabBar = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Side Presets/SidePresetContent/SidePresetSelector"
@onready var _side_effects_list: VBoxContainer = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Side Presets/SidePresetContent/SideEffectsList"
@onready var _hazards_list: VBoxContainer = $"MarginContainer/VBox/HSplit/RightPanel/RightTabs/Side Presets/SidePresetContent/HazardsList"

# Preview panel
@onready var _preview_panel: PanelContainer = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel
@onready var _preview_content: RichTextLabel = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewVBox/PreviewContent
@onready var _accept_button: Button = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewVBox/PreviewButtonRow/AcceptButton
@onready var _reroll_button: Button = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewVBox/PreviewButtonRow/RerollButton
@onready var _cancel_preview_button: Button = $MarginContainer/VBox/HSplit/RightPanel/PreviewPanel/PreviewVBox/PreviewButtonRow/CancelPreviewButton

# Bottom bar
@onready var _roll_button: Button = $MarginContainer/VBox/BottomBar/RollButton
@onready var _quick_battle_button: Button = $MarginContainer/VBox/BottomBar/QuickBattleButton
@onready var _back_button: Button = $MarginContainer/VBox/HeaderBar/BackButton
@onready var _validation_label: RichTextLabel = $MarginContainer/VBox/HSplit/RightPanel/ValidationLabel

# --- State ---

## Encounter table entries: Array of { digimon_key, rarity, min_level, max_level }
var _entries: Array[Dictionary] = []
var _balance: GameBalance = null
var _mode: Registry.GameMode = Registry.GameMode.TEST
var _return_scene: String = "res://scenes/screens/mode_screen.tscn"
var _rng := RandomNumberGenerator.new()
var _preview_config: BattleConfig = null

## Per-side preset state. Key = side_index, value = { side_effects: {}, hazards: {} }
var _side_presets: Dictionary = {}
var _current_preset_side: int = 0

## Rarity option labels for the dropdown.
const _RARITY_NAMES: Array[String] = [
	"Common", "Uncommon", "Rare", "Very Rare", "Legendary",
]


func _ready() -> void:
	MusicManager.play("res://assets/audio/music/07. Save Screen.mp3")
	_balance = load("res://data/config/game_balance.tres") as GameBalance
	_rng.randomize()

	_read_context()

	var returning_from_battle: bool = Game.builder_context.size() > 0
	var returning_from_picker: bool = Game.picker_context.size() > 0

	if returning_from_battle:
		_restore_from_battle()
	elif returning_from_picker:
		_restore_from_picker()

	_connect_signals()
	_setup_field_effect_options()
	_init_side_presets()
	_update_side_preset_selector()
	_build_player_preview()
	_update_encounter_list_display()
	_update_side_presets_display()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_return_scene = ctx.get("return_scene", "res://scenes/screens/mode_screen.tscn")


# --- Player Side (read-only) ---


func _build_player_preview() -> void:
	for child: Node in _player_team_list.get_children():
		child.queue_free()

	if Game.state == null or Game.state.party.members.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No Digimon in party."
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.add_theme_color_override(
			"font_color", Color(0.631, 0.631, 0.667, 1)
		)
		_player_team_list.add_child(placeholder)
		return

	for i: int in Game.state.party.members.size():
		var member: DigimonState = Game.state.party.members[i]
		var data: DigimonData = Atlas.digimon.get(member.key) as DigimonData
		var display: String = data.display_name if data else str(member.key)
		var label := Label.new()
		label.text = "%s Lv.%d" % [display, member.level]
		label.add_theme_font_size_override("font_size", 14)
		_player_team_list.add_child(label)


# --- Restore from battle/picker ---


func _restore_from_battle() -> void:
	var ctx: Dictionary = Game.builder_context
	Game.builder_context = {}

	if ctx.has("entries"):
		_entries = ctx["entries"] as Array[Dictionary]
	_current_preset_side = int(ctx.get("current_preset_side", 0))
	if ctx.has("side_presets"):
		_side_presets = ctx["side_presets"] as Dictionary

	# Sync consumed items back to inventory
	if ctx.has("pre_battle_inventory") and Game.state != null:
		var snapshot: Dictionary = ctx["pre_battle_inventory"] as Dictionary
		if ctx.has("config"):
			var config: BattleConfig = ctx["config"] as BattleConfig
			var player_bag: Variant = config.side_configs[0].get("bag") \
				if config.side_configs.size() > 0 else null
			if player_bag is BagState:
				BagState.sync_to_inventory(
					player_bag as BagState, Game.state.inventory, snapshot
				)

	_restore_party_energy()

	# Restore format weights
	if ctx.has("format_weights"):
		var fw: Dictionary = ctx["format_weights"] as Dictionary
		_singles_spin.value = fw.get(
			BattleConfig.FormatPreset.SINGLES_1V1, 85
		)
		_doubles_spin.value = fw.get(
			BattleConfig.FormatPreset.DOUBLES_2V2, 15
		)
		_triples_spin.value = fw.get(
			BattleConfig.FormatPreset.TRIPLES_3V3, 0
		)

	# Restore level range
	if ctx.has("default_min_level"):
		_min_level_spin.value = ctx["default_min_level"]
	if ctx.has("default_max_level"):
		_max_level_spin.value = ctx["default_max_level"]


func _restore_party_energy() -> void:
	if Game.state == null:
		return
	for member: DigimonState in Game.state.party.members:
		var data: DigimonData = Atlas.digimon.get(member.key) as DigimonData
		if data == null:
			continue
		var stats: Dictionary = StatCalculator.calculate_all_stats(data, member)
		var personality: PersonalityData = Atlas.personalities.get(
			member.personality_key,
		) as PersonalityData
		var max_energy: int = StatCalculator.apply_personality(
			stats.get(&"energy", 1), &"energy", personality,
		)
		member.current_energy = max_energy


func _restore_from_picker() -> void:
	var ctx: Dictionary = Game.picker_context
	var result: Variant = Game.picker_result
	Game.picker_result = null
	Game.picker_context = {}

	if ctx.has("entries"):
		_entries = ctx["entries"] as Array[Dictionary]
	_current_preset_side = int(ctx.get("current_preset_side", 0))
	if ctx.has("side_presets"):
		_side_presets = ctx["side_presets"] as Dictionary

	# Restore format weights
	if ctx.has("format_weights"):
		var fw: Dictionary = ctx["format_weights"] as Dictionary
		_singles_spin.value = fw.get(
			BattleConfig.FormatPreset.SINGLES_1V1, 85
		)
		_doubles_spin.value = fw.get(
			BattleConfig.FormatPreset.DOUBLES_2V2, 15
		)
		_triples_spin.value = fw.get(
			BattleConfig.FormatPreset.TRIPLES_3V3, 0
		)

	# Restore level range
	if ctx.has("default_min_level"):
		_min_level_spin.value = ctx["default_min_level"]
	if ctx.has("default_max_level"):
		_max_level_spin.value = ctx["default_max_level"]

	if result == null or result is not DigimonState:
		return

	var state: DigimonState = result as DigimonState
	_entries.append({
		"digimon_key": state.key,
		"rarity": Registry.Rarity.COMMON,
		"min_level": -1,
		"max_level": -1,
	})


# --- Signals ---


func _connect_signals() -> void:
	_add_digimon_button.pressed.connect(_on_add_digimon)
	_save_table_button.pressed.connect(_on_save_table)
	_load_table_button.pressed.connect(_on_load_table)
	_roll_button.pressed.connect(_on_roll_encounter)
	_quick_battle_button.pressed.connect(_on_quick_battle)
	_back_button.pressed.connect(_on_back)
	_accept_button.pressed.connect(_on_accept_preview)
	_reroll_button.pressed.connect(_on_roll_encounter)
	_cancel_preview_button.pressed.connect(_on_cancel_preview)
	_side_preset_selector.tab_changed.connect(_on_preset_side_selected)


# --- Encounter Table ---


func _update_encounter_list_display() -> void:
	for child: Node in _encounter_list.get_children():
		child.queue_free()

	if _entries.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No encounters added.\nClick 'Add Digimon' to add entries."
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.add_theme_color_override(
			"font_color", Color(0.631, 0.631, 0.667, 1)
		)
		_encounter_list.add_child(placeholder)
		return

	for i: int in _entries.size():
		var entry: Dictionary = _entries[i]
		var row := _create_encounter_entry_row(i, entry)
		_encounter_list.add_child(row)


func _create_encounter_entry_row(index: int, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name label
	var key: StringName = entry.get("digimon_key", &"")
	var data: DigimonData = Atlas.digimon.get(key) as DigimonData
	var display: String = data.display_name if data else str(key)
	var name_label := Label.new()
	name_label.text = display
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	# Rarity dropdown
	var rarity_option := OptionButton.new()
	rarity_option.custom_minimum_size = Vector2(100, 0)
	for rarity_name: String in _RARITY_NAMES:
		rarity_option.add_item(rarity_name)
	rarity_option.selected = int(entry.get("rarity", Registry.Rarity.COMMON))
	var idx: int = index
	rarity_option.item_selected.connect(func(sel: int) -> void:
		_entries[idx]["rarity"] = sel
	)
	row.add_child(rarity_option)

	# Level range spinners
	var min_spin := SpinBox.new()
	min_spin.min_value = -1
	min_spin.max_value = 100
	min_spin.value = int(entry.get("min_level", -1))
	min_spin.custom_minimum_size = Vector2(60, 0)
	min_spin.tooltip_text = "Min Level (-1 = default)"
	min_spin.value_changed.connect(func(val: float) -> void:
		_entries[idx]["min_level"] = int(val)
	)
	row.add_child(min_spin)

	var max_spin := SpinBox.new()
	max_spin.min_value = -1
	max_spin.max_value = 100
	max_spin.value = int(entry.get("max_level", -1))
	max_spin.custom_minimum_size = Vector2(60, 0)
	max_spin.tooltip_text = "Max Level (-1 = default)"
	max_spin.value_changed.connect(func(val: float) -> void:
		_entries[idx]["max_level"] = int(val)
	)
	row.add_child(max_spin)

	# Remove button
	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.custom_minimum_size = Vector2(30, 0)
	remove_button.pressed.connect(func() -> void:
		_entries.remove_at(idx)
		_update_encounter_list_display()
	)
	row.add_child(remove_button)

	return row


func _on_add_digimon() -> void:
	_save_side_presets()
	Game.picker_context = {
		"species_only": true,
		"add_button_text": "Add to Encounter Table",
		"entries": _entries.duplicate(true),
		"side_presets": _side_presets.duplicate(true),
		"current_preset_side": _current_preset_side,
		"format_weights": _get_format_weights(),
		"default_min_level": int(_min_level_spin.value),
		"default_max_level": int(_max_level_spin.value),
		"return_scene": WILD_BATTLE_SCREEN_PATH,
	}
	Game.picker_result = null
	SceneManager.change_scene(PICKER_SCENE_PATH)


# --- Build ZoneData from UI state ---


func _build_zone_from_ui() -> ZoneData:
	var zone := ZoneData.new()
	zone.key = &"custom_encounter"
	zone.name = "Custom Encounter"
	zone.default_min_level = int(_min_level_spin.value)
	zone.default_max_level = int(_max_level_spin.value)
	zone.format_weights = _get_format_weights()
	zone.encounter_entries = _entries.duplicate(true)
	return zone


func _get_format_weights() -> Dictionary:
	var weights: Dictionary = {}
	if int(_singles_spin.value) > 0:
		weights[BattleConfig.FormatPreset.SINGLES_1V1] = int(_singles_spin.value)
	if int(_doubles_spin.value) > 0:
		weights[BattleConfig.FormatPreset.DOUBLES_2V2] = int(_doubles_spin.value)
	if int(_triples_spin.value) > 0:
		weights[BattleConfig.FormatPreset.TRIPLES_3V3] = int(_triples_spin.value)
	return weights


# --- Roll / Quick Battle ---


func _on_roll_encounter() -> void:
	if _entries.is_empty():
		_show_validation_message("[color=red]Add at least one Digimon to the encounter table.[/color]")
		return
	if Game.state == null or Game.state.party.members.is_empty():
		_show_validation_message("[color=red]No Digimon in party.[/color]")
		return

	var zone: ZoneData = _build_zone_from_ui()
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	var bag: BagState = BagState.from_inventory(Game.state.inventory)

	_preview_config = WildBattleFactory.create_encounter(
		zone, player_party, bag, _rng
	)

	# Apply field effects
	_apply_field_effects_to_config(_preview_config)
	_save_side_presets()
	_apply_side_presets_to_config(_preview_config)

	_show_preview()


func _on_quick_battle() -> void:
	if _entries.is_empty():
		_show_validation_message("[color=red]Add at least one Digimon to the encounter table.[/color]")
		return
	if Game.state == null or Game.state.party.members.is_empty():
		_show_validation_message("[color=red]No Digimon in party.[/color]")
		return

	var zone: ZoneData = _build_zone_from_ui()
	var player_party: Array[DigimonState] = []
	for member: DigimonState in Game.state.party.members:
		player_party.append(member)
	var bag: BagState = BagState.from_inventory(Game.state.inventory)

	var config: BattleConfig = WildBattleFactory.create_encounter(
		zone, player_party, bag, _rng
	)

	_apply_field_effects_to_config(config)
	_save_side_presets()
	_apply_side_presets_to_config(config)

	_launch_battle(config)


func _on_accept_preview() -> void:
	if _preview_config != null:
		_launch_battle(_preview_config)


func _on_cancel_preview() -> void:
	_preview_config = null
	_preview_panel.visible = false
	_clear_validation()


# --- Preview ---


func _show_preview() -> void:
	if _preview_config == null:
		return

	_preview_panel.visible = true

	var text := ""
	var format_name: String = _get_format_name(_preview_config.format_preset)
	text += "[b]Format:[/b] %s\n" % format_name

	if _preview_config.side_configs.size() > 1:
		var wild_party: Array = _preview_config.side_configs[1].get("party", [])
		text += "[b]Wild Digimon:[/b]\n"
		for digimon: Variant in wild_party:
			if digimon is DigimonState:
				var state: DigimonState = digimon as DigimonState
				var data: DigimonData = Atlas.digimon.get(state.key) as DigimonData
				var display: String = data.display_name if data else str(state.key)
				text += "  %s Lv.%d\n" % [display, state.level]

	_preview_content.text = text


func _get_format_name(preset: BattleConfig.FormatPreset) -> String:
	match preset:
		BattleConfig.FormatPreset.SINGLES_1V1: return "Singles 1v1"
		BattleConfig.FormatPreset.DOUBLES_2V2: return "Doubles 2v2"
		BattleConfig.FormatPreset.TRIPLES_3V3: return "Triples 3v3"
		_: return "Unknown"


# --- Launch battle ---


func _launch_battle(config: BattleConfig) -> void:
	var errors: Array[String] = config.validate()
	if errors.size() > 0:
		_show_validation_errors(errors)
		return

	# Snapshot inventory before battle
	var pre_battle_inventory: Dictionary = {}
	if Game.state != null:
		pre_battle_inventory = Game.state.inventory.items.duplicate()

	_save_side_presets()

	Game.builder_context = {
		"config": config,
		"entries": _entries.duplicate(true),
		"side_presets": _side_presets.duplicate(true),
		"current_preset_side": _current_preset_side,
		"format_weights": _get_format_weights(),
		"default_min_level": int(_min_level_spin.value),
		"default_max_level": int(_max_level_spin.value),
		"return_scene": WILD_BATTLE_SCREEN_PATH,
		"pre_battle_inventory": pre_battle_inventory,
	}

	Game.battle_config = config
	SceneManager.change_scene(BATTLE_SCENE_PATH)


# --- Navigation ---


func _on_back() -> void:
	SceneManager.change_scene(_return_scene)


# --- Save / Load encounter table ---


func _on_save_table() -> void:
	if _entries.is_empty():
		_show_validation_message("No entries to save.")
		return

	var table := EncounterTableData.new()
	table.key = StringName("custom_%d" % Time.get_unix_time_from_system())
	table.name = "Custom Table"
	table.default_min_level = int(_min_level_spin.value)
	table.default_max_level = int(_max_level_spin.value)
	table.format_weights = _get_format_weights()
	table.entries = _entries.duplicate(true)

	DirAccess.make_dir_recursive_absolute(ENCOUNTER_TABLES_DIR)
	var save_path: String = ENCOUNTER_TABLES_DIR + str(table.key) + ".tres"
	var err: Error = ResourceSaver.save(table, save_path)
	if err == OK:
		_show_validation_message("Saved encounter table.")
	else:
		_show_validation_message("[color=red]Failed to save encounter table.[/color]")


func _on_load_table() -> void:
	var dir := DirAccess.open(ENCOUNTER_TABLES_DIR)
	if dir == null:
		_show_validation_message("No saved tables found.")
		return

	# Load the most recent table file
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.is_empty():
		_show_validation_message("No saved tables found.")
		return

	files.sort()
	var load_path: String = ENCOUNTER_TABLES_DIR + files[files.size() - 1]
	var table: EncounterTableData = load(load_path) as EncounterTableData
	if table == null:
		_show_validation_message("[color=red]Failed to load encounter table.[/color]")
		return

	_entries = table.entries.duplicate(true)
	_min_level_spin.value = table.default_min_level
	_max_level_spin.value = table.default_max_level

	# Restore format weights
	_singles_spin.value = table.format_weights.get(
		BattleConfig.FormatPreset.SINGLES_1V1, 0
	)
	_doubles_spin.value = table.format_weights.get(
		BattleConfig.FormatPreset.DOUBLES_2V2, 0
	)
	_triples_spin.value = table.format_weights.get(
		BattleConfig.FormatPreset.TRIPLES_3V3, 0
	)

	_update_encounter_list_display()
	_show_validation_message("Loaded '%s' (%d entries)." % [table.name, _entries.size()])


# --- Validation ---


func _show_validation_errors(errors: Array[String]) -> void:
	_validation_label.text = "[color=red]" + "\n".join(errors) + "[/color]"


func _show_validation_message(msg: String) -> void:
	_validation_label.text = msg


func _clear_validation() -> void:
	_validation_label.text = ""


# --- Field Effects (same pattern as start_battle_screen) ---


func _setup_field_effect_options() -> void:
	_weather_option.clear()
	_weather_option.add_item("None")
	for weather_key: StringName in Registry.WEATHER_TYPES:
		_weather_option.add_item(str(weather_key).capitalize())
	_weather_permanent.button_pressed = true

	_terrain_option.clear()
	_terrain_option.add_item("None")
	for terrain_key: StringName in Registry.TERRAIN_TYPES:
		_terrain_option.add_item(str(terrain_key).capitalize())
	_terrain_permanent.button_pressed = true

	_build_global_effects_list()


func _build_global_effects_list() -> void:
	for child: Node in _global_effects_list.get_children():
		child.queue_free()
	for key: StringName in Registry.GLOBAL_EFFECT_TYPES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := CheckBox.new()
		toggle.text = str(key).replace("_", " ").capitalize()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(toggle)
		var perm := CheckBox.new()
		perm.text = "Perm"
		perm.button_pressed = true
		row.add_child(perm)
		_global_effects_list.add_child(row)


func _apply_field_effects_to_config(config: BattleConfig) -> void:
	var presets: Dictionary = {}

	var weather_idx: int = _weather_option.selected
	if weather_idx > 0 and weather_idx - 1 < Registry.WEATHER_TYPES.size():
		presets["weather"] = {
			"key": Registry.WEATHER_TYPES[weather_idx - 1],
			"permanent": _weather_permanent.button_pressed,
		}

	var terrain_idx: int = _terrain_option.selected
	if terrain_idx > 0 and terrain_idx - 1 < Registry.TERRAIN_TYPES.size():
		presets["terrain"] = {
			"key": Registry.TERRAIN_TYPES[terrain_idx - 1],
			"permanent": _terrain_permanent.button_pressed,
		}

	var global_effects: Array[Dictionary] = []
	for i: int in _global_effects_list.get_child_count():
		var row: HBoxContainer = _global_effects_list.get_child(i) as HBoxContainer
		if row == null or row.get_child_count() < 2:
			continue
		var toggle: CheckBox = row.get_child(0) as CheckBox
		var perm: CheckBox = row.get_child(1) as CheckBox
		if toggle.button_pressed:
			global_effects.append({
				"key": Registry.GLOBAL_EFFECT_TYPES[i],
				"permanent": perm.button_pressed,
			})
	if not global_effects.is_empty():
		presets["global_effects"] = global_effects

	config.preset_field_effects = presets


# --- Side Presets (same pattern as start_battle_screen) ---


func _update_side_preset_selector() -> void:
	_side_preset_selector.clear_tabs()
	_side_preset_selector.add_tab("Player (Side 1)")
	_side_preset_selector.add_tab("Wild (Side 2)")
	if _current_preset_side > 1:
		_current_preset_side = 0
	_side_preset_selector.current_tab = _current_preset_side


func _on_preset_side_selected(index: int) -> void:
	_save_side_presets()
	_current_preset_side = index
	_update_side_presets_display()


func _init_side_presets() -> void:
	_side_presets.clear()
	for i: int in 2:
		_side_presets[i] = {
			"side_effects": {},
			"hazards": {},
		}


func _save_side_presets() -> void:
	if not _side_presets.has(_current_preset_side):
		_side_presets[_current_preset_side] = {
			"side_effects": {}, "hazards": {},
		}

	var side_data: Dictionary = _side_presets[_current_preset_side]

	var se_dict: Dictionary = {}
	for i: int in _side_effects_list.get_child_count():
		var row: HBoxContainer = _side_effects_list.get_child(i) as HBoxContainer
		if row == null or row.get_child_count() < 2:
			continue
		var toggle: CheckBox = row.get_child(0) as CheckBox
		var perm: CheckBox = row.get_child(1) as CheckBox
		var key: StringName = Registry.SIDE_EFFECT_TYPES[i]
		se_dict[key] = {
			"enabled": toggle.button_pressed,
			"permanent": perm.button_pressed,
		}
	side_data["side_effects"] = se_dict

	var hz_dict: Dictionary = {}
	for i: int in _hazards_list.get_child_count():
		var container: VBoxContainer = _hazards_list.get_child(i) as VBoxContainer
		if container == null:
			continue
		var key: StringName = Registry.HAZARD_TYPES[i]
		var header: HBoxContainer = container.get_child(0) as HBoxContainer
		var toggle: CheckBox = header.get_child(0) as CheckBox
		var perm: CheckBox = header.get_child(1) as CheckBox
		var layers_spin: SpinBox = header.get_child(2) as SpinBox
		var aerial_check: CheckBox = header.get_child(3) as CheckBox
		var name_edit: LineEdit = header.get_child(4) as LineEdit
		var entry: Dictionary = {
			"enabled": toggle.button_pressed,
			"permanent": perm.button_pressed,
			"layers": int(layers_spin.value),
			"aerial_is_immune": aerial_check.button_pressed,
			"hazard_name": name_edit.text if name_edit != null else "",
		}
		var extras: HBoxContainer = container.get_child(1) as HBoxContainer
		if key == &"entry_damage":
			var element_opt: OptionButton = extras.get_child(1) as OptionButton
			var dmg_spin: SpinBox = extras.get_child(3) as SpinBox
			var element_idx: int = element_opt.selected
			entry["element"] = _HAZARD_ELEMENTS[element_idx] \
				if element_idx < _HAZARD_ELEMENTS.size() else &""
			entry["damagePercent"] = dmg_spin.value
		elif key == &"entry_stat_reduction":
			var stat_opt: OptionButton = extras.get_child(1) as OptionButton
			var stages_spin: SpinBox = extras.get_child(3) as SpinBox
			entry["stat"] = _HAZARD_STATS[stat_opt.selected] \
				if stat_opt.selected < _HAZARD_STATS.size() else "spe"
			entry["stages"] = int(stages_spin.value)
		elif key == &"entry_status_effect":
			var status_opt: OptionButton = extras.get_child(1) as OptionButton
			entry["status"] = _HAZARD_STATUSES[status_opt.selected] \
				if status_opt.selected < _HAZARD_STATUSES.size() \
				else "poisoned"
		hz_dict[key] = entry
	side_data["hazards"] = hz_dict


func _update_side_presets_display() -> void:
	_build_side_effects_list()
	_build_hazards_list()


func _build_side_effects_list() -> void:
	for child: Node in _side_effects_list.get_children():
		child.queue_free()

	var saved: Dictionary = {}
	if _side_presets.has(_current_preset_side):
		saved = _side_presets[_current_preset_side].get("side_effects", {})

	for key: StringName in Registry.SIDE_EFFECT_TYPES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := CheckBox.new()
		toggle.text = str(key).replace("_", " ").capitalize()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if saved.has(key):
			toggle.button_pressed = saved[key].get("enabled", false)
		row.add_child(toggle)
		var perm := CheckBox.new()
		perm.text = "Perm"
		perm.button_pressed = true
		if saved.has(key):
			perm.button_pressed = saved[key].get("permanent", true)
		row.add_child(perm)
		_side_effects_list.add_child(row)


const _HAZARD_ELEMENTS: Array[StringName] = [
	&"", &"fire", &"water", &"air", &"earth", &"ice",
	&"lightning", &"plant", &"metal", &"dark", &"light",
]

const _HAZARD_STATS: Array[String] = ["atk", "def", "spa", "spd", "spe"]

const _HAZARD_STATUSES: Array[String] = [
	"poisoned", "burned", "frostbitten", "paralysed", "blinded", "seeded",
]


func _build_hazards_list() -> void:
	for child: Node in _hazards_list.get_children():
		child.queue_free()

	var saved: Dictionary = {}
	if _side_presets.has(_current_preset_side):
		saved = _side_presets[_current_preset_side].get("hazards", {})

	for key: StringName in Registry.HAZARD_TYPES:
		var container := VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header := HBoxContainer.new()
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var toggle := CheckBox.new()
		toggle.text = str(key).replace("_", " ").capitalize()
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if saved.has(key):
			toggle.button_pressed = saved[key].get("enabled", false)
		header.add_child(toggle)
		var perm := CheckBox.new()
		perm.text = "Perm"
		perm.button_pressed = true
		if saved.has(key):
			perm.button_pressed = saved[key].get("permanent", true)
		header.add_child(perm)
		var layers := SpinBox.new()
		layers.min_value = 1
		layers.max_value = 5
		layers.value = 1
		layers.custom_minimum_size = Vector2(60, 0)
		layers.tooltip_text = "Layers"
		if saved.has(key):
			layers.value = saved[key].get("layers", 1)
		header.add_child(layers)
		var aerial_check := CheckBox.new()
		aerial_check.text = "Aerial Immune"
		aerial_check.button_pressed = false
		if saved.has(key):
			aerial_check.button_pressed = saved[key].get(
				"aerial_is_immune", false,
			)
		header.add_child(aerial_check)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Hazard Name"
		name_edit.custom_minimum_size = Vector2(100, 0)
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if saved.has(key):
			name_edit.text = saved[key].get("hazard_name", "")
		header.add_child(name_edit)
		container.add_child(header)

		var extras := HBoxContainer.new()
		extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == &"entry_damage":
			var el_label := Label.new()
			el_label.text = "  Element:"
			extras.add_child(el_label)
			var el_option := OptionButton.new()
			el_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			el_option.add_item("None")
			for el_key: StringName in _HAZARD_ELEMENTS:
				if el_key != &"":
					el_option.add_item(str(el_key).capitalize())
			var saved_element: StringName = &""
			if saved.has(key):
				saved_element = StringName(saved[key].get("element", ""))
			if saved_element != &"":
				for ei: int in _HAZARD_ELEMENTS.size():
					if _HAZARD_ELEMENTS[ei] == saved_element:
						el_option.selected = ei
						break
			extras.add_child(el_option)
			var dmg_label := Label.new()
			dmg_label.text = "Dmg%:"
			extras.add_child(dmg_label)
			var dmg_spin := SpinBox.new()
			dmg_spin.min_value = 0.0
			dmg_spin.max_value = 0.5
			dmg_spin.step = 0.0625
			dmg_spin.value = 0.125
			dmg_spin.custom_minimum_size = Vector2(80, 0)
			if saved.has(key):
				dmg_spin.value = saved[key].get("damagePercent", 0.125)
			extras.add_child(dmg_spin)
		elif key == &"entry_stat_reduction":
			var stat_label := Label.new()
			stat_label.text = "  Stat:"
			extras.add_child(stat_label)
			var stat_option := OptionButton.new()
			stat_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for abbr: String in _HAZARD_STATS:
				stat_option.add_item(abbr.to_upper())
			var saved_stat: String = ""
			if saved.has(key):
				saved_stat = saved[key].get("stat", "spe")
			for si: int in _HAZARD_STATS.size():
				if _HAZARD_STATS[si] == saved_stat:
					stat_option.selected = si
					break
			extras.add_child(stat_option)
			var stages_label := Label.new()
			stages_label.text = "Stages:"
			extras.add_child(stages_label)
			var stages_spin := SpinBox.new()
			stages_spin.min_value = -6
			stages_spin.max_value = -1
			stages_spin.value = -1
			stages_spin.custom_minimum_size = Vector2(60, 0)
			if saved.has(key):
				stages_spin.value = saved[key].get("stages", -1)
			extras.add_child(stages_spin)
		elif key == &"entry_status_effect":
			var status_label := Label.new()
			status_label.text = "  Status:"
			extras.add_child(status_label)
			var status_option := OptionButton.new()
			status_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for status_name: String in _HAZARD_STATUSES:
				status_option.add_item(status_name.capitalize())
			if saved.has(key):
				var saved_status: String = saved[key].get(
					"status", "poisoned",
				)
				for si: int in _HAZARD_STATUSES.size():
					if _HAZARD_STATUSES[si] == saved_status:
						status_option.selected = si
						break
			extras.add_child(status_option)
		container.add_child(extras)

		_hazards_list.add_child(container)


func _apply_side_presets_to_config(config: BattleConfig) -> void:
	var side_effects: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []

	for side_idx: int in _side_presets:
		var data: Dictionary = _side_presets[side_idx]

		for key: StringName in data.get("side_effects", {}):
			var entry: Dictionary = data["side_effects"][key]
			if not entry.get("enabled", false):
				continue
			side_effects.append({
				"key": key,
				"sides": [side_idx],
				"permanent": entry.get("permanent", true),
			})

		for key: StringName in data.get("hazards", {}):
			var entry: Dictionary = data["hazards"][key]
			if not entry.get("enabled", false):
				continue
			var extra: Dictionary = {}
			if key == &"entry_damage":
				var element: StringName = StringName(
					entry.get("element", ""),
				)
				if element != &"":
					extra["element"] = element
				extra["damagePercent"] = entry.get("damagePercent", 0.125)
			elif key == &"entry_stat_reduction":
				extra["stat"] = entry.get("stat", "spe")
				extra["stages"] = entry.get("stages", -1)
			elif key == &"entry_status_effect":
				extra["status"] = entry.get("status", "poisoned")
			if entry.get("aerial_is_immune", false):
				extra["aerial_is_immune"] = true
			var hz_name: String = entry.get("hazard_name", "")
			if hz_name != "":
				extra["hazard_name"] = hz_name
			hazards.append({
				"key": key,
				"sides": [side_idx],
				"layers": entry.get("layers", 1),
				"permanent": entry.get("permanent", true),
				"extra": extra,
			})

	config.preset_side_effects = side_effects
	config.preset_hazards = hazards

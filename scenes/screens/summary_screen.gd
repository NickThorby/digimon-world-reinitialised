extends Control
## Summary Screen — detailed view of a single Digimon across multiple pages.

const PAGE_COUNT: int = 4

const _HEADER := "MarginContainer/VBox/HeaderBar"
const _TABS := "MarginContainer/VBox/PageTabs"
const _PAGES := "MarginContainer/VBox/PageContainer"

const CYAN := Color(0.024, 0.714, 0.831, 1)
const RED := Color(0.937, 0.267, 0.267, 1)
const MUTED := Color(0.443, 0.443, 0.478, 1)
const HP_GREEN := Color(0.133, 0.773, 0.369)
const XP_CYAN := Color(0.024, 0.714, 0.831, 1)

@onready var _back_button: Button = get_node(_HEADER + "/BackButton")
@onready var _prev_button: Button = get_node(_HEADER + "/PrevButton")
@onready var _next_button: Button = get_node(_HEADER + "/NextButton")
@onready var _page_label: Label = get_node(_HEADER + "/PageLabel")
@onready var _info_tab: Button = get_node(_TABS + "/InfoTab")
@onready var _stats_tab: Button = get_node(_TABS + "/StatsTab")
@onready var _techniques_tab: Button = get_node(_TABS + "/TechniquesTab")
@onready var _held_items_tab: Button = get_node(_TABS + "/HeldItemsTab")
@onready var _info_page: ScrollContainer = get_node(_PAGES + "/InfoPage")
@onready var _stats_page: ScrollContainer = get_node(_PAGES + "/StatsPage")
@onready var _techniques_page: ScrollContainer = get_node(_PAGES + "/TechniquesPage")
@onready var _held_items_page: ScrollContainer = get_node(_PAGES + "/HeldItemsPage")
@onready var _info_vbox: VBoxContainer = get_node(_PAGES + "/InfoPage/InfoVBox")
@onready var _stats_vbox: VBoxContainer = get_node(_PAGES + "/StatsPage/StatsVBox")
@onready var _techniques_vbox: VBoxContainer = get_node(
	_PAGES + "/TechniquesPage/TechniquesVBox"
)
@onready var _held_items_vbox: VBoxContainer = get_node(
	_PAGES + "/HeldItemsPage/HeldItemsVBox"
)

var _digimon: DigimonState = null
var _data: DigimonData = null
var _party_index: int = -1
var _editable: bool = false
var _party_navigation: bool = false
var _return_scene: String = ""
var _mode: Registry.GameMode = Registry.GameMode.TEST
var _party_return_scene: String = ""
var _current_page: int = 0


func _ready() -> void:
	_read_context()
	_setup_navigation()
	_build_all_pages()
	_show_page(0)
	_connect_signals()


func _read_context() -> void:
	var ctx: Dictionary = Game.screen_context
	_digimon = ctx.get("digimon", null) as DigimonState
	_party_index = ctx.get("party_index", -1)
	_editable = ctx.get("editable", false)
	_party_navigation = ctx.get("party_navigation", false)
	_return_scene = ctx.get("return_scene", "")
	_mode = ctx.get("mode", Registry.GameMode.TEST)
	_party_return_scene = ctx.get("party_return_scene", "")

	if _digimon:
		_data = Atlas.digimon.get(_digimon.key) as DigimonData


func _setup_navigation() -> void:
	_prev_button.visible = _party_navigation
	_next_button.visible = _party_navigation


func _connect_signals() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_prev_button.pressed.connect(_on_prev)
	_next_button.pressed.connect(_on_next)
	_info_tab.pressed.connect(_show_page.bind(0))
	_stats_tab.pressed.connect(_show_page.bind(1))
	_techniques_tab.pressed.connect(_show_page.bind(2))
	_held_items_tab.pressed.connect(_show_page.bind(3))


func _on_back_pressed() -> void:
	if _return_scene != "":
		var ctx: Dictionary = {"mode": _mode}
		if _party_return_scene != "":
			ctx["return_scene"] = _party_return_scene
		Game.screen_context = ctx
		SceneManager.change_scene(_return_scene)


func _on_prev() -> void:
	if Game.state == null or Game.state.party.members.is_empty():
		return
	var size: int = Game.state.party.members.size()
	_party_index = (_party_index - 1 + size) % size
	_digimon = Game.state.party.members[_party_index]
	_data = Atlas.digimon.get(_digimon.key) as DigimonData
	_build_all_pages()
	_show_page(_current_page)


func _on_next() -> void:
	if Game.state == null or Game.state.party.members.is_empty():
		return
	var size: int = Game.state.party.members.size()
	_party_index = (_party_index + 1) % size
	_digimon = Game.state.party.members[_party_index]
	_data = Atlas.digimon.get(_digimon.key) as DigimonData
	_build_all_pages()
	_show_page(_current_page)


func _show_page(page: int) -> void:
	_current_page = page
	_info_page.visible = page == 0
	_stats_page.visible = page == 1
	_techniques_page.visible = page == 2
	_held_items_page.visible = page == 3
	_page_label.text = "%d / %d" % [page + 1, PAGE_COUNT]

	# Highlight active tab
	_info_tab.add_theme_color_override(
		"font_color", CYAN if page == 0 else Color.WHITE,
	)
	_stats_tab.add_theme_color_override(
		"font_color", CYAN if page == 1 else Color.WHITE,
	)
	_techniques_tab.add_theme_color_override(
		"font_color", CYAN if page == 2 else Color.WHITE,
	)
	_held_items_tab.add_theme_color_override(
		"font_color", CYAN if page == 3 else Color.WHITE,
	)


func _build_all_pages() -> void:
	_build_info_page()
	_build_stats_page()
	_build_techniques_page()
	_build_held_items_page()


# --- Page 1: Info ---


func _build_info_page() -> void:
	_clear_children(_info_vbox)

	if _digimon == null or _data == null:
		var label := Label.new()
		label.text = tr("No Digimon data")
		_info_vbox.add_child(label)
		return

	# Top row: sprite + info
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	_info_vbox.add_child(top_hbox)

	# Sprite
	var sprite_rect := TextureRect.new()
	sprite_rect.custom_minimum_size = Vector2(96, 96)
	sprite_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.flip_h = true
	sprite_rect.texture = _data.sprite_texture
	top_hbox.add_child(sprite_rect)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(info_vbox)

	# Name
	var display: String = _digimon.nickname if _digimon.nickname != "" else _data.display_name
	var name_label := Label.new()
	name_label.text = display
	name_label.add_theme_font_size_override("font_size", 22)
	info_vbox.add_child(name_label)

	# Species + Evolution Level
	var evo_label_text: String = Registry.get_evolution_level_label(
		_data.level as Registry.EvolutionLevel,
	)
	var species_label := Label.new()
	species_label.text = "%s: %s (%s)" % [
		tr("Species"), _data.display_name, evo_label_text,
	]
	species_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(species_label)

	# Attribute
	var attr_text: String = str(
		Registry.attribute_labels.get(_data.attribute, "—")
	)
	var attr_label := Label.new()
	attr_label.text = "%s: %s" % [tr("Attribute"), attr_text]
	attr_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(attr_label)

	# Elements
	var elements: Array[String] = []
	for element_key: StringName in _data.element_traits:
		elements.append(str(element_key).capitalize())
	var element_text: String = " / ".join(elements) if elements.size() > 0 else "—"
	var element_label := Label.new()
	element_label.text = "%s: %s" % [tr("Elements"), element_text]
	element_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(element_label)

	# Personality (with override display)
	var personality: PersonalityData = Atlas.personalities.get(
		_digimon.personality_key,
	) as PersonalityData
	if personality:
		var boosted_name: String = str(
			Registry.stat_labels.get(personality.boosted_stat, "")
		)
		var reduced_name: String = str(
			Registry.stat_labels.get(personality.reduced_stat, "")
		)
		var personality_text: String = "%s: %s (+%s / -%s)" % [
			tr("Personality"),
			str(_digimon.personality_key).capitalize(),
			boosted_name,
			reduced_name,
		]
		var personality_label := Label.new()
		personality_label.text = personality_text
		personality_label.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(personality_label)

		# Show override if set
		if _digimon.personality_override_key != &"":
			var override_data: PersonalityData = Atlas.personalities.get(
				_digimon.personality_override_key,
			) as PersonalityData
			var override_name: String = str(
				_digimon.personality_override_key
			).capitalize()
			var override_text: String = "Modified: %s" % override_name
			if override_data:
				var ob: String = str(
					Registry.stat_labels.get(override_data.boosted_stat, "")
				)
				var or_: String = str(
					Registry.stat_labels.get(override_data.reduced_stat, "")
				)
				override_text = "Modified: %s (+%s / -%s)" % [
					override_name, ob, or_,
				]
			var override_label := Label.new()
			override_label.text = override_text
			override_label.add_theme_font_size_override("font_size", 13)
			override_label.add_theme_color_override("font_color", MUTED)
			info_vbox.add_child(override_label)

	# Separator
	var sep := HSeparator.new()
	_info_vbox.add_child(sep)

	# Active Ability
	_build_ability_section(_info_vbox)

	# Separator
	var sep2 := HSeparator.new()
	_info_vbox.add_child(sep2)

	# OT
	var ot_label := Label.new()
	ot_label.text = "%s: %s (%s)" % [
		tr("OT"),
		_digimon.original_tamer_name if _digimon.original_tamer_name != "" else "—",
		str(_digimon.display_id) if str(_digimon.display_id) != "" else "—",
	]
	ot_label.add_theme_font_size_override("font_size", 14)
	_info_vbox.add_child(ot_label)

	# Level + XP
	var level_hbox := HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 16)
	_info_vbox.add_child(level_hbox)

	var level_label := Label.new()
	level_label.text = "Lv. %d" % _digimon.level
	level_label.add_theme_font_size_override("font_size", 16)
	level_hbox.add_child(level_label)

	# XP bar
	var xp_vbox := VBoxContainer.new()
	xp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_hbox.add_child(xp_vbox)

	var current_threshold: int = XPCalculator.total_xp_for_level(
		_digimon.level, _data.growth_rate,
	)
	var next_threshold: int = XPCalculator.total_xp_for_level(
		_digimon.level + 1, _data.growth_rate,
	)

	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 10)
	xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = XP_CYAN
	xp_fill.corner_radius_top_left = 2
	xp_fill.corner_radius_top_right = 2
	xp_fill.corner_radius_bottom_left = 2
	xp_fill.corner_radius_bottom_right = 2
	xp_bar.add_theme_stylebox_override("fill", xp_fill)

	if next_threshold <= current_threshold:
		xp_bar.max_value = 1
		xp_bar.value = 1
	else:
		var level_range: int = next_threshold - current_threshold
		var progress: int = _digimon.experience - current_threshold
		xp_bar.max_value = level_range
		xp_bar.value = clampi(progress, 0, level_range)
	xp_vbox.add_child(xp_bar)

	var xp_text_label := Label.new()
	xp_text_label.text = "XP: %d / %d" % [
		_digimon.experience, next_threshold,
	]
	xp_text_label.add_theme_font_size_override("font_size", 12)
	xp_text_label.add_theme_color_override("font_color", MUTED)
	xp_vbox.add_child(xp_text_label)

	# TP
	var tp_label := Label.new()
	tp_label.text = "TP: %d" % _digimon.training_points
	tp_label.add_theme_font_size_override("font_size", 14)
	_info_vbox.add_child(tp_label)


func _build_ability_section(parent: VBoxContainer) -> void:
	var ability_header := Label.new()
	ability_header.text = tr("Active Ability")
	ability_header.add_theme_font_size_override("font_size", 16)
	parent.add_child(ability_header)

	if _data == null or _digimon == null:
		var none_label := Label.new()
		none_label.text = tr("None")
		none_label.add_theme_color_override("font_color", MUTED)
		parent.add_child(none_label)
		return

	var ability_key: StringName = &""
	match _digimon.active_ability_slot:
		1: ability_key = _data.ability_slot_1_key
		2: ability_key = _data.ability_slot_2_key
		3: ability_key = _data.ability_slot_3_key

	var ability_data: AbilityData = Atlas.abilities.get(ability_key) as AbilityData
	if ability_data == null:
		var none_label := Label.new()
		none_label.text = tr("None")
		none_label.add_theme_color_override("font_color", MUTED)
		parent.add_child(none_label)
		return

	var name_label := Label.new()
	name_label.text = ability_data.name
	name_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(name_label)

	# Trigger + stack limit
	var trigger_text: String = str(
		Registry.ability_trigger_labels.get(ability_data.trigger, "")
	)
	var stack_text: String = str(
		Registry.stack_limit_labels.get(ability_data.stack_limit, "")
	)
	if trigger_text != "" or stack_text != "":
		var meta_label := Label.new()
		var parts: Array[String] = []
		if trigger_text != "":
			parts.append(trigger_text)
		if stack_text != "":
			parts.append(stack_text)
		meta_label.text = " | ".join(parts)
		meta_label.add_theme_font_size_override("font_size", 12)
		meta_label.add_theme_color_override("font_color", MUTED)
		parent.add_child(meta_label)

	if ability_data.description != "":
		var desc_label := Label.new()
		desc_label.text = ability_data.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", MUTED)
		parent.add_child(desc_label)


# --- Page 2: Stats ---


const STAT_KEYS: Array[StringName] = [
	&"hp", &"energy", &"attack", &"defence",
	&"special_attack", &"special_defence", &"speed",
]

const STAT_DISPLAY_NAMES: Dictionary = {
	&"hp": "HP",
	&"energy": "EN",
	&"attack": "ATK",
	&"defence": "DEF",
	&"special_attack": "SATK",
	&"special_defence": "SDEF",
	&"speed": "SPD",
}

## Max stat value for visual bar scaling.
const STAT_BAR_MAX: int = 250


func _build_stats_page() -> void:
	_clear_children(_stats_vbox)

	if _digimon == null or _data == null:
		return

	var stats: Dictionary = StatCalculator.calculate_all_stats(_data, _digimon)
	var personality: PersonalityData = Atlas.personalities.get(
		_digimon.get_effective_personality_key(),
	) as PersonalityData

	var bst_total: int = 0

	for stat_key: StringName in STAT_KEYS:
		var base_value: int = stats.get(stat_key, 0) as int
		var final_value: int = StatCalculator.apply_personality(
			base_value, stat_key, personality,
		)
		bst_total += final_value

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_stats_vbox.add_child(row)

		# Stat name
		var name_label := Label.new()
		name_label.text = str(STAT_DISPLAY_NAMES.get(stat_key, str(stat_key)))
		name_label.custom_minimum_size = Vector2(50, 0)
		name_label.add_theme_font_size_override("font_size", 14)

		# Personality colouring
		var stat_colour: Color = _get_personality_colour(stat_key, personality)
		if stat_colour != Color.WHITE:
			name_label.add_theme_color_override("font_color", stat_colour)
		row.add_child(name_label)

		# Stat value
		var value_label := Label.new()
		value_label.text = str(final_value)
		value_label.custom_minimum_size = Vector2(45, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 14)
		if stat_colour != Color.WHITE:
			value_label.add_theme_color_override("font_color", stat_colour)
		row.add_child(value_label)

		# Stat bar
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 12)
		bar.max_value = STAT_BAR_MAX
		bar.value = mini(final_value, STAT_BAR_MAX)
		bar.show_percentage = false
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = stat_colour if stat_colour != Color.WHITE else CYAN
		bar_fill.corner_radius_top_left = 2
		bar_fill.corner_radius_top_right = 2
		bar_fill.corner_radius_bottom_left = 2
		bar_fill.corner_radius_bottom_right = 2
		bar.add_theme_stylebox_override("fill", bar_fill)
		row.add_child(bar)

		# IV
		var iv_val: int = _digimon.ivs.get(stat_key, 0) as int
		var iv_label := Label.new()
		iv_label.text = "IV:%d" % iv_val
		iv_label.custom_minimum_size = Vector2(50, 0)
		iv_label.add_theme_font_size_override("font_size", 11)
		iv_label.add_theme_color_override("font_color", MUTED)
		row.add_child(iv_label)

		# TV
		var tv_val: int = _digimon.tvs.get(stat_key, 0) as int
		var tv_label := Label.new()
		tv_label.text = "TV:%d" % tv_val
		tv_label.custom_minimum_size = Vector2(55, 0)
		tv_label.add_theme_font_size_override("font_size", 11)
		tv_label.add_theme_color_override("font_color", MUTED)
		row.add_child(tv_label)

	# BST total row
	var bst_sep := HSeparator.new()
	_stats_vbox.add_child(bst_sep)

	var bst_row := HBoxContainer.new()
	bst_row.add_theme_constant_override("separation", 8)
	_stats_vbox.add_child(bst_row)

	var bst_name := Label.new()
	bst_name.text = "BST"
	bst_name.custom_minimum_size = Vector2(50, 0)
	bst_name.add_theme_font_size_override("font_size", 14)
	bst_row.add_child(bst_name)

	var bst_val := Label.new()
	bst_val.text = str(bst_total)
	bst_val.add_theme_font_size_override("font_size", 14)
	bst_row.add_child(bst_val)


static func _get_personality_colour(
	stat_key: StringName,
	personality: PersonalityData,
) -> Color:
	if personality == null:
		return Color.WHITE

	var stat_enum: Registry.Stat = _stat_key_to_enum(stat_key)
	var is_boosted: bool = personality.boosted_stat == stat_enum
	var is_reduced: bool = personality.reduced_stat == stat_enum

	if is_boosted and is_reduced:
		return Color.WHITE  # Neutral personality
	if is_boosted:
		return CYAN
	if is_reduced:
		return RED
	return Color.WHITE


# --- Page 3: Techniques ---


func _build_techniques_page() -> void:
	_clear_children(_techniques_vbox)

	if _digimon == null:
		return

	# Equipped section
	var equipped_header := Label.new()
	equipped_header.text = tr("Equipped Techniques")
	equipped_header.add_theme_font_size_override("font_size", 18)
	equipped_header.add_theme_color_override("font_color", CYAN)
	_techniques_vbox.add_child(equipped_header)

	if _digimon.equipped_technique_keys.is_empty():
		var none_label := Label.new()
		none_label.text = tr("None equipped")
		none_label.add_theme_color_override("font_color", MUTED)
		_techniques_vbox.add_child(none_label)
	else:
		for i: int in _digimon.equipped_technique_keys.size():
			var tech_key: StringName = _digimon.equipped_technique_keys[i]
			var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
			var row := _create_technique_row(tech_key, tech_data, true, i)
			_techniques_vbox.add_child(row)

	# Separator
	var sep := HSeparator.new()
	_techniques_vbox.add_child(sep)

	# Known section (unequipped)
	var known_header := Label.new()
	known_header.text = tr("Known Techniques")
	known_header.add_theme_font_size_override("font_size", 18)
	_techniques_vbox.add_child(known_header)

	var unequipped_count: int = 0
	for tech_key: StringName in _digimon.known_technique_keys:
		if tech_key in _digimon.equipped_technique_keys:
			continue
		var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		var row := _create_technique_row(tech_key, tech_data, false, -1)
		_techniques_vbox.add_child(row)
		unequipped_count += 1

	if unequipped_count == 0:
		var none_label := Label.new()
		none_label.text = tr("No additional techniques known")
		none_label.add_theme_color_override("font_color", MUTED)
		_techniques_vbox.add_child(none_label)


func _create_technique_row(
	tech_key: StringName,
	tech_data: TechniqueData,
	is_equipped: bool,
	equipped_index: int,
) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	container.add_child(row)

	# Name
	var name_label := Label.new()
	if tech_data:
		name_label.text = tech_data.display_name
	else:
		name_label.text = str(tech_key)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	row.add_child(name_label)

	if tech_data:
		# Element
		var element_text: String = str(tech_data.element_key).capitalize()
		var element_label := Label.new()
		element_label.text = element_text
		element_label.custom_minimum_size = Vector2(70, 0)
		element_label.add_theme_font_size_override("font_size", 12)
		var elem_colour: Color = Registry.ELEMENT_COLOURS.get(
			tech_data.element_key, Color.WHITE,
		)
		element_label.add_theme_color_override("font_color", elem_colour)
		row.add_child(element_label)

		# Class
		var class_text: String = str(
			Registry.technique_class_labels.get(tech_data.technique_class, "")
		)
		var class_label := Label.new()
		class_label.text = class_text
		class_label.custom_minimum_size = Vector2(65, 0)
		class_label.add_theme_font_size_override("font_size", 12)
		class_label.add_theme_color_override("font_color", MUTED)
		row.add_child(class_label)

		# Power
		var power_label := Label.new()
		power_label.text = "Pwr:%d" % tech_data.power if tech_data.power > 0 else "Pwr:—"
		power_label.custom_minimum_size = Vector2(55, 0)
		power_label.add_theme_font_size_override("font_size", 12)
		row.add_child(power_label)

		# Accuracy
		if is_equipped:
			var acc_label := Label.new()
			acc_label.text = "Acc:%d%%" % tech_data.accuracy
			acc_label.custom_minimum_size = Vector2(60, 0)
			acc_label.add_theme_font_size_override("font_size", 12)
			row.add_child(acc_label)

		# Energy cost
		var energy_label := Label.new()
		energy_label.text = "EN:%d" % tech_data.energy_cost
		energy_label.custom_minimum_size = Vector2(45, 0)
		energy_label.add_theme_font_size_override("font_size", 12)
		row.add_child(energy_label)

	# Action button
	if _editable:
		if is_equipped:
			var unequip_btn := Button.new()
			unequip_btn.text = tr("Unequip")
			unequip_btn.pressed.connect(
				_on_unequip_technique.bind(equipped_index)
			)
			row.add_child(unequip_btn)
		else:
			var balance: GameBalance = load(
				"res://data/config/game_balance.tres"
			) as GameBalance
			var max_equipped: int = balance.max_equipped_techniques if balance else 4
			if _digimon.equipped_technique_keys.size() < max_equipped:
				var equip_btn := Button.new()
				equip_btn.text = tr("Equip")
				equip_btn.pressed.connect(
					_on_equip_technique.bind(tech_key)
				)
				row.add_child(equip_btn)
			else:
				var swap_btn := Button.new()
				swap_btn.text = tr("Swap")
				swap_btn.pressed.connect(
					_on_swap_technique_start.bind(tech_key)
				)
				row.add_child(swap_btn)

	# Description (shown for equipped techniques)
	if is_equipped and tech_data:
		if tech_data.description != "":
			var desc_label := Label.new()
			desc_label.text = tech_data.description
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.add_theme_font_size_override("font_size", 12)
			desc_label.add_theme_color_override("font_color", MUTED)
			container.add_child(desc_label)
		if tech_data.mechanic_description != "":
			var mech_label := Label.new()
			mech_label.text = tech_data.mechanic_description
			mech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mech_label.add_theme_font_size_override("font_size", 11)
			mech_label.add_theme_color_override("font_color", MUTED)
			container.add_child(mech_label)

	return container


func _on_unequip_technique(index: int) -> void:
	if _digimon == null:
		return
	if index < 0 or index >= _digimon.equipped_technique_keys.size():
		return
	_digimon.equipped_technique_keys.remove_at(index)
	_build_techniques_page()


func _on_equip_technique(tech_key: StringName) -> void:
	if _digimon == null:
		return
	var balance: GameBalance = load(
		"res://data/config/game_balance.tres"
	) as GameBalance
	var max_equipped: int = balance.max_equipped_techniques if balance else 4
	if _digimon.equipped_technique_keys.size() >= max_equipped:
		return
	_digimon.equipped_technique_keys.append(tech_key)
	_build_techniques_page()


func _on_swap_technique_start(new_key: StringName) -> void:
	if _digimon == null:
		return
	# Show a popup to pick which equipped slot to replace
	var popup := PopupMenu.new()
	for i: int in _digimon.equipped_technique_keys.size():
		var tech_key: StringName = _digimon.equipped_technique_keys[i]
		var tech_data: TechniqueData = Atlas.techniques.get(tech_key) as TechniqueData
		var label: String = tech_data.display_name if tech_data else str(tech_key)
		popup.add_item(label, i)

	add_child(popup)
	popup.id_pressed.connect(
		func(id: int) -> void:
			_on_swap_technique_confirm(id, new_key)
			popup.queue_free()
	)
	popup.popup_centered()


func _on_swap_technique_confirm(slot_index: int, new_key: StringName) -> void:
	if _digimon == null:
		return
	if slot_index < 0 or slot_index >= _digimon.equipped_technique_keys.size():
		return
	_digimon.equipped_technique_keys[slot_index] = new_key
	_build_techniques_page()


# --- Page 4: Held Items ---


func _build_held_items_page() -> void:
	_clear_children(_held_items_vbox)

	if _digimon == null:
		return

	# Gear slot
	var gear_header := Label.new()
	gear_header.text = tr("Gear")
	gear_header.add_theme_font_size_override("font_size", 18)
	gear_header.add_theme_color_override("font_color", CYAN)
	_held_items_vbox.add_child(gear_header)

	if _digimon.equipped_gear_key != &"":
		_build_item_slot(
			_held_items_vbox, _digimon.equipped_gear_key, false,
		)
	else:
		var none_label := Label.new()
		none_label.text = tr("None")
		none_label.add_theme_color_override("font_color", MUTED)
		_held_items_vbox.add_child(none_label)

	# Separator
	var sep := HSeparator.new()
	_held_items_vbox.add_child(sep)

	# Consumable slot
	var consumable_header := Label.new()
	consumable_header.text = tr("Consumable")
	consumable_header.add_theme_font_size_override("font_size", 18)
	consumable_header.add_theme_color_override("font_color", CYAN)
	_held_items_vbox.add_child(consumable_header)

	if _digimon.equipped_consumable_key != &"":
		_build_item_slot(
			_held_items_vbox, _digimon.equipped_consumable_key, true,
		)
	else:
		var none_label := Label.new()
		none_label.text = tr("None")
		none_label.add_theme_color_override("font_color", MUTED)
		_held_items_vbox.add_child(none_label)


func _build_item_slot(
	parent: VBoxContainer, item_key: StringName, is_consumable: bool,
) -> void:
	var item_data: ItemData = Atlas.items.get(item_key) as ItemData
	if item_data == null:
		var unknown_label := Label.new()
		unknown_label.text = str(item_key)
		unknown_label.add_theme_color_override("font_color", MUTED)
		parent.add_child(unknown_label)
		return

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	parent.add_child(name_row)

	var name_label := Label.new()
	name_label.text = item_data.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(name_label)

	if _editable:
		var remove_btn := Button.new()
		remove_btn.text = tr("Remove")
		remove_btn.pressed.connect(_on_remove_held_item.bind(is_consumable))
		name_row.add_child(remove_btn)

	if item_data.description != "":
		var desc_label := Label.new()
		desc_label.text = item_data.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", MUTED)
		parent.add_child(desc_label)

	# Show gear-specific info
	if item_data is GearData:
		var gear: GearData = item_data as GearData
		var trigger_text: String = str(
			Registry.ability_trigger_labels.get(gear.trigger, "")
		)
		var stack_text: String = str(
			Registry.stack_limit_labels.get(gear.stack_limit, "")
		)
		var parts: Array[String] = []
		if trigger_text != "":
			parts.append(trigger_text)
		if stack_text != "":
			parts.append(stack_text)
		if parts.size() > 0:
			var meta_label := Label.new()
			meta_label.text = " | ".join(parts)
			meta_label.add_theme_font_size_override("font_size", 11)
			meta_label.add_theme_color_override("font_color", MUTED)
			parent.add_child(meta_label)


func _on_remove_held_item(is_consumable: bool) -> void:
	if _digimon == null:
		return

	var key: StringName
	if is_consumable:
		key = _digimon.equipped_consumable_key
		if key == &"":
			return
		_digimon.equipped_consumable_key = &""
	else:
		key = _digimon.equipped_gear_key
		if key == &"":
			return
		_digimon.equipped_gear_key = &""

	# Return item to inventory
	if Game.state:
		var current_qty: int = Game.state.inventory.items.get(key, 0) as int
		Game.state.inventory.items[key] = current_qty + 1

	_build_held_items_page()


# --- Helpers ---


static func _stat_key_to_enum(stat_key: StringName) -> Registry.Stat:
	match stat_key:
		&"hp": return Registry.Stat.HP
		&"energy": return Registry.Stat.ENERGY
		&"attack": return Registry.Stat.ATTACK
		&"defence": return Registry.Stat.DEFENCE
		&"special_attack": return Registry.Stat.SPECIAL_ATTACK
		&"special_defence": return Registry.Stat.SPECIAL_DEFENCE
		&"speed": return Registry.Stat.SPEED
		_: return Registry.Stat.HP


func _clear_children(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()

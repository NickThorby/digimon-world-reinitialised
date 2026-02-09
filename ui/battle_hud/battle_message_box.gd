class_name BattleMessageBox
extends PanelContainer
## Pokemon-style message box with typewriter text reveal and press-to-advance.

enum State {
	IDLE,
	REVEALING,
	WAITING,
}

signal message_completed

@onready var _label: RichTextLabel = $MarginContainer/MessageLabel
@onready var _advance_indicator: Label = $AdvanceIndicator

var _state: State = State.IDLE
var _chars_per_second: int = 0
var _char_progress: float = 0.0
var _total_characters: int = 0
var _auto_advance_timer: float = 0.0


func _ready() -> void:
	_label.bbcode_enabled = true
	_label.visible_characters = 0
	_advance_indicator.visible = false


func _process(delta: float) -> void:
	match _state:
		State.REVEALING:
			_process_revealing(delta)
		State.WAITING:
			_process_waiting(delta)


func _process_revealing(delta: float) -> void:
	if _chars_per_second <= 0:
		return
	_char_progress += float(_chars_per_second) * delta
	var new_visible: int = mini(int(_char_progress), _total_characters)
	_label.visible_characters = new_visible
	if new_visible >= _total_characters:
		_enter_waiting()


func _process_waiting(delta: float) -> void:
	if Settings.advance_mode == Settings.AdvanceMode.AUTO:
		_auto_advance_timer -= delta
		if _auto_advance_timer <= 0.0:
			_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	match _state:
		State.REVEALING:
			# Skip to full text
			_label.visible_characters = _total_characters
			_enter_waiting()
			get_viewport().set_input_as_handled()
		State.WAITING:
			if Settings.advance_mode == Settings.AdvanceMode.MANUAL:
				_advance()
				get_viewport().set_input_as_handled()


## Display a message with typewriter reveal. Awaitable — resolves when advanced.
func show_message(text: String) -> void:
	_label.text = text
	_total_characters = _label.get_total_character_count()
	_chars_per_second = Settings.TEXT_SPEED_CPS.get(
		Settings.text_speed, 40
	) as int

	if _chars_per_second <= 0:
		# Instant mode
		_label.visible_characters = -1
		_enter_waiting()
	else:
		_label.visible_characters = 0
		_char_progress = 0.0
		_state = State.REVEALING
		_advance_indicator.visible = false

	await message_completed


## Display a prompt (non-blocking, no typewriter, no advance required).
func show_prompt(text: String) -> void:
	_label.text = text
	_label.visible_characters = -1
	_state = State.IDLE
	_advance_indicator.visible = false


## Clear the message box.
func clear() -> void:
	_label.text = ""
	_label.visible_characters = 0
	_state = State.IDLE
	_advance_indicator.visible = false


func _enter_waiting() -> void:
	_state = State.WAITING
	_label.visible_characters = _total_characters
	_auto_advance_timer = Settings.AUTO_ADVANCE_DELAY
	if Settings.advance_mode == Settings.AdvanceMode.MANUAL:
		_advance_indicator.visible = true
	else:
		_advance_indicator.visible = false


func _advance() -> void:
	_state = State.IDLE
	_advance_indicator.visible = false
	message_completed.emit()

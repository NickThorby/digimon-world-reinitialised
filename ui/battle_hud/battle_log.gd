class_name BattleLog
extends PanelContainer
## Scrolling text log for battle messages.


@onready var _text: RichTextLabel = %LogText

var _max_lines: int = 100


func _ready() -> void:
	_text.bbcode_enabled = true


## Add a message to the log.
func add_message(text: String) -> void:
	_text.append_text(text + "\n")

	# Trim if too many lines
	if _text.get_line_count() > _max_lines:
		var full_text: String = _text.get_parsed_text()
		var lines: PackedStringArray = full_text.split("\n")
		if lines.size() > _max_lines:
			var trimmed: String = "\n".join(
				lines.slice(lines.size() - _max_lines)
			)
			_text.clear()
			_text.append_text(trimmed)

	# Auto-scroll to bottom
	_text.scroll_to_line(_text.get_line_count())


## Clear all messages.
func clear_log() -> void:
	_text.clear()

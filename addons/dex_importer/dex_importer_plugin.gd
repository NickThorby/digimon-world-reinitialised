@tool
class_name DexImporterPlugin
extends EditorPlugin
## Registers the Dex Importer dock panel in the editor.

var _dock: Control


func _enter_tree() -> void:
	_dock = preload("res://addons/dex_importer/dex_importer_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

extends Node2D
## Entry point scene. Redirects to appropriate screen on load.


func _ready() -> void:
	# Use call_deferred to allow autoloads to fully initialise first.
	call_deferred("_on_ready_deferred")


func _on_ready_deferred() -> void:
	# TODO: Replace with main menu scene transition once it exists.
	print("Digimon World: Reinitialised — main scene loaded.")

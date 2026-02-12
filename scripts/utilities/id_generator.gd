class_name IdGenerator
extends RefCounted
## Generates unique identifier strings for game entities.


## Generate an 8-character lowercase hex ID (32-bit).
static func generate_hex_id() -> StringName:
	return StringName("%08x" % randi())


## Generate a paired display_id + secret_id for a Digimon instance.
## Returns { "display_id": StringName, "secret_id": StringName }.
static func generate_digimon_ids() -> Dictionary:
	return {
		"display_id": generate_hex_id(),
		"secret_id": generate_hex_id(),
	}

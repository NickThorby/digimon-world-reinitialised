@tool
extends RefCounted
## Saves Resource instances as .tres files, creating directories as needed.


## Saves a resource to the specified folder with the given filename.
func write_resource(resource: Resource, folder: String, filename: String) -> Error:
	_ensure_directory(folder)
	var path: String = folder + "/" + filename
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("[ResourceWriter] Failed to save %s: error %d" % [path, error])
	return error


func _ensure_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

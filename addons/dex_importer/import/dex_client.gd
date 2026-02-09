@tool
extends RefCounted
## Fetches export data from the dex API or a local JSON file.


## Fetches JSON from the dex API endpoint. Requires a parent node for HTTPRequest.
func fetch_from_api(url: String, parent: Node) -> Dictionary:
	var http_request: HTTPRequest = HTTPRequest.new()
	parent.add_child(http_request)

	var error: int = http_request.request(url)
	if error != OK:
		push_error("[DexClient] HTTP request failed: error %d" % error)
		http_request.queue_free()
		return {}

	var response: Array = await http_request.request_completed
	http_request.queue_free()

	var result: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[DexClient] HTTP request failed with result %d" % result)
		return {}

	if response_code != 200:
		push_error("[DexClient] HTTP %d response" % response_code)
		return {}

	var json_string: String = body.get_string_from_utf8()
	return _parse_json(json_string)


## Reads and parses a local JSON file.
func fetch_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[DexClient] File not found: %s" % path)
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DexClient] Cannot open file: %s" % path)
		return {}

	var json_string: String = file.get_as_text()
	file.close()
	return _parse_json(json_string)


## Downloads a sprite PNG from the dex API. Returns raw bytes, or empty on failure.
func download_sprite(base_url: String, game_id: String, parent: Node) -> PackedByteArray:
	var url: String = base_url.trim_suffix("/") + "/sprites/" + game_id
	var http: HTTPRequest = HTTPRequest.new()
	parent.add_child(http)

	var error: int = http.request(url)
	if error != OK:
		http.queue_free()
		return PackedByteArray()

	var response: Array = await http.request_completed
	http.queue_free()

	var result: int = response[0]
	var code: int = response[1]
	var body: PackedByteArray = response[3]

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return PackedByteArray()

	return body


func _parse_json(json_string: String) -> Dictionary:
	var json: JSON = JSON.new()
	var parse_error: int = json.parse(json_string)
	if parse_error != OK:
		push_error("[DexClient] JSON parse error at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		return {}

	var data: Variant = json.data
	if data is not Dictionary:
		push_error("[DexClient] Expected root JSON object, got %s" % typeof(data))
		return {}

	return data as Dictionary

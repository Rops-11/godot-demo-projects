class_name GameOnConnect
extends Node

signal authorization_status_changed(status: String)
signal artifact_unlocked(artifact_data: Dictionary, is_new_unlock: bool)

const POLL_INTERVAL_SECONDS := 3.0

var api_url: String = ProjectSettings.get_setting("game_on/api_url", "https://staging.gameonportal.ph")
var game_id: String = ProjectSettings.get_setting("game_on/game_id", "")

var is_authorized: bool = false
var _session_token: String = ""
var _session_in_progress: bool = false

var pending_artifact: Dictionary = {}
var pending_is_new_unlock: bool = false


func connect_account() -> void:
	if _session_in_progress or is_authorized:
		return
	if game_id.is_empty():
		push_error("GameOnConnect: game_id not configured in Project Settings")
		authorization_status_changed.emit("error")
		return
	_session_in_progress = true
	authorization_status_changed.emit("connecting")
	_create_session()


func unlock_artifact() -> void:
	if not is_authorized:
		return
	_unlock_artifact_request()


func _create_session() -> void:
	var body := {"gameId": game_id}
	var response: Variant = await _post_json("/api/session", body, "")

	_session_in_progress = false

	if not (response is Dictionary):
		authorization_status_changed.emit("error")
		return

	var data := response as Dictionary
	_session_token = String(data.get("sessionToken", ""))
	var signin_url := String(data.get("signinUrl", ""))

	if _session_token.is_empty() or signin_url.is_empty():
		push_error("GameOnConnect: invalid create session response")
		authorization_status_changed.emit("error")
		return

	_open_browser(signin_url)
	_poll_authorization()


func _poll_authorization() -> void:
	while true:
		var response: Variant = await _get_with_bearer("/api/session", _session_token)
		if not (response is Dictionary):
			await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
			continue

		var data := response as Dictionary
		var status := String(data.get("status", ""))
		match status:
			"pending":
				authorization_status_changed.emit("pending")
			"authorized":
				is_authorized = true
				authorization_status_changed.emit("authorized")
				return
			"expired":
				authorization_status_changed.emit("expired")
				return
			_:
				authorization_status_changed.emit("error")
				return

		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout


func _unlock_artifact_request() -> void:
	var response: Variant = await _post_json("/api/artifacts/unlock", {}, _session_token)
	if not (response is Dictionary):
		print("GameOn unlock: response is not a dictionary")
		return
	
	var data := response as Dictionary
	print("GameOn unlock response: %s" % data)
	
	if data.get("success", false):
		var already_unlocked: bool = data.get("alreadyUnlocked", false)
		
		if already_unlocked:
			print("GameOn unlock: artifact already unlocked, loading from cache")
			var cached := _load_artifact_cache()
			if not cached.is_empty():
				print("GameOn unlock: using cached artifact data")
				print("Cached artifact: %s" % cached.get("artifact", {}).get("name", "Unknown"))
				pending_artifact = cached
				pending_is_new_unlock = false
				artifact_unlocked.emit(cached, false)
			else:
				print("GameOn unlock: no cache available, using response data")
				pending_artifact = data
				pending_is_new_unlock = false
				artifact_unlocked.emit(data, false)
		else:
			print("GameOn unlock: new unlock, saving to cache")
			_save_artifact_cache(data)
			pending_artifact = data
			pending_is_new_unlock = true
			artifact_unlocked.emit(data, true)
	else:
		print("GameOn unlock: success=false, trying cache")
		var cached := _load_artifact_cache()
		if not cached.is_empty():
			print("GameOn unlock: using cached artifact data")
			pending_artifact = cached
			pending_is_new_unlock = false
			artifact_unlocked.emit(cached, false)
		else:
			print("GameOn unlock: no cached artifact data available")


func _save_artifact_cache(artifact_data: Dictionary) -> void:
	var file := FileAccess.open("user://artifact_cache.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(artifact_data))
		file.close()


func _load_artifact_cache() -> Dictionary:
	var file := FileAccess.open("user://artifact_cache.json", FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(content)
		if parsed is Dictionary:
			return parsed
	return {}


func _open_browser(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank');" % url, true)
	else:
		OS.shell_open(url)


func _post_json(path: String, body: Dictionary, bearer: String) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not bearer.is_empty():
		headers.append("Authorization: Bearer %s" % bearer)
	http.request(api_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	var result: Array = await http.request_completed
	http.queue_free()
	return _parse_response(result)


func _get_with_bearer(path: String, bearer: String) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Authorization: Bearer %s" % bearer])
	http.request(api_url + path, headers, HTTPClient.METHOD_GET, "")
	var result: Array = await http.request_completed
	http.queue_free()
	return _parse_response(result)


func _parse_response(result: Array) -> Variant:
	if result.is_empty():
		push_error("GameOnConnect: empty response")
		return null
	var status: int = result[0]
	var body: PackedByteArray = result[3]
	if status != HTTPRequest.RESULT_SUCCESS:
		push_error("GameOnConnect: HTTP request failed with result %d" % status)
		return null
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("GameOnConnect: response is not a JSON object: %s" % text)
		return null
	return parsed

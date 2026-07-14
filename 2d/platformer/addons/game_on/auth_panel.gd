class_name AuthPanel
extends Control

signal authorized

@onready var _status_label: Label = %StatusLabel
@onready var _connect_button: Button = %ConnectButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_connect_button.pressed.connect(_on_connect_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
	game_on_connect.authorization_status_changed.connect(_on_authorization_status_changed)

	if game_on_connect.is_authorized:
		_update_ui_for_status("authorized")
	else:
		_update_ui_for_status("idle")


func _on_connect_pressed() -> void:
	get_node(^"/root/GameOnPortal").connect_account()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_authorization_status_changed(status: String) -> void:
	_update_ui_for_status(status)
	if status == "authorized":
		authorized.emit()
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://main_menu.tscn")


func _update_ui_for_status(status: String) -> void:
	match status:
		"idle":
			_connect_button.disabled = false
			_status_label.text = "Press Connect to begin"
		"connecting":
			_connect_button.disabled = true
			_status_label.text = "Opening sign-in page..."
		"pending":
			_connect_button.disabled = true
			_connect_button.text = "Connecting..."
			_status_label.text = "Sign-in pending..."
		"authorized":
			_connect_button.visible = false
			_status_label.text = "Welcome! Authentication successful."
		"expired":
			_connect_button.disabled = false
			_status_label.text = "Session expired. Press Connect again."
		"error":
			_connect_button.disabled = false
			_status_label.text = "Connection error. Try again."

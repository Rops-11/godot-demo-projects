class_name MainMenu
extends Control

@onready var _status_label: Label = %StatusLabel
@onready var _connect_button: Button = %ConnectButton
@onready var _start_button: Button = %StartButton
@onready var _instructions_button: Button = %InstructionsButton


func _ready() -> void:
	_connect_button.pressed.connect(_on_connect_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_instructions_button.pressed.connect(_on_instructions_pressed)

	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
	game_on_connect.authorization_status_changed.connect(_on_authorization_status_changed)

	if game_on_connect.is_authorized:
		_update_ui_for_status("authorized")
	else:
		_update_ui_for_status("idle")


func _on_connect_pressed() -> void:
	get_node(^"/root/GameOnPortal").connect_account()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(^"res://game_singleplayer.tscn")


func _on_instructions_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Instructions"
	dialog.dialog_text = "Authenticate with your GameOn account."
	dialog.ok_button_text = "Close"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _on_authorization_status_changed(status: String) -> void:
	_update_ui_for_status(status)


func _update_ui_for_status(status: String) -> void:
	match status:
		"idle":
			_connect_button.disabled = false
			_connect_button.text = "Connect Platform Account"
			_start_button.visible = false
			_instructions_button.visible = false
			_status_label.text = "Press Connect to begin"
		"connecting":
			_connect_button.disabled = true
			_connect_button.text = "Connect Platform Account"
			_start_button.visible = false
			_instructions_button.visible = false
			_status_label.text = "Opening sign-in page..."
		"pending":
			_connect_button.disabled = true
			_connect_button.text = "Connecting..."
			_start_button.visible = false
			_instructions_button.visible = false
			_status_label.text = "Sign-in pending..."
		"authorized":
			_connect_button.visible = false
			_start_button.visible = true
			_instructions_button.visible = true
			_status_label.text = "Welcome!"
		"expired":
			_connect_button.disabled = false
			_connect_button.text = "Connect Platform Account"
			_start_button.visible = false
			_instructions_button.visible = false
			_status_label.text = "Session expired. Press Connect again."
		"error":
			_connect_button.disabled = false
			_connect_button.text = "Connect Platform Account"
			_start_button.visible = false
			_instructions_button.visible = false
			_status_label.text = "Connection error. Try again."

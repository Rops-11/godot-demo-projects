class_name Level
extends Node2D

signal level_cleared

const LIMIT_LEFT := -315
const LIMIT_TOP := -250
const LIMIT_RIGHT := 955
const LIMIT_BOTTOM := 690

var _coins_remaining: int = 0
var _enemies_remaining: int = 0


func _ready() -> void:
	_coins_remaining = _count_descendants_of_type(get_node_or_null(^"Coins"), Coin)
	_enemies_remaining = _count_descendants_of_type(get_node_or_null(^"Enemies"), Enemy)
	_hook_players()
	_hook_enemies()
	_check_cleared()
	
	var game_on_connect := get_node_or_null(^"/root/GameOnPortal") as GameOnConnect
	if game_on_connect != null:
		game_on_connect.artifact_unlocked.connect(_on_artifact_unlocked)


func _count_descendants_of_type(node: Node, type: Variant) -> int:
	if node == null:
		return 0
	var count: int = 0
	for child in node.get_children():
		if is_instance_of(child, type):
			count += 1
		count += _count_descendants_of_type(child, type)
	return count


func _hook_players() -> void:
	for child in get_children():
		if child is Player:
			var camera := child.get_node(^"Camera") as Camera2D
			camera.limit_left = LIMIT_LEFT
			camera.limit_top = LIMIT_TOP
			camera.limit_right = LIMIT_RIGHT
			camera.limit_bottom = LIMIT_BOTTOM
			(child as Player).coin_collected.connect(_on_coin_collected)


func _hook_enemies() -> void:
	var enemies := get_node_or_null(^"Enemies")
	if enemies == null:
		return
	for child in enemies.get_children():
		if child is Enemy:
			(child as Enemy).destroyed.connect(_on_enemy_destroyed)


func _on_coin_collected() -> void:
	_coins_remaining = maxi(0, _coins_remaining - 1)
	print("Coin collected. Remaining: ", _coins_remaining)
	_check_cleared()


func _on_enemy_destroyed() -> void:
	_enemies_remaining = maxi(0, _enemies_remaining - 1)
	print("Enemy destroyed. Remaining: ", _enemies_remaining)
	_check_cleared()


func _check_cleared() -> void:
	print("Check cleared - Coins:", _coins_remaining, " Enemies:", _enemies_remaining)
	if _coins_remaining == 0 and _enemies_remaining == 0:
		print("LEVEL CLEARED!")
		level_cleared.emit()
		var game_on_connect := get_node_or_null(^"/root/GameOnPortal") as GameOnConnect
		if game_on_connect != null and game_on_connect.is_authorized:
			print("Unlocking artifact...")
			game_on_connect.unlock_artifact()
		else:
			print("Not authorized or GameOnPortal not found")


func _on_artifact_unlocked(_artifact_data: Dictionary, _is_new_unlock: bool) -> void:
	get_tree().change_scene_to_file("res://gui/level_complete.tscn")

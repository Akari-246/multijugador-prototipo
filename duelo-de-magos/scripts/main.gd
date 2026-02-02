extends Node2D

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _on_btn_lan_pressed() -> void:
	Global.network_mode = "lan"
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	
func _on_btn_steam_pressed() -> void:
	Global.network_mode = "steam"
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

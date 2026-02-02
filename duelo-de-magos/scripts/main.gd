extends Control

func _on_btn_steam_pressed() -> void:
	GlobalLobby.network_type = LobbyManager.NetworkType.STEAM
	get_tree().change_scene_to_packed(load("res://scenes/lobby.tscn"))

func _on_btn_lan_pressed() -> void:
	GlobalLobby.network_type = LobbyManager.NetworkType.LAN
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

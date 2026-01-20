extends Node2D

var peer = ENetMultiplayerPeer.new() #ahora en vez de ENetMultiplayer sera steam...
#@export var player: PackedScene

func _on_host_pressed() -> void:
	peer.create_server(3306)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(peer_connected) #conectar al coso en vez de addPlayer
	get_tree().change_scene_to_file("res://scenes/game.tscn") #addPlayer() #en vez de llamar a la funcion par aañadir jugador llamar a cambio de escena

func _on_join_pressed() -> void:
	peer.create_client("localhost", 3306)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(server_connected)

func peer_connected(id):
	print("Jugador conectado: ", id)
	
func server_connected():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

"""func addPlayer(id = 1):
	var playerI = player.instantiate()
	playerI.name = str(id)
	call_deferred("add_child", playerI)
"""

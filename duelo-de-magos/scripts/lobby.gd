extends Node2D

@onready var lobby_manager = LobbyManager.new()
@onready var hostBtn = $Host
@onready var joinBtn = $Join
@onready var ip_input = $IPInput
@onready var status_label = $StatusLabel

#var network_type: LobbyManager.NetworkType
var peer = ENetMultiplayerPeer.new() #ahora en vez de ENetMultiplayer sera steam...
#@export var player: PackedScene

func _ready():
	pass

func _on_host_pressed() -> void:
	peer.create_server(3306)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(peer_connected) #conectar al coso en vez de addPlayer
	get_tree().change_scene_to_file("res://scenes/game.tscn") #addPlayer() #en vez de llamar a la funcion par aañadir jugador llamar a cambio de escena

func _on_join_pressed() -> void:
	var ip = ip_input.text if ip_input.text != "" else "localhost"
	peer.create_client(ip, 3306)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(server_connected)
	#peer.create_client("localhost", 3306)
	#multiplayer.multiplayer_peer = peer
	#multiplayer.connected_to_server.connect(server_connected)

func peer_connected(id):
	print("Jugador conectado: ", id)

func server_connected():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

#func addPlayer(id = 1):
	#var playerI = player.instantiate()
	#playerI.name = str(id)
	#call_deferred("add_child", playerI)



#extends Node2D
#
#@onready var lobby_manager = LobbyManager.new()
#@onready var hostBtn = $Host
#@onready var joinBtn = $Join
#@onready var ip_input = $IPInput
#@onready var status_label = $StatusLabel
#
#var network_type: LobbyManager.NetworkType
##var peer = ENetMultiplayerPeer.new() #ahora en vez de ENetMultiplayer sera steam...
##@export var player: PackedScene
#
#func _ready():
	#print("=== GAME READY ===")
	#print("Soy servidor: ", multiplayer.is_server())
	#print("Mi ID: ", multiplayer.get_unique_id())
	#print("==================")
	#add_child(lobby_manager)
	#lobby_manager.server_created.connect(_on_server_created)
	#lobby_manager.connection_ok.connect(_on_connection_ok)
	#lobby_manager.connection_failed.connect(_on_connection_failed)
	#lobby_manager.player_joined.connect(playerJoined)
	#network_type = GlobalLobby.network_type
#
	#if ip_input:
		#ip_input.visible = (network_type == LobbyManager.NetworkType.LAN)
	#if network_type == LobbyManager.NetworkType.LAN:
		#status_label.text = "Modo LAN - Introduce IP o crea servidor"
	#else:
		#status_label.text = "Modo Steam - Amigos disponibles"
#
#func _on_host_pressed() -> void:
	##peer.create_server(3306)
	##multiplayer.multiplayer_peer = peer
	##multiplayer.peer_connected.connect(peer_connected) #conectar al coso en vez de addPlayer
	##get_tree().change_scene_to_file("res://scenes/game.tscn") #addPlayer() #en vez de llamar a la funcion par aañadir jugador llamar a cambio de escena
	#status_label.text = "Creando partida..."
	#hostBtn.disabled = true
	#joinBtn.disabled = true
	#if network_type == LobbyManager.NetworkType.LAN:
		#lobby_manager.host_lan()
	#else:
		#lobby_manager.host_steam()
		#
#func _on_join_pressed() -> void:
	##peer.create_client("localhost", 3306)
	##multiplayer.multiplayer_peer = peer
	##multiplayer.connected_to_server.connect(server_connected)
	#status_label.text = "Conectando..."
	#hostBtn.disabled = true
	#joinBtn.disabled = true
	#
	#if network_type == LobbyManager.NetworkType.LAN:
		#var ip = ip_input.text if ip_input.text != "" else "localhost"
		#lobby_manager.join_lan(ip)
	#else:
		##deberías mostrar una lista de lobbies de Steam, oor ahora, esto es un placeholder
		#var steam_lobby_id = 12345  #eto lo obtendrías de la lista de lobbies
		#lobby_manager.join_steam(steam_lobby_id)
#
##func peer_connected(id):
	##print("Jugador conectado: ", id)
	##
##func server_connected():
	##get_tree().change_scene_to_file("res://scenes/game.tscn")
##
##"""func addPlayer(id = 1):
	##var playerI = player.instantiate()
	##playerI.name = str(id)
	##call_deferred("add_child", playerI)
##"""
#
#func _on_server_created():
	#status_label.text = "Servidor creado! Esperando jugadores..."
	#print("servidor creado, esperando conexion")
#
#func playerJoined(id: int):
	#print("Jugador ", id, " se unió al lobby")
	#status_label.text = "Jugador conectado :D"
	#await get_tree().create_timer(0.5).timeout
	#startGame.rpc()
	#
#func _on_connection_ok():
	#status_label.text = "Conectado! Iniciando juego..."
#
#func _on_connection_failed():
	#status_label.text = "Error de conexión"
	#hostBtn.disabled = false
	#joinBtn.disabled = false
#
#@rpc("authority", "call_local", "reliable")
#func startGame():
	#print("RPC RECIBIDO por id: ", multiplayer.get_unique_id())
	#await get_tree().create_timer(0.3).timeout
	#get_tree().change_scene_to_file("res://scenes/game.tscn")

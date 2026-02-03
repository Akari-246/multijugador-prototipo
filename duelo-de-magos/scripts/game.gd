extends Node2D

@export var player: PackedScene
@onready var spawner = $MultiplayerSpawner
@onready var players = $MultiplayerSpawner/Players

# Posiciones de spawn
var spawn_positions = [
	Vector2(200, 300),
	Vector2(400, 300),
	Vector2(600, 300),
	Vector2(800, 300)
]

func _ready():
	await get_tree().create_timer(0.1).timeout
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(peer_connected)
		multiplayer.peer_disconnected.connect(peer_disconnected)
	
	addPlayer(multiplayer.get_unique_id())

func addPlayer(id: int):
	if players.has_node(str(id)):
		print("⚠️ Jugador %s ya existe" % id)
		return
	
	var playerI = player.instantiate()
	playerI.name = str(id)
	playerI.position = get_spawn_position()
	players.add_child(playerI, true)
	print("✅ Jugador añadido: %s" % id)

func get_spawn_position() -> Vector2:
	# Usar una posición aleatoria de la lista
	return spawn_positions[randi() % spawn_positions.size()]

func peer_connected(id: int):
	print("🔗 Nuevo jugador conectado: %s" % id)
	addPlayer(id)

func peer_disconnected(id: int):
	print("❌ Jugador desconectado: %s" % id)
	var player_node = players.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()

# NUEVO: En lugar de recargar escena, reposicionar jugador
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player_id = body.name.to_int()
		print("Jugador %s murió - Reposicionando..." % player_id)
		
		# Llamar con deferred para evitar error de física
		call_deferred("_respawn_player", body)

func _respawn_player(player_node: Node2D):
	if not is_instance_valid(player_node):
		return
	
	var new_pos = get_spawn_position()
	
	# Si es el servidor, reposicionar directamente
	if multiplayer.is_server():
		player_node.respawn(new_pos)
		# Notificar a todos los clientes
		rpc("sync_respawn", player_node.name.to_int(), new_pos)
	else:
		# Si es cliente, pedir al servidor que reposicione
		rpc_id(1, "request_respawn", player_node.name.to_int())

# RPC para que el cliente solicite respawn al servidor
@rpc("any_peer", "reliable")
func request_respawn(player_id: int):
	if not multiplayer.is_server():
		return
	
	var player_node = players.get_node_or_null(str(player_id))
	if player_node:
		var new_pos = get_spawn_position()
		player_node.respawn(new_pos)
		rpc("sync_respawn", player_id, new_pos)

# RPC para sincronizar el respawn en todos los clientes
@rpc("any_peer", "reliable")
func sync_respawn(player_id: int, pos: Vector2):
	var player_node = players.get_node_or_null(str(player_id))
	if player_node:
		player_node.respawn(pos)
		
		
#extends Node2D
#
#@export var player: PackedScene
#@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
#@onready var players: Node2D = $MultiplayerSpawner/Players
#
#func _ready():
	#if not spawner.spawn_function:
		#spawner.spawn_function  = spawn_player
	#await get_tree().create_timer(0.3).timeout
	
	#if multiplayer.is_server():
		#multiplayer.peer_connected.connect(peer_connected)
		#multiplayer.peer_disconnected.connect(peer_disconnected)
	#if multiplayer.is_server():
		#multiplayer.peer_connected.connect(peer_connected)
		#multiplayer.peer_disconnected.connect(peer_disconnected)
		#addPlayer(1)
	#else:
		#await get_tree().create_timer(0.3).timeout
		#addPlayer(multiplayer.get_unique_id())



#func spawn_player(data):
	#var playerI = player.instantiate()
	#return playerI
#
#func addPlayer(id: int):
	#if not multiplayer.is_server():
		#return
	#
	#if players.has_node(str(id)):
		#print("Jugador ", id, " ya existe")
		#
	#var playerI = player.instantiate()
	#playerI.name = str(id)
	##lo siguiente para posicionar a los jugadores en sitios distintos :D
	#playerI.position = Vector2(randf_range(100, 500), randf_range(100, 500))
	#players.add_child(playerI, true)
	#print("Jugador añadido: ", id, " | Total de jugadores: ", players.get_child_count())
#
#func peer_connected(id: int):
	#print("nuevo jugador conectado: ", id)
	#await get_tree().create_timer(0.5).timeout
	#addPlayer(id)
	#
#func peer_disconnected(id: int):
	#print("jugador desconectado: ", id)
	#if players.has_node(str(id)):
		#players.get_node(str(id)).queue_free()
	#

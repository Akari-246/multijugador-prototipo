extends Node2D

@export var player: PackedScene

@onready var spawner = $MultiplayerSpawner
@onready var players = $MultiplayerSpawner/Players

var spawn_positions = [
	Vector2(200, 300),
	Vector2(400, 300),
	Vector2(600, 300),
	Vector2(800, 300)
]

var used_spawn_indices = []

func _ready():
	print("[Game] ===== ESCENA DE JUEGO INICIADA =====")
	print("[Game] Unique ID: ", multiplayer.get_unique_id())
	print("[Game] Is server: ", multiplayer.is_server())
	
	# Notificar que hemos cargado
	LobbyManager.player_loaded.rpc()
	
	# Conectar señal de inicio
	if not LobbyManager.game_started.is_connected(_on_all_players_ready):
		LobbyManager.game_started.connect(_on_all_players_ready)
	
	# Configurar callbacks de multiplayer
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(peer_connected)
		multiplayer.peer_disconnected.connect(peer_disconnected)
		
		# Esperar un frame para que el multiplayer se estabilice
		await get_tree().process_frame

func _on_all_players_ready(scene_path: String):
	print("[Game] ===== TODOS LOS JUGADORES LISTOS =====")
	print("[Game] Jugadores totales: ", LobbyManager.players.size())
	
	# SOLO el servidor spawnea jugadores
	if not multiplayer.is_server():
		print("[Game] Soy cliente, esperando que el servidor spawnee jugadores")
		return
	
	# Resetear índices usados
	used_spawn_indices.clear()
	
	# Spawnear todos los jugadores (el MultiplayerSpawner sincronizará automáticamente)
	for id in LobbyManager.players:
		print("[Game] Spawneando jugador: ", id)
		addPlayer(id)

func addPlayer(id: int):
	# CRÍTICO: Solo el servidor debe llamar esto
	if not multiplayer.is_server():
		print("[Game] ⚠️ addPlayer llamado en cliente - ignorando")
		return
	
	if players.has_node(str(id)):
		print("[Game] ⚠️ Jugador %s ya existe" % id)
		return
	
	var playerI = player.instantiate()
	playerI.name = str(id)
	playerI.position = get_spawn_position()
	
	print("[Game] Añadiendo jugador %s en posición: %s" % [id, playerI.position])
	
	# El segundo parámetro 'true' hace que MultiplayerSpawner sincronice automáticamente
	players.add_child(playerI, true)
	
	print("[Game] ✅ Jugador %s añadido correctamente" % id)

func get_spawn_position() -> Vector2:
	# Si hemos usado todas las posiciones, resetear
	if used_spawn_indices.size() >= spawn_positions.size():
		used_spawn_indices.clear()
	
	# Encontrar un índice no usado
	var available_indices = []
	for i in range(spawn_positions.size()):
		if not used_spawn_indices.has(i):
			available_indices.append(i)
	
	# Elegir un índice aleatorio de los disponibles
	var chosen_index = available_indices[randi() % available_indices.size()]
	used_spawn_indices.append(chosen_index)
	
	return spawn_positions[chosen_index]

func peer_connected(id: int):
	print("[Game] ⚠️ Nuevo jugador intentó conectarse durante partida: %s" % id)
	# No hacer nada - el LobbyManager rechazará conexiones tardías

func peer_disconnected(id: int):
	print("[Game] Jugador desconectado: %s" % id)
	var player_node = players.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player_id = body.name.to_int()
		print("[Game] Jugador %s murió - Reposicionando..." % player_id)
		call_deferred("_respawn_player", body)

func _respawn_player(player_node: Node2D):
	if not is_instance_valid(player_node):
		return
	
	var new_pos = get_spawn_position()
	
	if multiplayer.is_server():
		player_node.respawn(new_pos)
		rpc("sync_respawn", player_node.name.to_int(), new_pos)
	else:
		rpc_id(1, "request_respawn", player_node.name.to_int())

@rpc("any_peer", "reliable")
func request_respawn(player_id: int):
	if not multiplayer.is_server():
		return
	
	var player_node = players.get_node_or_null(str(player_id))
	if player_node:
		var new_pos = get_spawn_position()
		player_node.respawn(new_pos)
		rpc("sync_respawn", player_id, new_pos)

@rpc("any_peer", "reliable")
func sync_respawn(player_id: int, pos: Vector2):
	var player_node = players.get_node_or_null(str(player_id))
	if player_node:
		player_node.respawn(pos)

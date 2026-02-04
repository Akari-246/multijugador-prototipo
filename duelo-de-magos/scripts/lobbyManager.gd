class_name lobbyManager extends Node

signal connection_ok
signal connection_failed
signal server_created
signal player_joined(id: int, player_info: Dictionary)
signal player_left(id: int)
signal game_started(scene_path: String)

enum NetworkType { LAN, STEAM }

const DEFAULT_PORT = 3306
const MAX_PLAYERS = 4

var current_network_type: NetworkType
var players = {}
var player_info = {"name": "Player", "avatar": "p1"}

var lan_peer: ENetMultiplayerPeer
var steam_peer: SteamMultiplayerPeer
var lobby_id: int = 0
var is_host: bool = false

var game_started_flag: bool = false
var players_loaded: int = 0
var game_scene_path: String = ""

# Flags de control para evitar duplicados
var _steam_initialized: bool = false
var _is_creating_peer: bool = false

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ========== CREAR PARTIDA ==========
func host_lan(port: int = DEFAULT_PORT):
	current_network_type = NetworkType.LAN
	lan_peer = ENetMultiplayerPeer.new()
	
	var error = lan_peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("[LobbyManager] Error creando servidor LAN: ", error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = lan_peer
	is_host = true
	players[1] = player_info.duplicate()
	print("[LobbyManager] Servidor LAN creado en puerto ", port)
	server_created.emit()
	player_joined.emit(1, player_info)

func host_steam():
	current_network_type = NetworkType.STEAM
	if not _init_steam():
		connection_failed.emit()
		return
	print("[LobbyManager] Creando lobby Steam...")
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)

# ========== UNIRSE A PARTIDA ==========
func join_lan(address: String, port: int = DEFAULT_PORT):
	current_network_type = NetworkType.LAN
	lan_peer = ENetMultiplayerPeer.new()
	
	var error = lan_peer.create_client(address, port)
	if error != OK:
		print("[LobbyManager] Error conectando a servidor LAN: ", error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = lan_peer
	print("[LobbyManager] Conectando a ", address, ":", port)

func join_steam(steam_lobby_id: int):
	current_network_type = NetworkType.STEAM
	print("[LobbyManager] ===== INICIANDO JOIN STEAM =====")
	
	if not _init_steam():
		print("[LobbyManager] ERROR: No se pudo inicializar Steam")
		connection_failed.emit()
		return
	
	lobby_id = steam_lobby_id
	print("[LobbyManager] Intentando unirse a lobby: ", lobby_id)
	Steam.joinLobby(lobby_id)

# ========== STEAM INTERNALS ==========
func _init_steam() -> bool:
	# Si ya está inicializado, no repetir
	if _steam_initialized:
		print("[LobbyManager] Steam ya inicializado previamente")
		return true
	
	print("[LobbyManager] ----- Inicializando Steam -----")
	
	if not Steam.isSteamRunning():
		print("[LobbyManager] ❌ ERROR: Steam no está corriendo")
		return false
	
	print("[LobbyManager] ✅ Steam está corriendo")
	
	var status = Steam.steamInit(480, true)
	if not status:
		print("[LobbyManager] ❌ ERROR inicializando Steam API")
		return false
	
	print("[LobbyManager] ✅ Steam API inicializada")
	
	steam_peer = SteamMultiplayerPeer.new()
	print("[LobbyManager] ✅ SteamMultiplayerPeer creado")
	
	# Conectar señales
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	print("[LobbyManager] ✅ Señales Steam conectadas")
	
	Steam.initRelayNetworkAccess()
	print("[LobbyManager] ✅ Relay network access inicializado")
	
	_steam_initialized = true
	print("[LobbyManager] ----- Steam inicializado correctamente -----")
	return true

func _on_steam_lobby_created(result: int, _lobby_id: int):
	print("[LobbyManager] ===== CALLBACK: LOBBY CREADO =====")
	print("[LobbyManager] Result: ", result)
	print("[LobbyManager] Lobby ID: ", _lobby_id)
	
	if result != Steam.Result.RESULT_OK:
		print("[LobbyManager] ❌ Error creando lobby Steam: ", result)
		connection_failed.emit()
		return
	
	lobby_id = _lobby_id
	
	if _is_creating_peer:
		print("[LobbyManager] ⚠️ Ya estamos creando peer, ignorando...")
		return
	
	_is_creating_peer = true
	
	steam_peer.server_relay = true
	print("[LobbyManager] Llamando a create_host()...")
	var error = steam_peer.create_host()
	print("[LobbyManager] create_host() retornó: ", error)
	
	if error != OK:
		print("[LobbyManager] ❌ Error creando host Steam: ", error)
		_is_creating_peer = false
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = steam_peer
	is_host = true
	players[1] = player_info.duplicate()
	
	_is_creating_peer = false
	
	print("[LobbyManager] ✅ Lobby Steam creado exitosamente")
	print("[LobbyManager] ===================================")
	
	server_created.emit()
	player_joined.emit(1, player_info)

func _on_steam_lobby_joined(_lobby_id: int, _permissions: int, _locked: bool, response: int):
	print("[LobbyManager] ===== CALLBACK: LOBBY JOINED =====")
	print("[LobbyManager] Lobby ID: ", _lobby_id)
	print("[LobbyManager] Response: ", response)
	
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("[LobbyManager] ❌ Error uniéndose al lobby: ", response)
		connection_failed.emit()
		return
	
	lobby_id = _lobby_id
	var owner_id = Steam.getLobbyOwner(_lobby_id)
	var my_steam_id = Steam.getSteamID()
	
	print("[LobbyManager] Owner ID: ", owner_id)
	print("[LobbyManager] My Steam ID: ", my_steam_id)
	
	# Si somos el dueño, esto es el auto-join del host
	if owner_id == my_steam_id:
		print("[LobbyManager] ℹ️ Somos el dueño, ignorando auto-join")
		return
	
	# CLIENTE: unirse al host
	if _is_creating_peer:
		print("[LobbyManager] ⚠️ Ya estamos creando peer, ignorando...")
		return
	
	_is_creating_peer = true
	
	steam_peer.server_relay = true
	print("[LobbyManager] Llamando a create_client(", owner_id, ")...")
	var error = steam_peer.create_client(owner_id)
	print("[LobbyManager] create_client() retornó: ", error)
	
	if error != OK:
		print("[LobbyManager] ❌ Error creando cliente Steam: ", error)
		_is_creating_peer = false
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = steam_peer
	_is_creating_peer = false
	
	print("[LobbyManager] ✅ Cliente Steam creado, esperando conexión...")
	print("[LobbyManager] ==================================")

# ========== CALLBACKS DE MULTIPLAYER ==========
func _on_peer_connected(id: int):
	print("[LobbyManager] ===== PEER CONNECTED =====")
	print("[LobbyManager] ID: ", id)
	print("[LobbyManager] Game started: ", game_started_flag)
	print("[LobbyManager] Is host: ", is_host)
	
	if game_started_flag:
		print("[LobbyManager] Rechazando - juego ya iniciado")
		_reject_late_joiner.rpc_id(id)
		return
	
	if is_host:
		print("[LobbyManager] Enviando info de host al nuevo jugador")
		# Enviar info del host
		_register_player.rpc_id(id, player_info)
		
		# Enviar info de todos los jugadores existentes al nuevo
		for existing_id in players:
			if existing_id != 1 and existing_id != id:
				_send_existing_player.rpc_id(id, existing_id, players[existing_id])

func _on_peer_disconnected(id: int):
	print("[LobbyManager] ===== PEER DISCONNECTED =====")
	print("[LobbyManager] ID: ", id)
	players.erase(id)
	player_left.emit(id)

func _on_connected_to_server():
	print("[LobbyManager] ===== CONNECTED TO SERVER =====")
	var my_id = multiplayer.get_unique_id()
	print("[LobbyManager] Mi ID: ", my_id)
	
	players[my_id] = player_info.duplicate()
	
	# Registrarse con el servidor
	_register_player.rpc_id(1, player_info)
	
	connection_ok.emit()

func _on_connection_failed():
	print("[LobbyManager] ===== CONNECTION FAILED =====")
	_is_creating_peer = false
	connection_failed.emit()

func _on_server_disconnected():
	print("[LobbyManager] ===== SERVER DISCONNECTED =====")
	disconnect_from_game()

# ========== RPC - REGISTRO DE JUGADORES ==========
@rpc("any_peer", "reliable")
func _register_player(new_player_info: Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	print("[LobbyManager] ===== REGISTRANDO JUGADOR =====")
	print("[LobbyManager] ID: ", new_player_id)
	print("[LobbyManager] Info: ", new_player_info)
	
	players[new_player_id] = new_player_info
	player_joined.emit(new_player_id, new_player_info)
	
	# Si somos host, notificar a todos los demás del nuevo jugador
	if is_host and new_player_id != 1:
		for peer_id in multiplayer.get_peers():
			if peer_id != new_player_id:
				_send_existing_player.rpc_id(peer_id, new_player_id, new_player_info)

@rpc("any_peer", "reliable")
func _send_existing_player(player_id: int, info: Dictionary):
	print("[LobbyManager] ===== JUGADOR EXISTENTE RECIBIDO =====")
	print("[LobbyManager] ID: ", player_id)
	print("[LobbyManager] Info: ", info)
	
	if not players.has(player_id):
		players[player_id] = info
		player_joined.emit(player_id, info)

@rpc("any_peer", "call_remote", "reliable")
func _reject_late_joiner():
	print("[LobbyManager] ===== RECHAZADO: JUEGO INICIADO =====")
	disconnect_from_game()
	connection_failed.emit()

# ========== INICIAR PARTIDA ==========
func start_game(scene_path: String):
	if not is_host:
		print("[LobbyManager] ❌ Solo el host puede iniciar")
		return
	
	print("[LobbyManager] ===== INICIANDO PARTIDA =====")
	print("[LobbyManager] Escena: ", scene_path)
	print("[LobbyManager] Jugadores: ", players.size())
	
	game_started_flag = true
	game_scene_path = scene_path
	players_loaded = 0
	
	_load_game.rpc(scene_path)

@rpc("call_local", "reliable")
func _load_game(scene_path: String):
	print("[LobbyManager] ===== CARGANDO ESCENA DE JUEGO =====")
	print("[LobbyManager] Escena: ", scene_path)
	game_scene_path = scene_path
	game_started_flag = true
	get_tree().change_scene_to_file(scene_path)

@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if is_host:
		players_loaded += 1
		print("[LobbyManager] ===== JUGADOR CARGADO =====")
		print("[LobbyManager] Cargados: ", players_loaded, "/", players.size())
		
		if players_loaded >= players.size():
			print("[LobbyManager] ===== TODOS LISTOS - EMPEZANDO =====")
			_start_game_for_all.rpc()

@rpc("call_local", "reliable")
func _start_game_for_all():
	print("[LobbyManager] ===== INICIO CONFIRMADO =====")
	game_started.emit(game_scene_path)

# ========== UTILIDADES ==========
func disconnect_from_game():
	print("[LobbyManager] ===== DESCONECTANDO =====")
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	game_started_flag = false
	players_loaded = 0
	_is_creating_peer = false
	
	if current_network_type == NetworkType.STEAM and lobby_id > 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0

func get_player_count() -> int:
	return players.size()

func get_lobby_code() -> String:
	if current_network_type == NetworkType.STEAM:
		return str(lobby_id)
	return ""
	

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
		print("Error creando servidor LAN: ", error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = lan_peer
	is_host = true
	players[1] = player_info.duplicate()
	print("Servidor LAN creado en puerto ", port)
	server_created.emit()
	player_joined.emit(1, player_info)

func host_steam():
	current_network_type = NetworkType.STEAM
	if not _init_steam():
		connection_failed.emit()
		return
	print("Creando lobby Steam...")
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)

# ========== UNIRSE A PARTIDA ==========
func join_lan(address: String, port: int = DEFAULT_PORT):
	current_network_type = NetworkType.LAN
	lan_peer = ENetMultiplayerPeer.new()
	
	var error = lan_peer.create_client(address, port)
	if error != OK:
		print("Error conectando a servidor LAN: ", error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = lan_peer
	print("Conectando a ", address, ":", port)

func join_steam(steam_lobby_id: int):
	current_network_type = NetworkType.STEAM
	if not _init_steam():
		connection_failed.emit()
		return
	lobby_id = steam_lobby_id
	print("Uniéndose a lobby Steam: ", lobby_id)
	Steam.joinLobby(lobby_id)

# ========== STEAM INTERNALS ==========
func _init_steam() -> bool:
	# Verificar que Steam esté disponible
	if not Steam.isSteamRunning():
		print("[LobbyManager] Error: Steam no está corriendo")
		return false
	
	# Si ya está inicializado, no volver a inicializar
	if steam_peer != null:
		print("[LobbyManager] Steam ya inicializado")
		return true
	
	# Inicializar Steam
	var status = Steam.steamInit(480, true)
	if not status:
		print("[LobbyManager] Error inicializando Steam")
		return false
	
	steam_peer = SteamMultiplayerPeer.new()
	
	# Conectar señales solo una vez
	if not Steam.lobby_created.is_connected(_on_steam_lobby_created):
		Steam.lobby_created.connect(_on_steam_lobby_created)
	if not Steam.lobby_joined.is_connected(_on_steam_lobby_joined):
		Steam.lobby_joined.connect(_on_steam_lobby_joined)
	
	Steam.initRelayNetworkAccess()
	
	print("[LobbyManager] Steam inicializado correctamente")
	return true

func _on_steam_lobby_created(result: int, _lobby_id: int):
	if result != Steam.Result.RESULT_OK:
		print("Error creando lobby Steam: ", result)
		connection_failed.emit()
		return
	
	lobby_id = _lobby_id
	var peer_status  =steam_peer.get_connection_status()
	if peer_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		steam_peer.server_relay = true
		var error= steam_peer.create_host()
		if error != OK:
			print("Error creando host Steam: ", error)
			connection_failed.emit()
			return
	#steam_peer.create_host()
	multiplayer.multiplayer_peer = steam_peer
	is_host = true
	players[1] = player_info.duplicate()
	print("[LobbyManager] Lobby Steam creado exitosamente: ", lobby_id)
	server_created.emit()
	player_joined.emit(1, player_info)

func _on_steam_lobby_joined(_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Error uniéndose al lobby: ", response)
		connection_failed.emit()
		return
	
	var owner_id = Steam.getLobbyOwner(_lobby_id)
	if steam_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		steam_peer.server_relay = true
		var error = steam_peer.create_client(owner_id)
		if error != OK:
			print("Error creando cliente Steam: ", error)
			connection_failed.emit()
			return
	
	multiplayer.multiplayer_peer = steam_peer
	print("Unido al lobby Steam c: : ", _lobby_id)

# ========== CALLBACKS DE MULTIPLAYER ==========
func _on_peer_connected(id: int):
	print("[LobbyManager] Jugador conectado: ", id)
	
	# Si ya empezó el juego, rechazar al nuevo jugador
	if game_started_flag:
		_reject_late_joiner.rpc_id(id)
		return
	
	# Si soy host, le envío mi info al nuevo jugador
	if is_host:
		_register_player.rpc_id(id, player_info)

func _on_peer_disconnected(id: int):
	print("[LobbyManager] Jugador desconectado: ", id)
	players.erase(id)
	player_left.emit(id)

func _on_connected_to_server():
	var my_id = multiplayer.get_unique_id()
	players[my_id] = player_info.duplicate()
	print("[LobbyManager] Conectado al servidor como: ", my_id)
	
	# Le envío mi info al servidor
	_register_player.rpc_id(1, player_info)
	connection_ok.emit()

func _on_connection_failed():
	print("[LobbyManager] Falló la conexión")
	connection_failed.emit()

func _on_server_disconnected():
	print("[LobbyManager] Servidor desconectado")
	disconnect_from_game()

# ========== RPC - REGISTRO DE JUGADORES ==========
@rpc("any_peer", "reliable")
func _register_player(new_player_info: Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	print("[LobbyManager] Registrado jugador ", new_player_id, ": ", new_player_info)
	player_joined.emit(new_player_id, new_player_info)

@rpc("any_peer", "call_remote", "reliable")
func _reject_late_joiner():
	print("[LobbyManager] Partida ya iniciada, no puedes unirte")
	disconnect_from_game()
	connection_failed.emit()

# ========== INICIAR PARTIDA ==========
func start_game(scene_path: String):
	if not is_host:
		print("[LobbyManager] Solo el host puede iniciar la partida")
		return
	
	game_started_flag = true
	game_scene_path = scene_path
	print("[LobbyManager] Iniciando partida...")
	
	# Notificar a todos los clientes
	_load_game.rpc(scene_path)

@rpc("call_local", "reliable") #antes era remote
func _load_game(scene_path: String):
	game_scene_path = scene_path
	get_tree().change_scene_to_file(scene_path)

# Cada jugador llama a esto cuando carga la escena del juego
@rpc("any_peer", "call_local", "reliable")
func player_loaded():
	if is_host:
		players_loaded += 1
		print("[LobbyManager] Jugadores cargados: ", players_loaded, "/", players.size())
		
		if players_loaded == players.size():
			print("[LobbyManager] Todos los jugadores cargados, empezando partida")
			game_started.emit(game_scene_path)

# ========== UTILIDADES ==========
func disconnect_from_game():
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	game_started_flag = false
	players_loaded = 0
	
	if current_network_type == NetworkType.STEAM and lobby_id > 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0

func get_player_count() -> int:
	return players.size()

func get_lobby_code() -> String:
	if current_network_type == NetworkType.STEAM:
		return str(lobby_id)
	return ""

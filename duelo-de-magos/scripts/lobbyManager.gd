class_name LobbyManager extends Node

signal connection_ok
signal connection_failed
signal server_created
signal player_joined(id: int) 

enum NetworkType { LAN, STEAM }

const DEFAULT_PORT = 3306
const MAX_PLAYERS = 4
var current_network_type: NetworkType
var players = {}
var player_info = {"name": "Player", "avatar": "p1"}
var lan_peer: ENetMultiplayerPeer
var steam_peer: SteamMultiplayerPeer
var lobby_id: int = 0

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# CREAR PARTIDA
func host_lan(port: int = DEFAULT_PORT):
	current_network_type = NetworkType.LAN
	lan_peer = ENetMultiplayerPeer.new()
	
	var error = lan_peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("Error creando servidor LAN: ", error)
		connection_failed.emit()
		return
	
	multiplayer.multiplayer_peer = lan_peer
	players[1] = player_info
	print("Servidor LAN creado en puerto ", port)
	server_created.emit()

func host_steam():
	current_network_type = NetworkType.STEAM
	if not _init_steam():
		connection_failed.emit()
		return
	print("Creando lobby Steam...")
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)

# UNIRSE A PARTIDA
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

# FUNCIONES INTERNAS DE STEAM
func _init_steam() -> bool:
	if steam_peer and steam_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		print("Steam ya está conectado")
		return true
	var status = Steam.steamInit(480, true)
	if not status:
		print("Error inicializando Steam")
		return false

	steam_peer = SteamMultiplayerPeer.new()
	if Steam.lobby_created.is_connected(_on_steam_lobby_created):
		Steam.lobby_created.disconnect(_on_steam_lobby_created)
	if Steam.lobby_joined.is_connected(_on_steam_lobby_joined):
		Steam.lobby_joined.disconnect(_on_steam_lobby_joined)
	
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.initRelayNetworkAccess()
	print("Steam inicializado")
	return true

func _on_steam_lobby_created(result: int, _lobby_id: int):
	if result != Steam.Result.RESULT_OK:
		print("Error creando lobby Steam: ", result)
		connection_failed.emit()
		return
	
	lobby_id = _lobby_id
	steam_peer.create_host()
	multiplayer.multiplayer_peer = steam_peer
	players[1] = player_info
	print("Lobby Steam creado: ", lobby_id)
	server_created.emit()

func _on_steam_lobby_joined(_lobby_id: int, _permissions: int, _locked: bool, response: int):
	if response != Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Error uniéndose al lobby: ", response)
		connection_failed.emit()
		return
	
	var owner_id = Steam.getLobbyOwner(_lobby_id)
	steam_peer.create_client(owner_id)
	multiplayer.multiplayer_peer = steam_peer
	print("Unido a lobby Steam: ", _lobby_id)

# CALLBACKS DE MULTIPLAYER
func _on_peer_connected(id: int):
	print("[LobbyManager] Jugador conectado: ", id)
	players[id] = {"name": "Player " + str(id)}
	player_joined.emit(id)

func _on_peer_disconnected(id: int):
	print("[LobbyManager] Jugador desconectado: ", id)
	players.erase(id)

func _on_connected_to_server():
	var my_id = multiplayer.get_unique_id()
	players[my_id] = player_info
	print("[LobbyManager] Conectado al servidor como: ", my_id)
	connection_ok.emit()

func _on_connection_failed():
	print("[LobbyManager] Falló la conexión")
	connection_failed.emit()

func _on_server_disconnected():
	print("[LobbyManager] Servidor desconectado")
	disconnect_from_game()

# UTILIDADES
func disconnect_from_game():
	multiplayer.multiplayer_peer = null
	players.clear()
	if current_network_type == NetworkType.STEAM and lobby_id > 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0

func get_player_count() -> int:
	return players.size()

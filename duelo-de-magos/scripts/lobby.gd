extends Node2D

@onready var lobby_manager = LobbyManager

@onready var hostBtn = $Host
@onready var joinBtn = $Join
@onready var startBtn = $StartGame
@onready var ip_input = $IPInput
@onready var status_label = $StatusLabel
@onready var steam_container = $SteamContainer
@onready var lobby_input = $SteamContainer/LobbyInput
@onready var invite_btn = $SteamContainer/InviteButton
@onready var player_list = $PlayerList

@export var game_scene: PackedScene

var network_type: LobbyManager.NetworkType

func _ready():
	network_type = GlobalLobby.network_type
	
	# Configurar player_info antes de conectar
	lobby_manager.player_info["name"] = "Player_" + str(randi() % 1000)
	
	# Desconectar señales previas para evitar duplicados
	if lobby_manager.server_created.is_connected(_on_server_created):
		lobby_manager.server_created.disconnect(_on_server_created)
	if lobby_manager.connection_ok.is_connected(_on_connection_ok):
		lobby_manager.connection_ok.disconnect(_on_connection_ok)
	if lobby_manager.connection_failed.is_connected(_on_connection_failed):
		lobby_manager.connection_failed.disconnect(_on_connection_failed)
	if lobby_manager.player_joined.is_connected(_on_player_joined):
		lobby_manager.player_joined.disconnect(_on_player_joined)
	if lobby_manager.player_left.is_connected(_on_player_left):
		lobby_manager.player_left.disconnect(_on_player_left)
	
	# Conectar señales
	lobby_manager.server_created.connect(_on_server_created)
	lobby_manager.connection_ok.connect(_on_connection_ok)
	lobby_manager.connection_failed.connect(_on_connection_failed)
	lobby_manager.player_joined.connect(_on_player_joined)
	lobby_manager.player_left.connect(_on_player_left)
	
	# Solo conectar Steam si estamos en modo Steam
	if network_type == LobbyManager.NetworkType.STEAM:
		if Steam.isSteamRunning():
			if not Steam.join_requested.is_connected(_on_steam_join_requested):
				Steam.join_requested.connect(_on_steam_join_requested)
		else:
			print("[Lobby] Advertencia: Steam no está corriendo")
	
	_setup_ui()

func _setup_ui():
	startBtn.visible = false
	invite_btn.disabled = true
	
	if network_type == LobbyManager.NetworkType.LAN:
		ip_input.visible = true
		steam_container.visible = false
		status_label.text = "Modo LAN"
		
	elif network_type == LobbyManager.NetworkType.STEAM:
		ip_input.visible = false
		steam_container.visible = true
		status_label.text = "Modo Steam"
		
		await get_tree().process_frame
		
		if Steam and Steam.isSteamRunning():
			if Steam.getSteamID() > 0:
				var steam_name = Steam.getFriendPersonaName(Steam.getSteamID())
				status_label.text = "Steam: " + steam_name
				lobby_manager.player_info["name"] = steam_name
			else:
				status_label.text = "Steam: No logueado"
		else:
			status_label.text = "ERROR: Steam no está corriendo"
			hostBtn.disabled = true
			joinBtn.disabled = true

# ========== BOTONES ==========
func _on_host_pressed() -> void:
	status_label.text = "Creando servidor..."
	hostBtn.disabled = true
	joinBtn.disabled = true
	
	if network_type == LobbyManager.NetworkType.LAN:
		lobby_manager.host_lan(3306)
	elif network_type == LobbyManager.NetworkType.STEAM:
		lobby_manager.host_steam()

func _on_join_pressed() -> void:
	status_label.text = "Conectando..."
	hostBtn.disabled = true
	joinBtn.disabled = true
	
	if network_type == LobbyManager.NetworkType.LAN:
		var ip = ip_input.text if ip_input.text != "" else "localhost"
		lobby_manager.join_lan(ip, 3306)
		
	elif network_type == LobbyManager.NetworkType.STEAM:
		var lobby_code = lobby_input.text.to_int()
		if lobby_code > 0:
			lobby_manager.join_steam(lobby_code)
		else:
			status_label.text = "Introduce un código de lobby válido"
			hostBtn.disabled = false
			joinBtn.disabled = false

func _on_start_game_pressed() -> void:
	if lobby_manager.is_host and game_scene:
		status_label.text = "Iniciando partida..."
		startBtn.disabled = true
		lobby_manager.start_game(game_scene.resource_path)
	else:
		status_label.text = "Solo el host puede iniciar"

func _on_invite_button_pressed() -> void:
	if network_type == LobbyManager.NetworkType.STEAM and Steam.isSteamRunning():
		Steam.activateGameOverlayInviteDialog(lobby_manager.lobby_id)

# ========== CALLBACKS ==========
func _on_server_created():
	status_label.text = "Servidor creado. Esperando jugadores..."
	startBtn.visible = true
	
	if network_type == LobbyManager.NetworkType.STEAM:
		lobby_input.text = str(lobby_manager.lobby_id)
		invite_btn.disabled = false
		status_label.text = "Lobby: " + str(lobby_manager.lobby_id)
	
	_update_player_list()

func _on_connection_ok():
	status_label.text = "Conectado al servidor"
	startBtn.visible = false
	_update_player_list()

func _on_connection_failed():
	status_label.text = "Error de conexión"
	hostBtn.disabled = false
	joinBtn.disabled = false

func _on_player_joined(id: int, player_info: Dictionary):
	var player_name = player_info.get("name", "Player")
	status_label.text = "Jugador conectado: " + player_name
	print("[Lobby] Jugador unido - ID: ", id, " Nombre: ", player_name)
	_update_player_list()

func _on_player_left(id: int):
	status_label.text = "Jugador desconectado"
	_update_player_list()

func _on_steam_join_requested(_lobby_id: int, _friend_id: int):
	if network_type == LobbyManager.NetworkType.STEAM:
		lobby_input.text = str(_lobby_id)
		_on_join_pressed()

# ========== HELPERS ==========
func _update_player_list():
	for child in player_list.get_children():
		child.queue_free()
	
	print("[Lobby] Actualizando lista de jugadores. Total: ", lobby_manager.players.size())
	for id in lobby_manager.players:
		var info = lobby_manager.players[id]
		var label = Label.new()
		label.text = info.get("name", "Player " + str(id)) + " (ID: " + str(id) + ")"
		player_list.add_child(label)
		print("[Lobby] - ", label.text)

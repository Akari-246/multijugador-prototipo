extends Node2D

@onready var lobby_manager = LobbyManager
@onready var hostBtn = $Host
@onready var joinBtn = $Join
@onready var startBtn = $StartGame
@onready var ip_input = $IPInput
@onready var status_label = $StatusLabel
@onready var steam_container = $SteamContainer
@onready var lobby_input = $SteamContainer/LobbyInput  #para código de lobby?
@onready var invite_btn = $SteamContainer/InviteButton  #para invitar amigos
@onready var player_list = $PlayerList  #eto para mostrar jugadores
@export var game_scene: PackedScene

var network_type: LobbyManager.NetworkType

func _ready():
	network_type = GlobalLobby.network_type
	
	lobby_manager.player_info["name"] = "Player_" + str(randi() % 1000)
	#señales
	lobby_manager.server_created.connect(_on_server_created)
	lobby_manager.connection_ok.connect(_on_connection_ok)
	lobby_manager.connection_failed.connect(_on_connection_failed)
	lobby_manager.player_joined.connect(_on_player_joined)
	lobby_manager.player_left.connect(_on_player_left)
	
	#señal de invitación de Steam
	if network_type == LobbyManager.NetworkType.STEAM:
		Steam.join_requested.connect(_on_steam_join_requested)
	
	_setup_ui() #configurar UI según el tipo de red

func _setup_ui():
	startBtn.visible = false
	invite_btn.disabled = true
	
	if network_type == LobbyManager.NetworkType.LAN:
		#mostrar campos de LAN, ocultar Steam
		ip_input.visible = true
		steam_container.visible = false
		status_label.text = "Modo LAN"
		
	elif network_type == LobbyManager.NetworkType.STEAM:
		#ocultar campos de LAN, mostrar Steam
		ip_input.visible = false
		steam_container.visible = true
		status_label.text = "Modo Steam"
		
		#si está logueado en Steam, mostrar nombre
		if Steam.isSteamRunning() and Steam.loggedOn():
			var steam_name = Steam.getFriendPersonaName(Steam.getSteamID())
			status_label.text = "Steam: " + steam_name
			lobby_manager.player_info["name"] = steam_name
		else:
			status_label.text = "Steam no conectado :c"

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
		lobby_manager.start_game(game_scene.resource_path)
	else:
		status_label.text = "Solo el host puede iniciar"

func _on_invite_button_pressed() -> void:
	if network_type == LobbyManager.NetworkType.STEAM:
		Steam.activateGameOverlayInviteDialog(lobby_manager.lobby_id)

# ========== CALLBACKS ==========
func _on_server_created():
	status_label.text = "Servidor creado. Esperando jugadores..."
	startBtn.visible = true  #mostrar botón de inicio para el host
	
	#si es Steam, mostrar el código del lobby
	if network_type == LobbyManager.NetworkType.STEAM:
		lobby_input.text = str(lobby_manager.lobby_id)
		invite_btn.disabled = false
		status_label.text = "Lobby: " + str(lobby_manager.lobby_id)

func _on_connection_ok():
	status_label.text = "Conectado al servidor"

func _on_connection_failed():
	status_label.text = "Error de conexión"
	hostBtn.disabled = false
	joinBtn.disabled = false

func _on_player_joined(id: int, player_info: Dictionary):
	status_label.text = "Jugador conectado: " + player_info.get("name", "Player")
	_update_player_list()

func _on_player_left(id: int):
	status_label.text = "Jugador desconectado"
	_update_player_list()

func _on_steam_join_requested(_lobby_id: int, _friend_id: int):
	#cuando un amigo te invita desde Steam
	if network_type == LobbyManager.NetworkType.STEAM:
		lobby_input.text = str(_lobby_id)
		_on_join_pressed()

# ========== HELPERS ==========
func _update_player_list():
	for child in player_list.get_children():
		child.queue_free()
	
	#añadir cada jugador
	for id in lobby_manager.players:
		var info = lobby_manager.players[id]
		var label = Label.new()
		label.text = info.get("name", "Player " + str(id))
		player_list.add_child(label)

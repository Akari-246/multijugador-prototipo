extends Node2D

@export var player: PackedScene
@onready var spawner = $MultiplayerSpawner
@onready var players = $MultiplayerSpawner/Players

func _ready():
	await get_tree().create_timer(0.1).timeout
	var id = multiplayer.get_unique_id()
	addPlayer(id)
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(peer_connected)
	else:
		addPlayer(multiplayer.get_unique_id())

func addPlayer(id: int):
	#esto para evitar duplicadoss
	if players.has_node(str(id)):
		return
		
	var playerI = player.instantiate()
	playerI.name = str(id)
	#lo siguiente para posicionar a los jugadores en sitios distintos :D
	playerI.position = Vector2(randf_range(100, 500), randf_range(100, 500))
	players.add_child(playerI, true)
	print("Jugador añadido: ", id)

func peer_connected(id: int):
	print("nuevo jugador conectado: ", id)
	addPlayer(id)

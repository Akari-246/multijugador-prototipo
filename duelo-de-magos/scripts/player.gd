extends CharacterBody2D

const SPEED = 300
const JUMP_VELOCITY = -550
const ATTACK_DURATION = 0.5

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_buffer_time = 0.12
var jump_buffer = 0.0
var is_attacking = false
var facing_right = true  #var para monitorear la dirección
var bullet =preload("res://scenes/bala_fuego.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var spawnPoint: Marker2D = $SpawnPoint

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if camera:
		camera.enabled = is_multiplayer_authority()
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	if is_multiplayer_authority():
		handle_input(delta)
	
	move_and_slide()
	update_animations()

func handle_input(delta: float):
	#ATAQUE/disparar fuego
	if Input.is_action_just_pressed("ataque") and can_attack():
		attack()
		shoot()
		return
	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		return
	
	#SALTO
	if Input.is_action_just_pressed("salto"):
		jump_buffer = jump_buffer_time
	else:
		jump_buffer -= delta
	
	if jump_buffer > 0 and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0
	
	#MOV HORIZONTAL
	var direction = Input.get_axis("moverIzq", "moverDere")
	if direction != 0:
		velocity.x = direction * SPEED
		#actualizar dirección y sincronizar:
		var new_facing = (direction > 0)
		if new_facing != facing_right:
			facing_right = new_facing
			update_sprite_direction()
			safe_rpc("sync_direction", facing_right)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func shoot():
	var offset = 30
	var shoot_direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	var shoot_position = global_position + (shoot_direction * offset)
	
	spawn_bullet(shoot_position, shoot_direction) #bala local
	rpc("sync_shoot", shoot_position, shoot_direction, name.to_int())

func spawn_bullet(pos: Vector2, dir: Vector2):
	var newBala = bullet.instantiate()
	newBala.direction_vector = dir
	newBala.shooter_id =name.to_int()
	newBala.global_position = pos
	#newBala.shooter_id = multiplayer.get_unique_id()  #identificar quién disparó
	get_tree().root.add_child(newBala)  #añadir a la raíz para evitar problemas

@rpc("any_peer", "reliable")
func sync_shoot(pos: Vector2, dir: Vector2, shooter_id: int):
	if multiplayer.get_unique_id() != shooter_id:
		var newBala = bullet.instantiate()
		newBala.direction_vector = dir
		newBala.shooter_id = shooter_id
		newBala.global_position = pos
		get_tree().root.add_child(newBala)
	
	
func safe_rpc(method: String, arg = null):
	if not is_inside_tree() or multiplayer.get_peers().size() == 0:
		return
	if arg != null:
		rpc(method, arg)
	else:
		rpc(method)

func update_sprite_direction():
	if sprite:
		sprite.flip_h = facing_right

@rpc("any_peer", "unreliable") #antes era reliable 
func sync_direction(is_right: bool):
	if not is_inside_tree():
		return
	facing_right = is_right
	update_sprite_direction()

func can_attack() -> bool:
	return is_on_floor() and not is_attacking

func attack():
	is_attacking = true
	velocity.x = 0
	if sprite:
		sprite.play("attack")
	safe_rpc("remote_attack")
	
	if is_inside_tree():
		get_tree().create_timer(ATTACK_DURATION + 0.1).timeout.connect(force_end_attack)

@rpc("any_peer", "reliable")
func remote_attack():
	if not is_inside_tree():
		return
	
	is_attacking = true
	if sprite:
		sprite.play("attack")
	if is_inside_tree():
		get_tree().create_timer(ATTACK_DURATION + 0.1).timeout.connect(force_end_attack)

func _on_animation_finished():
	if sprite and sprite.animation == "attack" and is_attacking:
		is_attacking = false

func force_end_attack():
	if is_inside_tree():
		is_attacking = false

func update_animations():
	if not sprite or not is_inside_tree():
		return
	if is_attacking and sprite.animation == "attack":
		return
	
	if is_on_floor():
		if abs(velocity.x) < 10:
			play_anim("idle")
		else:
			play_anim("walk")
	else:
		#if velocity.y < 0:
			#play_anim("jump")
		#else:
			play_anim("jump")

func play_anim(anim_name: String):
	if sprite and sprite.animation != anim_name:
		sprite.play(anim_name)

#para cuando la bala impacte
func take_damage():
	print("El jugador %s recibió daño" % name)
	die()

func die():
	var game = get_tree().root.get_node_or_null("game")
	if game:
		game._respawn_player(self)
	
#par que el jugador spawnee de nuevo:
func respawn(new_position: Vector2):
	position = new_position
	velocity = Vector2.ZERO
	is_attacking = false
	facing_right = true
	
	if sprite:
		sprite.flip_h = false
		sprite.play("idle")
	visible = true
	set_physics_process(true)
	
func _exit_tree():
	is_attacking = false

extends Area2D

const SPEED: float = 400
const LIFETIME: float = 5.0

@export var direction_vector: Vector2 = Vector2.RIGHT
@export var shooter_id: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Area2D

var velocity: Vector2 = Vector2.ZERO

func _ready():
	velocity = direction_vector.normalized() * SPEED
	
	if sprite:
		sprite.flip_h = (direction_vector.x < 0)
		sprite.play()
	body_entered.connect(_on_body_entered)
	#para autodestruir :D
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _physics_process(delta):
	global_position += velocity * delta

func _on_body_entered(body: Node2D):
	if body is StaticBody2D or body is TileMap:
		queue_free()
		return
	
	if body.is_in_group("player"):
		if body.name.to_int() != shooter_id:
			print("La bala impactó al jugador %s" % body.name)
			if body.has_method("take_damage"):
				body.take_damage()
			queue_free()

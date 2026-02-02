extends CharacterBody2D

var direction: float = 0.0
var vel: float = 1000

func _ready():
	rotation = direction
	
func _physics_process(delta):
	velocity  = Vector2(vel,0).rotated(direction)
	move_and_slide()

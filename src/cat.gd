extends CharacterBody2D

var astar_grid: AStarGrid2D

const SPEED = 150.0
const JUMP_VELOCITY = -280.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var input_handler := $PlayerInputHandler

func _ready():
	astar_grid = AStarGrid2D.new()
	input_handler.direction_changed.connect(_on_direction_changed)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	
	# if is_on_floor()
	if direction < 0:
		animated_sprite.flip_h = true
	elif direction > 0:
		animated_sprite.flip_h = false
	
	if direction == 0:
		animated_sprite.play("idle")
	else:
		animated_sprite.play("walk")
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _on_direction_changed(facing_right: bool):
	animated_sprite.flip_h = not facing_right

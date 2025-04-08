extends CharacterBody2D

@export var max_speed := 100.0
@export var friction := 0.9
@export var push_force := 400.0

var being_pushed := false
var push_direction := Vector2.ZERO

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += 800 * delta  # Adjust gravity strength as needed
	
	# Handle being pushed
	if being_pushed:
		velocity.x = push_direction.x * push_force * delta
		being_pushed = false
	else:
		# Apply friction when not being pushed
		velocity.x *= friction
	
	move_and_slide()
	
func _on_push_area_body_entered(body):
	if body.name == "Cat":  # TODO: Replace with group check
		# Determine push direction based on player position
		var player = body
		push_direction = Vector2(
			sign(global_position.x - player.global_position.x),
			0
		)
		being_pushed = true

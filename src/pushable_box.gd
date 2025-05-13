extends CharacterBody2D

signal ground_impact(impact_velocity)

@export var max_speed := 100.0
@export var friction := 0.9
@export var push_force := 800.0
@export var min_impact_velocity := 200.0

var being_pushed := false
var push_direction := Vector2.ZERO
var was_in_air := false

func _physics_process(delta):
	var previously_in_air = not is_on_floor()
	
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
	
	# Detect landing impact
	if previously_in_air and is_on_floor():
		# Check if we fell fast enough to trigger impact
		if velocity.y >= min_impact_velocity:
			ground_impact.emit(velocity.y)
		
		# Reset vertical velocity after landing
		velocity.y = 0
	
func _on_push_area_body_entered(body):
	if body.name == "Cat":  # TODO: Replace with group check
		# Determine push direction based on player position
		var player = body
		push_direction = Vector2(
			sign(global_position.x - player.global_position.x),
			0
		)
		being_pushed = true

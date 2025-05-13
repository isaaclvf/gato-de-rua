extends CharacterBody2D

# Constants
const WALK_SPEED = 150.0
const SPRINT_SPEED = 260.0
const JUMP_VELOCITY = -280.0
@export var SPRINT_DISTANCE_THRESHOLD: float = 100.0 # Min distance to target to trigger sprint
@export var NAVIGATION_TIMEOUT: float = 3.0 # Seconds before navigation target expires
@export var normal_collision_mask: int
@export var hidden_collision_mask: int = 0b0000
@export var normal_collision_layer: int
@export var hidden_collision_layer: int = 0b0000


# Node References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var input_handler: Node = $PlayerInputHandler
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var thinking_timer: Timer = $ThinkingTimer
@onready var navigation_timeout_timer: Timer = $NavigationTimeoutTimer # New Timer



# State Variables
enum ControlMode { KEYBOARD, MOUSE_FOLLOW }
var current_control_mode = ControlMode.KEYBOARD

var laser_target_position: Vector2 = Vector2.ZERO
var is_following_path: bool = false
var is_thinking: bool = false
var current_navigation_speed: float = WALK_SPEED # Speed used for navigation

# Hiding Variables
var can_hide := false
var is_hidden := false
var current_bush = null
var normal_modulate_alpha: float = 1.0

# Pushing Variables
var pushing_box_collider = null

# --- Core Functions ---

func get_project_gravity_vector() -> Vector2:
	return Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))

func _ready():
	# PlayerInputHandler connections
	input_handler.direction_changed.connect(_on_input_handler_direction_changed)
	input_handler.navigation_target_set.connect(_on_input_handler_navigation_target_set)
	# The 'laser_activated' signal from input handler isn't used directly here currently,
	# but could trigger visual effects if needed.

	# Timer connections
	thinking_timer.timeout.connect(_on_thinking_timer_timeout)
	navigation_timeout_timer.timeout.connect(_on_navigation_timeout_timer_timeout) # Connect new timer
	navigation_agent.target_reached.connect(_on_navigation_target_reached)

	# Initialize timer settings
	navigation_timeout_timer.wait_time = NAVIGATION_TIMEOUT
	normal_modulate_alpha = animated_sprite.modulate.a

	# Set agent settings (optional but good practice)
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 12.0


func _process(delta: float): # Standard Godot callback for non-physics updates
	if Input.is_action_just_pressed("hide"):
		if can_hide and not is_hidden:
			hide_in_bush()
		elif is_hidden:
			unhide_from_bush()

func _physics_process(delta: float) -> void:
	pushing_box_collider = null # Reset pushing state each frame

	if is_hidden:
		handle_hidden_state(delta)
	elif is_thinking:
		handle_thinking_state(delta)
	else:
		handle_normal_state(delta)

	update_animations() # Update animations based on current state/velocity
	move_and_slide() # Apply physics movement

	# Check for pushing only if not hidden/thinking and potentially moving
	if not is_hidden and not is_thinking:
		check_for_pushing_box()

# --- State Handling Functions ---

func handle_hidden_state(delta: float):
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Stop slowly
	velocity.y = 0 # Prevent falling if hidden slightly above ground

func handle_thinking_state(delta: float):
	# Apply gravity while thinking
	if not is_on_floor():
		velocity.y += get_project_gravity_vector().y * delta
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Slow down

func handle_normal_state(delta: float):
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y += get_project_gravity_vector().y * delta

	match current_control_mode:
		ControlMode.KEYBOARD:
			handle_keyboard_movement(delta)
		ControlMode.MOUSE_FOLLOW:
			if is_following_path:
				handle_navigation_movement(delta)
			else:
				# Idle while in mouse follow mode (target reached, invalid, or timed out)
				velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

# --- Movement Logic Functions ---

func handle_keyboard_movement(delta: float):
	var direction := Input.get_axis("move_left", "move_right")
	var is_sprinting := Input.is_action_pressed("sprint")

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if direction:
		var current_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

func handle_navigation_movement(delta: float):
	# Double check if we should still be following (e.g., timeout might have occurred between frames)
	if not is_following_path:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Stop if path was cancelled
		return

	# Agent handles path updates internally after target is set
	if navigation_agent.is_navigation_finished():
		print("NavigationAgent reports finished in handle_nav_movement.")
		_stop_navigation("Navigation finished (path end or invalid)")
		return

	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction_to_next_point: Vector2 = global_position.direction_to(next_path_position)

	# Apply movement using the calculated speed (walk or sprint)
	velocity.x = direction_to_next_point.x * current_navigation_speed # Use current_navigation_speed

	# --- Basic Jump Detection ---
	# Note: NavigationLink2D nodes in the level are more robust for defined jumps.
	# This heuristic attempts jumps based on path geometry.
	var y_diff = global_position.y - next_path_position.y
	var x_dist = abs(global_position.x - next_path_position.x)
	# Adjust thresholds based on your game's scale and jump physics
	if is_on_floor() and y_diff > 20 and y_diff < 150 and x_dist < 64:
		# Check if there's ground at the approximate landing spot
		var landing_check_start = Vector2(next_path_position.x, next_path_position.y - 16)
		var landing_check_end = Vector2(next_path_position.x, next_path_position.y + 32)
		var space_state = get_world_2d().direct_space_state
		var query_params = PhysicsRayQueryParameters2D.create(landing_check_start, landing_check_end)
		query_params.collide_with_bodies = true
		query_params.collision_mask = self.collision_mask # Check against what the cat collides with
		var result = space_state.intersect_ray(query_params)
		if result: # Found potential ground to land on
			velocity.y = JUMP_VELOCITY
		# else: Consider what happens if the jump seems unsafe. For now, it just won't jump.
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("pushable"):
			var player_velocity = get_velocity()
			var push_force = Vector2(player_velocity.x * 0.075,0)
			push_force.normalized()
			# Apply force to the RigidBody2D
			collision.get_collider().apply_central_impulse(push_force)
# --- Animation & Interaction ---

func update_animations():
	var current_animation_name = animated_sprite.animation

	if is_hidden:
		# Play specific hiding animation or just idle
		if current_animation_name != "idle": animated_sprite.play("idle") # Assume "idle" or make a "hide_idle"
		return

	if is_thinking:
		# Play thinking animation or idle
		if current_animation_name != "idle": animated_sprite.play("idle") # Assume "idle" or make a "thinking"
		return

	# Flip sprite based on horizontal velocity or input handler direction if idle
	if abs(velocity.x) > 1.0:
		animated_sprite.flip_h = velocity.x < 0
	# else: Retain last facing direction when idle (handled by input handler potentially)

	# Animation State Machine
	if not is_on_floor():
		if velocity.y < 0:
			if current_animation_name != "jump": animated_sprite.play("jump")
		else:
			if current_animation_name != "fall": animated_sprite.play("fall")
	elif pushing_box_collider:
		if current_animation_name != "walk": animated_sprite.play("walk") # Or a dedicated "push" animation
	elif abs(velocity.x) > 5.0:
		# Determine if sprinting based on mode and speed
		var is_sprinting_now = false
		if current_control_mode == ControlMode.KEYBOARD:
			is_sprinting_now = Input.is_action_pressed("sprint")
		elif current_control_mode == ControlMode.MOUSE_FOLLOW and is_following_path:
			is_sprinting_now = (current_navigation_speed == SPRINT_SPEED) # Check navigation speed

		if is_sprinting_now and animated_sprite.sprite_frames.has_animation("sprint"):
			if current_animation_name != "sprint": animated_sprite.play("sprint")
		else: # Walking
			if current_animation_name != "walk": animated_sprite.play("walk")
	else: # Idle
		if current_animation_name != "idle": animated_sprite.play("idle")


func check_for_pushing_box():
	if abs(velocity.x) > 1.0 and is_on_floor(): # Check only if moving horizontally on floor
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision:
				var collider = collision.get_collider()
				# Check if collider is pushable and if we are pushing against its side
				if collider and collider.is_in_group("pushable"): # Assuming boxes are in "pushable" group
					var normal = collision.get_normal()
					# Check if collision normal is opposing movement direction significantly
					if (velocity.x > 0 and normal.x < -0.5) or \
					   (velocity.x < 0 and normal.x > 0.5):
						pushing_box_collider = collider
						print("Pushing box:", collider.name) # Debug
						break # Found a box being pushed


func hide_in_bush():
	if current_bush and not is_hidden:
		if current_bush.has_method("hide_player"): 
			current_bush.hide_player(self)
	is_hidden = true
	animated_sprite.modulate.a = 0.5
	_stop_navigation("Hidden")
	#set_collision_mask_value(1, false)  
	#set_collision_mask_value(2, false) 
	#set_collision_mask_value(3, false)
	normal_collision_mask = collision_mask
	normal_collision_layer = collision_layer
	collision_mask = 0b0000
	collision_layer = 0b0000
		
func unhide_from_bush():
	if is_hidden:
		if current_bush and current_bush.has_method("unhide_player"):
			current_bush.unhide_player(self)
		is_hidden = false
		animated_sprite.modulate.a = 1.0
		
		# Reativa todas as colisões
		collision_mask = normal_collision_mask
		collision_layer = normal_collision_layer
		
# --- Signal Handlers ---

func _on_input_handler_direction_changed(facing_right: bool):
	# Face the mouse click direction if idle or just starting navigation
	if not is_following_path and not (current_control_mode == ControlMode.KEYBOARD and abs(velocity.x) > 1.0):
		animated_sprite.flip_h = not facing_right

func _on_input_handler_navigation_target_set(world_pos: Vector2):
	print("Cat received navigation target: ", world_pos)

	# Stop any previous navigation immediately
	_stop_navigation("New target set")

	# Switch state
	current_control_mode = ControlMode.MOUSE_FOLLOW
	laser_target_position = world_pos
	velocity = Vector2.ZERO # Stop current keyboard movement

	# Start thinking
	is_thinking = true
	thinking_timer.start() # Use default wait time set in editor or _ready
	# Play "thinking" animation if available
	# if animated_sprite.sprite_frames.has_animation("thinking"): animated_sprite.play("thinking")


func _on_thinking_timer_timeout():
	is_thinking = false
	# if animated_sprite.sprite_frames.has_animation("idle"): animated_sprite.play("idle") # Back to idle/default

	navigation_agent.target_position = laser_target_position # Set the agent's target

	# Need a short delay for the agent to compute the path status
	await get_tree().physics_frame

	if navigation_agent.is_target_reachable():
		print("Path to target is reachable.")
		is_following_path = true

		# Determine speed based on distance
		var dist_to_target = global_position.distance_to(laser_target_position)
		current_navigation_speed = SPRINT_SPEED if dist_to_target > SPRINT_DISTANCE_THRESHOLD else WALK_SPEED
		print("Navigation starting. Speed: ", current_navigation_speed)

		# Start the timeout timer now that we are actively following
		navigation_timeout_timer.start()

	else:
		print("Cannot reach target. Path is invalid or blocked.")
		is_following_path = false
		current_navigation_speed = WALK_SPEED # Reset speed
		# Optional: Play a "confused" animation or sound effect
		# Optional: Revert to keyboard control automatically
		# current_control_mode = ControlMode.KEYBOARD


func _on_navigation_target_reached():
	# This signal means the agent is *close* to the final target_position
	print("NavigationAgent reports target reached.")
	_stop_navigation("Target reached")


func _on_navigation_timeout_timer_timeout():
	# This function is called ONLY if the timer finishes *before* the target was reached.
	if not is_following_path:
		return # Ignore timeout if we already stopped following for another reason

	print("Navigation timed out!")
	_stop_navigation("Timeout")
	# Optional: Play a sound or animation indicating failure/giving up


func _stop_navigation(reason: String):
	"""Helper function to stop current navigation cleanly."""
	if is_following_path or navigation_timeout_timer.time_left > 0:
		# print("Stopping navigation. Reason: ", reason) # Debug
		is_following_path = false
		navigation_timeout_timer.stop() # Stop the timeout timer
		current_navigation_speed = WALK_SPEED # Reset speed
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Start stopping

		# Crucial: Tell the agent to stop trying to reach the previous target.
		# Setting target to current position effectively cancels the pathfinding goal.
		if is_instance_valid(navigation_agent) and navigation_agent.is_inside_tree():
			navigation_agent.target_position = global_position
			# Force agent update by waiting a physics frame is sometimes needed if issues persist
			# await get_tree().physics_frame 


# --- Area Detection for Hiding ---

func _on_hide_zone_detector_area_entered(area: Area2D) -> void:
	# Assuming the Area2D node on the bush is in the "hide" group
	if area.is_in_group("hide"):
		can_hide = true
		current_bush = area.get_parent() # Assuming Area2D is direct child of the Bush scene root

func _on_hide_zone_detector_area_exited(area: Area2D) -> void:
	if area.is_in_group("hide") and area.get_parent() == current_bush:
		can_hide = false
		if is_hidden: # If cat leaves the zone while hidden, unhide
			unhide_from_bush()
		current_bush = null

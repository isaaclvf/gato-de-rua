extends CharacterBody2D

const WALK_SPEED = 150.0
const SPRINT_SPEED = 260.0
const JUMP_VELOCITY = -280.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var input_handler: Node = $PlayerInputHandler # Keep type as Node if PlayerInputHandler script is on a Node2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var thinking_timer: Timer = $ThinkingTimer

enum ControlMode { KEYBOARD, MOUSE_FOLLOW } # Updated control modes
var current_control_mode = ControlMode.KEYBOARD # Start with keyboard control

var laser_target_position: Vector2 = Vector2.ZERO # Store the mouse click target
var is_following_path: bool = false
var is_thinking: bool = false # To show "thinking" state/animation

var can_hide := false
var is_hidden := false
var current_bush = null
var normal_modulate_alpha: float = 1.0

var pushing_box_collider = null

func get_project_gravity_vector() -> Vector2:
	return Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))

func _ready():
	# PlayerInputHandler connections
	input_handler.direction_changed.connect(_on_input_handler_direction_changed)
	input_handler.navigation_target_set.connect(_on_input_handler_navigation_target_set)

	# Navigation and Thinking Timer connections
	thinking_timer.timeout.connect(_on_thinking_timer_timeout)
	navigation_agent.target_reached.connect(_on_navigation_target_reached)
	# navigation_agent.navigation_finished.connect(_on_navigation_finished) # Optional

	normal_modulate_alpha = animated_sprite.modulate.a

func _process(delta: float): # Renamed from _process to Godot's standard
	if Input.is_action_just_pressed("hide"):
		if can_hide and not is_hidden:
			hide_in_bush()
		elif is_hidden:
			unhide_from_bush()

func _physics_process(delta: float) -> void:
	pushing_box_collider = null

	if is_hidden:
		handle_hidden_state(delta)
	elif is_thinking:
		handle_thinking_state(delta) # Cat might still be affected by gravity
	else:
		handle_normal_state(delta)

	update_animations()
	move_and_slide()

	if not is_hidden and not is_thinking: # Don't check for pushing if hidden or thinking
		check_for_pushing_box()


func handle_hidden_state(delta: float):
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	velocity.y = 0

func handle_thinking_state(delta: float):
	# Allow gravity while thinking
	if not is_on_floor():
		velocity.y += get_project_gravity_vector().y * delta
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Slow down horizontal movement

func handle_normal_state(delta: float):
	if not is_on_floor():
		velocity.y += get_project_gravity_vector().y * delta

	match current_control_mode:
		ControlMode.KEYBOARD:
			handle_keyboard_movement(delta)
		ControlMode.MOUSE_FOLLOW:
			if is_following_path:
				handle_navigation_movement(delta)
			else:
				# Idle in mouse_follow mode (e.g., target reached or path invalid)
				velocity.x = move_toward(velocity.x, 0, WALK_SPEED)


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
	if navigation_agent.is_target_reached() or navigation_agent.is_navigation_finished():
		# This should ideally be caught by the _on_navigation_target_reached signal
		print("Navigation agent reports target reached or finished in _physics_process (during follow).")
		_on_navigation_target_reached() # Call it directly to ensure state is cleaned up
		return

	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction_to_next_point: Vector2 = global_position.direction_to(next_path_position)

	velocity.x = direction_to_next_point.x * WALK_SPEED # Use WALK_SPEED for navigation
	
	# Basic jump detection (same as before, consider NavigationLink2D for robust jumps)
	var y_diff = global_position.y - next_path_position.y
	var x_dist = abs(global_position.x - next_path_position.x)
	if is_on_floor() and y_diff > 20 and y_diff < 150 and x_dist < 64:
		var landing_check_start = Vector2(next_path_position.x, next_path_position.y - 16)
		var landing_check_end = Vector2(next_path_position.x, next_path_position.y + 32)
		var space_state = get_world_2d().direct_space_state
		var query_params = PhysicsRayQueryParameters2D.create(landing_check_start, landing_check_end)
		query_params.collide_with_bodies = true
		query_params.collision_mask = self.collision_mask
		var result = space_state.intersect_ray(query_params)
		if result:
			velocity.y = JUMP_VELOCITY

func update_animations():
	var current_animation_name = animated_sprite.animation

	if is_hidden:
		if current_animation_name != "idle": animated_sprite.play("idle") # Or "hide_idle"
		return
	
	if is_thinking:
		if current_animation_name != "idle": animated_sprite.play("idle") # Or a "thinking" animation
		return

	# Sprite flipping:
	# If moving via keyboard or navigation, flip based on velocity.
	# If idle, PlayerInputHandler's direction_changed might dictate flip (cat faces mouse).
	if abs(velocity.x) > 1.0: # Moving
		animated_sprite.flip_h = velocity.x < 0
	# else: // If idle, rely on _on_input_handler_direction_changed for facing, or keep last flip

	if not is_on_floor():
		if velocity.y < 0:
			if current_animation_name != "jump": animated_sprite.play("jump")
		else:
			if current_animation_name != "fall": animated_sprite.play("fall")
	elif pushing_box_collider:
		if current_animation_name != "walk": animated_sprite.play("walk") # Or "push"
	elif abs(velocity.x) > 5.0:
		# Note: sprint animation only for keyboard mode here. Nav uses WALK_SPEED.
		var is_sprinting_keyboard = Input.is_action_pressed("sprint") and current_control_mode == ControlMode.KEYBOARD
		if is_sprinting_keyboard:
			if current_animation_name != "sprint": animated_sprite.play("sprint")
		else:
			if current_animation_name != "walk": animated_sprite.play("walk")
	else: # Idle
		if current_animation_name != "idle": animated_sprite.play("idle")


func check_for_pushing_box():
	if abs(velocity.x) > 1.0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision:
				var collider = collision.get_collider()
				if collider and collider.is_in_group("pushable"):
					var normal = collision.get_normal()
					if (velocity.x > 0 and normal.x < -0.5) or \
					   (velocity.x < 0 and normal.x > 0.5):
						pushing_box_collider = collider
						break

func hide_in_bush():
	if current_bush and not is_hidden:
		if current_bush.has_method("hide_player"): current_bush.hide_player(self)
		is_hidden = true
		animated_sprite.modulate.a = 0.5
		is_following_path = false # Stop navigation if hiding

func unhide_from_bush():
	if is_hidden: # Check is_hidden first
		if current_bush and current_bush.has_method("unhide_player"):
			current_bush.unhide_player(self)
		is_hidden = false
		animated_sprite.modulate.a = normal_modulate_alpha
		animated_sprite.show()


# --- Signal Handlers ---

func _on_input_handler_direction_changed(facing_right: bool):
	# This signal comes from PlayerInputHandler on mouse click.
	# Cat can use this to face the mouse, especially when idle or target is set.
	if not is_following_path and not (current_control_mode == ControlMode.KEYBOARD and abs(velocity.x) > 1.0):
		# If not actively moving via path or keyboard, face the mouse click direction
		animated_sprite.flip_h = not facing_right

func _on_input_handler_navigation_target_set(world_pos: Vector2):
	print("Cat received navigation target: ", world_pos)
	current_control_mode = ControlMode.MOUSE_FOLLOW
	laser_target_position = world_pos
	is_following_path = false # Will be true after thinking and path is confirmed
	velocity = Vector2.ZERO # Stop current keyboard movement immediately
	
	is_thinking = true
	thinking_timer.wait_time = 0.5 # Adjust "thinking" duration as needed
	thinking_timer.start()
	# Could play a "thinking" animation here if you have one
	# animated_sprite.play("thinking_start")


func _on_thinking_timer_timeout():
	is_thinking = false
	# animated_sprite.play("thinking_end_or_idle") # Transition animation

	navigation_agent.set_target_position(laser_target_position)
	
	# Wait a physics frame for the agent to update its path information
	await get_tree().physics_frame 
	
	if navigation_agent.is_target_reachable():
		print("Path to laser target is reachable. Following.")
		is_following_path = true
	else:
		print("Cannot reach laser target. Path is invalid or blocked.")
		is_following_path = false
		# Optional: Revert to keyboard mode or play a "confused" animation
		# current_control_mode = ControlMode.KEYBOARD


func _on_navigation_target_reached():
	print("Cat reached laser target.")
	is_following_path = false
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Come to a stop

	# Cat remains in MOUSE_FOLLOW mode, waiting for the next click.
	# To switch back to keyboard automatically:
	# current_control_mode = ControlMode.KEYBOARD

# func _on_navigation_finished(): # Use if you need to distinguish from target_reached
#    print("NavigationAgent2D: Navigation Finished (path exhausted or invalid).")
#    is_following_path = false
#    velocity.x = move_toward(velocity.x, 0, WALK_SPEED)


func _on_hide_zone_detector_area_entered(area: Area2D) -> void:
	if area.is_in_group("hide"):
		can_hide = true
		current_bush = area.get_parent()

func _on_hide_zone_detector_area_exited(area: Area2D) -> void:
	if area.is_in_group("hide") and area.get_parent() == current_bush:
		can_hide = false
		if is_hidden:
			unhide_from_bush()
		current_bush = null

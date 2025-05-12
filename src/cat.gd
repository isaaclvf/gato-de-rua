extends CharacterBody2D

const WALK_SPEED = 150.0
const SPRINT_SPEED = 260.0 # Used for keyboard sprint
const JUMP_VELOCITY = -280.0

@export var target: Node2D # The target Node2D the cat will follow

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var input_handler := $PlayerInputHandler # Assuming this is for keyboard/gamepad
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var thinking_timer: Timer = $ThinkingTimer

enum ControlMode { KEYBOARD, AUTO_FOLLOW } # Changed LASER_POINTER to AUTO_FOLLOW for this task
var current_control_mode = ControlMode.AUTO_FOLLOW # Start in auto-follow mode

var is_following_path: bool = false # True when actively moving along a nav path

var can_hide := false
var is_hidden := false
var current_bush = null
var normal_modulate_alpha: float = 1.0

var pushing_box_collider = null # Stores the collider of the box being pushed, for animation

# Helper to get gravity vector from project settings
func get_project_gravity_vector() -> Vector2:
	return Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))

func _ready():
	input_handler.direction_changed.connect(_on_direction_changed) # For keyboard sprite flipping
	normal_modulate_alpha = animated_sprite.modulate.a

	# --- Navigation Setup ---
	thinking_timer.timeout.connect(_on_thinking_timer_timeout)
	navigation_agent.target_reached.connect(_on_navigation_target_reached)
	# Optional: For debugging path changes or more complex logic
	# navigation_agent.path_changed.connect(_on_path_changed)
	# navigation_agent.navigation_finished.connect(_on_navigation_finished)

	if current_control_mode == ControlMode.AUTO_FOLLOW:
		if target:
			print("Cat is in AUTO_FOLLOW mode. Target: ", target.name)
			# Start the "thinking" process before moving to the target
			# For this test, let's make thinking time very short or immediate
			thinking_timer.wait_time = 0.1 # Short "thinking" delay for test
			thinking_timer.start()
		else:
			printerr("Cat in AUTO_FOLLOW mode, but no target Node2D is assigned!")
			current_control_mode = ControlMode.KEYBOARD # Fallback to keyboard if no target

func _process(delta: float) -> void: # Renamed from _process to Godot's standard
	# Handle hide/unhide input (works in any mode unless overridden)
	if Input.is_action_just_pressed("hide"):
		if can_hide and not is_hidden:
			hide_in_bush()
		elif is_hidden:
			unhide_from_bush()

func _physics_process(delta: float) -> void:
	pushing_box_collider = null # Reset each physics frame

	if is_hidden:
		handle_hidden_state(delta)
		update_animations() # Ensure hidden animation plays
		move_and_slide()
		return # No other movement or logic if hidden

	# Apply gravity if not on floor (common to all active modes)
	if not is_on_floor():
		velocity += get_project_gravity_vector() * delta

	match current_control_mode:
		ControlMode.KEYBOARD:
			handle_keyboard_movement(delta)
		ControlMode.AUTO_FOLLOW:
			if is_following_path:
				handle_navigation_movement(delta)
			else:
				# Cat is idle in auto-follow mode (e.g., finished thinking but not moving, or reached target)
				velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Slow down

	update_animations() # Update animations based on current state and velocity
	move_and_slide()
	
	# Check for pushing after move_and_slide to get collision info
	if not is_hidden: # Don't check for pushing if hidden
		check_for_pushing_box()


func handle_hidden_state(delta):
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	velocity.y = 0 # Stop vertical movement if any (e.g. was falling into hide spot)
	# animation handled in update_animations

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
		# but good to have a fallback.
		print("Navigation agent reports target reached or navigation finished in _physics_process.")
		is_following_path = false
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED) # Come to a stop
		return

	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction_to_next_point: Vector2 = global_position.direction_to(next_path_position)

	velocity.x = direction_to_next_point.x * WALK_SPEED
	
	# Basic jump detection (very simplified - NavigationLink2D is preferred for robust jumps)
	# This attempts a jump if the next point is significantly higher and close horizontally.
	var y_diff = global_position.y - next_path_position.y # Positive if next point is higher
	var x_dist = abs(global_position.x - next_path_position.x)

	if is_on_floor() and y_diff > 20 and y_diff < 150 and x_dist < 64: # Heuristic values
		# Simple check if there's something to land on near the target's X,Y
		var landing_check_start = Vector2(next_path_position.x, next_path_position.y - 16)
		var landing_check_end = Vector2(next_path_position.x, next_path_position.y + 32)
		var space_state = get_world_2d().direct_space_state
		var query_params = PhysicsRayQueryParameters2D.create(landing_check_start, landing_check_end)
		query_params.collide_with_bodies = true
		query_params.collision_mask = self.collision_mask # Check against what cat collides with
		var result = space_state.intersect_ray(query_params)
		
		if result:
			velocity.y = JUMP_VELOCITY
			print("Auto-jump initiated by navigation.")
		# else: Path might require a jump cat can't make, or NavLink is missing.

func update_animations():
	var current_animation = animated_sprite.animation

	if is_hidden:
		if current_animation != "idle": # Or a specific "hide_idle" if you have one
			animated_sprite.play("idle") 
		return

	# Sprite flipping based on horizontal velocity
	if velocity.x < -1.0:
		animated_sprite.flip_h = true
	elif velocity.x > 1.0:
		animated_sprite.flip_h = false
	# Else, keep current flip if velocity.x is near zero (prevents flipping while standing still)

	if not is_on_floor():
		if velocity.y < 0:
			if current_animation != "jump": animated_sprite.play("jump")
		else:
			if current_animation != "fall": animated_sprite.play("fall")
	elif pushing_box_collider:
		if current_animation != "walk": animated_sprite.play("walk") # Or a specific "push" animation
	elif abs(velocity.x) > 5.0: # Moving threshold
		var is_sprinting_keyboard = Input.is_action_pressed("sprint") and current_control_mode == ControlMode.KEYBOARD
		if is_sprinting_keyboard:
			if current_animation != "sprint": animated_sprite.play("sprint")
		else:
			if current_animation != "walk": animated_sprite.play("walk")
	else: # Idle
		if current_animation != "idle": animated_sprite.play("idle")


func check_for_pushing_box():
	# Detects if colliding with a pushable box while moving into it.
	# This is for animation and potentially custom push logic if boxes aren't RigidBody2D.
	if abs(velocity.x) > 1.0: # Only consider pushing if actively moving
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision: # Ensure collision is not null
				var collider = collision.get_collider()
				if collider and collider.is_in_group("pushable"):
					# Check if the cat is moving towards the box
					var normal = collision.get_normal() # Normal points away from the surface hit
					if (velocity.x > 0 and normal.x < -0.5) or \
					   (velocity.x < 0 and normal.x > 0.5):
						pushing_box_collider = collider
						# If boxes are RigidBody2D, move_and_slide will handle the push.
						# If they are CharacterBody2D or StaticBody2D with custom scripts:
						# if collider.has_method("being_pushed_by"):
						#    collider.being_pushed_by(self, velocity * delta)
						break # Assume pushing one box at a time

# --- Hide/Unhide Logic ---
func hide_in_bush():
	if current_bush and not is_hidden:
		current_bush.hide_player(self) # Assuming bush has this method
		is_hidden = true
		animated_sprite.modulate.a = 0.5
		print("Cat hidden.")

func unhide_from_bush():
	if current_bush and is_hidden: # Ensure current_bush is still valid
		current_bush.unhide_player(self) # Assuming bush has this method
	is_hidden = false # Always unhide logically
	animated_sprite.modulate.a = normal_modulate_alpha
	animated_sprite.show() # Just in case it was hidden by other means
	print("Cat unhidden.")


# --- Signal Handlers ---
func _on_thinking_timer_timeout():
	print("Cat finished 'thinking'. Attempting to find path.")
	if not target:
		printerr("Target became null before navigation could start.")
		current_control_mode = ControlMode.KEYBOARD # Revert if issue
		is_following_path = false
		return

	navigation_agent.set_target_position(target.global_position)
	
	# It's good practice to wait a frame or check is_target_reachable before setting is_following_path
	# For simplicity in this initial test, we'll try to follow immediately.
	# A more robust way:
	# await get_tree().physics_frame 
	# if navigation_agent.is_target_reachable():
	#    is_following_path = true
	# else:
	#    print("Path to target is not reachable.")
	#    is_following_path = false
	#    current_control_mode = ControlMode.KEYBOARD # Revert if path not found
	
	# For this test:
	is_following_path = true 
	print("Pathfinding initiated to target: ", target.name)

func _on_navigation_target_reached():
	print("NavigationAgent2D: Target Reached - ", target.name if target else "Unknown Target")
	is_following_path = false
	velocity = Vector2.ZERO # Stop the cat smoothly
	# current_control_mode = ControlMode.KEYBOARD # Optional: Switch back after reaching

# func _on_path_changed():
#    print("NavigationAgent2D: Path Changed. New path length: ", navigation_agent.get_current_navigation_path().size())
#    current_path = navigation_agent.get_current_navigation_path() # For debugging

# func _on_navigation_finished():
#    print("NavigationAgent2D: Navigation Finished (path exhausted or invalid).")
#    is_following_path = false
#    velocity.x = move_toward(velocity.x, 0, WALK_SPEED)


func _on_hide_zone_detector_area_entered(area: Area2D) -> void:
	if area.is_in_group("hide"): # Assuming your bush's Area2D is in group "hide"
		can_hide = true
		current_bush = area.get_parent() # Assuming Area2D is child of the main bush node
		print("Entered hide zone for: ", current_bush.name)

func _on_hide_zone_detector_area_exited(area: Area2D) -> void:
	if area.is_in_group("hide") and area.get_parent() == current_bush:
		can_hide = false
		print("Exited hide zone for: ", current_bush.name)
		if is_hidden:
			# Force unhide if leaving bush area while hidden
			unhide_from_bush() # This will also clear current_bush logically if needed
		current_bush = null


func _on_direction_changed(facing_right: bool):
	# This is connected to PlayerInputHandler, primarily for keyboard.
	# For navigation, flip_h is handled by update_animations based on velocity.
	if current_control_mode == ControlMode.KEYBOARD:
		animated_sprite.flip_h = not facing_right

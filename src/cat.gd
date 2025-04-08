extends CharacterBody2D

const WALK_SPEED = 150.0
const SPRINT_SPEED = 260.0
const JUMP_VELOCITY = -280.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var input_handler := $PlayerInputHandler

var can_hide := false
var is_hidden := false
var current_bush = null
var normal_modulate: float = 1.0  # Store normal opacity

var pushing_box = null

func _ready():
	input_handler.direction_changed.connect(_on_direction_changed)
	normal_modulate = animated_sprite.modulate.a  # Store initial opacity

func _process(delta):
	if Input.is_action_just_pressed("hide"):
		if can_hide and not is_hidden:
			# Hide the player
			current_bush.hide_player(self)
			is_hidden = true
			animated_sprite.modulate.a = 0.5
		elif is_hidden:
			# Unhide the player
			current_bush.unhide_player(self)
			is_hidden = false
			animated_sprite.modulate.a = normal_modulate
			animated_sprite.show()

func _physics_process(delta: float) -> void:
	if is_hidden:
		handle_hidden_state(delta)
	else:
		handle_normal_state(delta)

func handle_hidden_state(delta):
	# Player is hidden - only respond to unhide input (handled in _process)
	# Stop all movement
	velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	velocity.y = 0
	move_and_slide()
	
	# Ensure sprite stays still
	animated_sprite.play("idle")

func handle_normal_state(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animated_sprite.play("jump")

	var direction := Input.get_axis("move_left", "move_right")
	var is_sprinting := Input.is_action_pressed("sprint")
	
	# Flip sprite based on direction
	if direction < 0:
		animated_sprite.flip_h = true
	elif direction > 0:
		animated_sprite.flip_h = false
	
	# Handle animations - prioritize jump/fall animations first
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")  # Rising part of jump
		else:
			animated_sprite.play("fall")  # Falling part of jump
	elif direction == 0:
		animated_sprite.play("idle")
	else:
		if is_sprinting:
			animated_sprite.play("sprint")
		else:
			animated_sprite.play("walk")
	
	# Apply movement
	if direction:
		var current_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("pushable"):
			# Apply push force based on player movement
			if Input.is_action_pressed("move_right"):
				collision.get_collider().push_direction = Vector2.RIGHT
				collision.get_collider().being_pushed = true
			elif Input.is_action_pressed("move_left"):
				collision.get_collider().push_direction = Vector2.LEFT
				collision.get_collider().being_pushed = true
	
func _on_hide_zone_detector_area_entered(area: Area2D) -> void:
	if area.is_in_group("hide"):
		can_hide = true
		current_bush = area.get_parent()

func _on_hide_zone_detector_area_exited(area: Area2D) -> void:
	if area.is_in_group("hide"):
		can_hide = false
		if is_hidden:
			# Force unhide if leaving bush while hidden
			current_bush.unhide_player(self)
			is_hidden = false
			animated_sprite.modulate.a = normal_modulate
			animated_sprite.show()
		current_bush = null

func _on_direction_changed(facing_right: bool):
	animated_sprite.flip_h = not facing_right

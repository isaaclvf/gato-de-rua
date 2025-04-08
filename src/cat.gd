extends CharacterBody2D

const WALK_SPEED = 150.0
const SPRINT_SPEED = 260.0
const JUMP_VELOCITY = -280.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var input_handler := $PlayerInputHandler

var can_hide := false
var is_hidden := false
var current_bush = null

func _ready():
	input_handler.direction_changed.connect(_on_direction_changed)
	
func _process(delta):
	if Input.is_action_just_pressed("hide") and can_hide:
		if is_hidden:
			current_bush.unhide_player(self)
			is_hidden = false
			# Restore player visibility/collision
			$AnimatedSprite2D.show()
		else:
			current_bush.hide_player(self)
			is_hidden = true
			$AnimatedSprite2D.modulate.a = 0.5


func _physics_process(delta: float) -> void:
	handle_normal_state(delta)

func _on_direction_changed(facing_right: bool):
	animated_sprite.flip_h = not facing_right

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
			$AnimatedSprite2D.show()
		current_bush = null

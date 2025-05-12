extends Node2D

signal direction_changed(facing_right: bool) # Existing signal
signal navigation_target_set(world_position: Vector2) # Signal for navigation
signal laser_activated(world_position: Vector2) # New signal for the "laser shake" activation

@onready var cat: CharacterBody2D = get_parent() # More robust way to get parent

# Tracking variables for mouse state
var mouse_held: bool = false
var hold_start_time: float = 0.0
var hold_duration_threshold: float = 0.1 # How long to hold before tracking shake
var last_mouse_positions: Array[Vector2] = []
var position_sample_rate: float = 0.05 # How often to sample mouse position (seconds)
var last_sample_time: float = 0.0
var shake_threshold: float = 25.0 # Total movement distance needed to trigger
var max_position_samples: int = 10 # Number of samples to keep
var is_shaking: bool = false
var current_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Start tracking when mouse is pressed
			mouse_held = true
			hold_start_time = Time.get_ticks_msec() / 1000.0
			last_mouse_positions.clear()
			current_mouse_pos = get_global_mouse_position()
			
			# Still update direction immediately (optional, can be removed)
			if cat:
				var facing_right: bool = current_mouse_pos.x > cat.global_position.x
				direction_changed.emit(facing_right)
		else:
			# Reset tracking when mouse is released
			mouse_held = false
			is_shaking = false

func _process(delta: float) -> void:
	if not mouse_held:
		return
		
	current_mouse_pos = get_global_mouse_position()
	var current_time = Time.get_ticks_msec() / 1000.0
	var hold_duration = current_time - hold_start_time
	
	# Start tracking shake after hold threshold is met
	if hold_duration >= hold_duration_threshold:
		# Sample mouse position at intervals
		if current_time - last_sample_time >= position_sample_rate:
			last_sample_time = current_time
			last_mouse_positions.append(current_mouse_pos)
			
			# Keep only the recent samples
			if last_mouse_positions.size() > max_position_samples:
				last_mouse_positions.remove_at(0)
			
			# Check for shake if we have enough samples
			if last_mouse_positions.size() >= 3:
				check_for_shake()

func check_for_shake() -> void:
	# Calculate total movement distance across samples
	var total_movement: float = 0.0
	for i in range(1, last_mouse_positions.size()):
		total_movement += last_mouse_positions[i].distance_to(last_mouse_positions[i-1])
	
	# Calculate average movement per sample
	var avg_movement = total_movement / (last_mouse_positions.size() - 1)
	
	# Detect shake based on movement threshold
	if avg_movement >= shake_threshold / max_position_samples:
		if not is_shaking:
			is_shaking = true
			trigger_laser_activation()

func trigger_laser_activation() -> void:
	if cat:
		# Emit both signals when shake is detected
		navigation_target_set.emit(current_mouse_pos)
		
		var facing_right: bool = current_mouse_pos.x > cat.global_position.x
		direction_changed.emit(facing_right)
		
		# Emit the new laser activation signal
		laser_activated.emit(current_mouse_pos)

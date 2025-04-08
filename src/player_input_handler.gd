extends Node2D

signal direction_changed(facing_right: bool)

@onready var cat: CharacterBody2D = $".."

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position()
		
		if cat:  # Safety check
			var facing_right = mouse_pos.x > cat.global_position.x
			print("Player at: ", cat.global_position.x, 
				  " | Click at: ", mouse_pos.x,
				  " | Facing right: ", facing_right)
			direction_changed.emit(facing_right)

extends Node2D

signal player_entered_box
signal player_exited_box

var player_in_box := false
var player_hidden := false

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_in_box = true
		player_entered_box.emit()

func _on_area_2d_bodybox_exited(body):
	if body.is_in_group("player"):
		player_in_box = false
		if player_hidden:
			unhide_player(body)
		player_exited_box.emit()

func hide_player(player):
	player_hidden = true
	# Optional: Play hide animation
	modulate.a = 0.7 
	
func unhide_player(player):
	player_hidden = false
	# Optional: Play unhide animation
	modulate.a = 1.0

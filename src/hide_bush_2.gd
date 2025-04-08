extends Node2D

signal player_entered_bush
signal player_exited_bush

var player_in_bush := false
var player_hidden := false

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		player_in_bush = true
		player_entered_bush.emit()

func _on_area_2d_body_exited(body):
	if body.is_in_group("player"):
		player_in_bush = false
		if player_hidden:
			unhide_player(body)
		player_exited_bush.emit()

func hide_player(player):
	player_hidden = true
	# Optional: Play hide animation
	modulate.a = 0.7 
	
func unhide_player(player):
	player_hidden = false
	# Optional: Play unhide animation
	modulate.a = 1.0

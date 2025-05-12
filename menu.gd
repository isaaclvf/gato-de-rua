extends Control

@onready var button: Button = $CenterContainer/VBoxContainer/Button

func _ready():
	button.pressed.connect(_on_jogar_pressed)

func _on_jogar_pressed():
	get_tree().change_scene_to_file("res://src/game.tscn")

extends Area2D

@export var content: String

@onready var label: Label = $Label

func _ready() -> void:
	label.visible = false

func _on_body_entered(body: Node2D) -> void:
	label.text = content
	label.visible = true

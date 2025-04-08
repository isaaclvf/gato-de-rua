extends Node2D

signal mouse_clicked(position: Vector2, button_index: int)

@export var normal_color := Color.RED
@export var clicked_color := Color.BLUE
@export var pointer_size := 2.6

@onready var sprite := $Sprite2D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	if sprite.texture != null:
		sprite.modulate = normal_color
		return
	
	sprite.texture = create_mouse_texture(normal_color)

func _process(_delta):
	global_position = get_global_mouse_position()

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if sprite.texture == null:
				sprite.modulate = clicked_color
			else:
				sprite.texture = create_mouse_texture(clicked_color)
			mouse_clicked.emit(global_position, event.button_index)
		else:
			if sprite.texture == null:
				sprite.modulate = normal_color
			else:
				sprite.texture = create_mouse_texture(normal_color)

func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func create_mouse_texture(color: Color):
	var image = Image.create(pointer_size, pointer_size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.create_from_image(image)
	return texture

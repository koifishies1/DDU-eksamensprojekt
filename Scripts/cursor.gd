extends TextureRect

@export var normal_texture: Texture2D
@export var click_texture: Texture2D
@export var hotspot := Vector2.ZERO

var _was_left_pressed := false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	top_level = true
	z_as_relative = false
	z_index = 4096
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = normal_texture

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position() - hotspot
	var is_left_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if is_left_pressed:
		texture = click_texture
	else:
		texture = normal_texture

	if is_left_pressed and not _was_left_pressed:
		%Mouseclick.play()

	_was_left_pressed = is_left_pressed

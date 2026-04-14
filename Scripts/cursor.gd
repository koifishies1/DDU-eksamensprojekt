extends TextureRect

@export var normal_texture: Texture2D
@export var click_texture: Texture2D
@export var hotspot := Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = normal_texture

func _process(_delta: float) -> void:
	position = get_viewport().get_mouse_position() - hotspot

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		texture = click_texture
	else:
		texture = normal_texture

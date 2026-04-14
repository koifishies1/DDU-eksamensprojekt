extends TextureButton

@export var windowBackground: Control

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if windowBackground:
		windowBackground.visible = false

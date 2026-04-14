extends TextureRect

@export var window_root: Control
@export var drag_zone_height: float = 30.0

var dragging := false
var drag_offset := Vector2.ZERO

func _gui_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_mouse := get_local_mouse_position()
			var drag_rect := Rect2(0, 0, size.x, drag_zone_height)

			if drag_rect.has_point(local_mouse):
				dragging = true
				if window_root:
					drag_offset = get_global_mouse_position() - window_root.global_position
		else:
			dragging = false

	elif event is InputEventMouseMotion and dragging:
		if window_root:
			window_root.global_position = get_global_mouse_position() - drag_offset

extends Control

@export var drag_zone_height: float = 30.0

var dragging := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	print("Notepad drag script ready on:", name)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	print("EVENT:", event)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		print("Mouse click detected")

		if event.pressed:
			print("Mouse DOWN")

			var local_mouse := get_local_mouse_position()
			print("Local mouse position:", local_mouse)

			var drag_rect := Rect2(0, 0, size.x, drag_zone_height)
			print("Drag rect:", drag_rect)

			if drag_rect.has_point(local_mouse):
				print("INSIDE DRAG ZONE → START DRAG")
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				print("Drag offset:", drag_offset)
			else:
				print("OUTSIDE DRAG ZONE → NO DRAG")

		else:
			print("Mouse UP → STOP DRAG")
			dragging = false

	elif event is InputEventMouseMotion:
		if dragging:
			print("Dragging... mouse:", get_global_mouse_position())
			global_position = get_global_mouse_position() - drag_offset
		else:
			print("Mouse moving, but NOT dragging")

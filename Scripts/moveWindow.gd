extends TextureRect

@export var window_root: Control
@export var drag_zone_height: float = 30.0

var dragging := false
var drag_offset := Vector2.ZERO

func _ready() -> void:
	if not is_in_group("desktop_window_surface"):
		add_to_group("desktop_window_surface")
	if window_root and not window_root.is_in_group("desktop_window"):
		window_root.add_to_group("desktop_window")


func _bring_window_to_front() -> void:
	if window_root == null:
		return

	if not window_root.is_in_group("desktop_window"):
		window_root.add_to_group("desktop_window")

	var top_z := 0
	for node in get_tree().get_nodes_in_group("desktop_window"):
		if node is Control:
			top_z = max(top_z, (node as Control).z_index)

	window_root.z_index = top_z + 1


func _gui_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_bring_window_to_front()
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

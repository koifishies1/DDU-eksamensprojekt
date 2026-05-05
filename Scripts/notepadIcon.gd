extends TextureButton

var _hint_flash_tween: Tween


func _ready() -> void:
	if _should_show_day1_notepad_hint():
		_start_day1_hint_flash()


func _should_show_day1_notepad_hint() -> bool:
	var gp := get_node_or_null("/root/GameProgress")
	if gp == null or not gp.has_method("get_current_night"):
		return false
	return int(gp.call("get_current_night")) == 1


func _start_day1_hint_flash() -> void:
	_stop_day1_hint_flash()
	_hint_flash_tween = create_tween()
	_hint_flash_tween.set_loops()
	_hint_flash_tween.set_trans(Tween.TRANS_SINE)
	_hint_flash_tween.set_ease(Tween.EASE_IN_OUT)
	_hint_flash_tween.tween_property(self, "modulate:a", 0.35, 0.5)
	_hint_flash_tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _stop_day1_hint_flash() -> void:
	if _hint_flash_tween != null:
		_hint_flash_tween.kill()
		_hint_flash_tween = null
	modulate = Color(1, 1, 1, 1)


func _is_blocked_by_window() -> bool:
	var mouse_pos := get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("desktop_window_surface"):
		if not (node is Control):
			continue
		var surface := node as Control
		var owner_window := surface.get("window_root") as Control
		if owner_window == null or not owner_window.visible:
			continue
		if owner_window == %notepad:
			continue
		if surface.get_global_rect().has_point(mouse_pos):
			return true
	return false


func _bring_window_to_front(window: Control) -> void:
	if window == null:
		return

	if not window.is_in_group("desktop_window"):
		window.add_to_group("desktop_window")

	var top_z := 0
	for node in get_tree().get_nodes_in_group("desktop_window"):
		if node is Control:
			top_z = max(top_z, (node as Control).z_index)

	window.z_index = top_z + 1


func _on_pressed() -> void:
	if _is_blocked_by_window():
		return
	_stop_day1_hint_flash()
	%notepad.visible = true
	_bring_window_to_front(%notepad)

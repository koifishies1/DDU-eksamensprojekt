extends TextureButton

func _is_blocked_by_window() -> bool:
	var mouse_pos := get_global_mouse_position()
	for node in get_tree().get_nodes_in_group("desktop_window_surface"):
		if not (node is Control):
			continue
		var surface := node as Control
		var owner_window := surface.get("window_root") as Control
		if owner_window == null or not owner_window.visible:
			continue
		if owner_window == %mail:
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


func _pressed() -> void:
	if _is_blocked_by_window():
		return
	%mail.visible = true
	_bring_window_to_front(%mail)
	var mail_manager := get_node_or_null("/root/MailManager")
	if mail_manager and mail_manager.has_method("record_action"):
		mail_manager.record_action("open_mail_app")


func _on_forward_btn_pressed() -> void:
	pass # Replace with function body.


func _on_delete_btn_pressed() -> void:
	pass # Replace with function body.

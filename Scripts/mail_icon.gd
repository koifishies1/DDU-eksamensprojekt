extends TextureButton


func _pressed() -> void:
	%mail.visible = true
	var mail_manager := get_node_or_null("/root/MailManager")
	if mail_manager and mail_manager.has_method("record_action"):
		mail_manager.record_action("open_mail_app")


func _on_forward_btn_pressed() -> void:
	pass # Replace with function body.


func _on_delete_btn_pressed() -> void:
	pass # Replace with function body.

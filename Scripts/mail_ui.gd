extends Control

@export var use_preview_data: bool = true
@export var inbox_list_path: NodePath
@export var subject_label_path: NodePath
@export var sender_label_path: NodePath
@export var body_text_path: NodePath
@export var forward_button_path: NodePath = ^"mailBackground/forwardBtn"
@export var delete_button_path: NodePath = ^"mailBackground/deleteBtn"
@export var logout_button_path: NodePath
@export var permanent_disposal: bool = false

var _inbox_list: VBoxContainer
var _subject_label: Label
var _sender_label: Label
var _body_text: RichTextLabel
var _forward_button: BaseButton
var _delete_button: BaseButton
var _logout_button: BaseButton

var _visible_emails: Array[Dictionary] = []
var _current_index: int = -1
var _session_hidden_ids: Dictionary = {}
var _session_results: Dictionary = {}
var _session_seen_ids: Dictionary = {}


func _ready() -> void:
	_resolve_or_create_ui()
	_wire_buttons()

	if not use_preview_data:
		var manager := get_node_or_null("/root/MailManager")
		if manager and manager.has_signal("inbox_updated"):
			manager.inbox_updated.connect(_refresh_from_source)

	_refresh_from_source()


func _resolve_or_create_ui() -> void:
	_inbox_list = get_node_or_null(inbox_list_path) as VBoxContainer
	_subject_label = get_node_or_null(subject_label_path) as Label
	_sender_label = get_node_or_null(sender_label_path) as Label
	_body_text = get_node_or_null(body_text_path) as RichTextLabel
	_forward_button = get_node_or_null(forward_button_path) as BaseButton
	_delete_button = get_node_or_null(delete_button_path) as BaseButton
	_logout_button = get_node_or_null(logout_button_path) as BaseButton

	if _inbox_list and _subject_label and _sender_label and _body_text:
		return

	_build_fallback_ui()


func _build_fallback_ui() -> void:
	var background := get_node_or_null("mailBackground") as Control
	if background == null:
		push_warning("mail_ui.gd expected a child node named 'mailBackground'.")
		return

	var content := background.get_node_or_null("MailContent") as Control
	if content == null:
		content = Control.new()
		content.name = "MailContent"
		background.add_child(content)
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 34.0
		content.offset_top = 78.0
		content.offset_right = -34.0
		content.offset_bottom = -34.0

	var root := HBoxContainer.new()
	root.name = "RootRow"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(root)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(240.0, 0.0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)

	_inbox_list = VBoxContainer.new()
	_inbox_list.name = "InboxList"
	_inbox_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_inbox_list)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_panel)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_col)

	_subject_label = Label.new()
	_subject_label.name = "SubjectLabel"
	_subject_label.text = "Subject"
	right_col.add_child(_subject_label)

	_sender_label = Label.new()
	_sender_label.name = "SenderLabel"
	_sender_label.text = "Sender"
	right_col.add_child(_sender_label)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(body_scroll)

	_body_text = RichTextLabel.new()
	_body_text.name = "BodyText"
	_body_text.fit_content = true
	_body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_text.scroll_active = true
	_body_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(_body_text)


func _wire_buttons() -> void:
	if _logout_button and not _logout_button.pressed.is_connected(_on_logout_pressed):
		_logout_button.pressed.connect(_on_logout_pressed)


func _refresh_from_source() -> void:
	if use_preview_data:
		_visible_emails = _get_preview_emails()
	else:
		var source_emails := _get_mail_manager_emails()
		_visible_emails = []
		for email in source_emails:
			var email_id: String = str(email.get("id", ""))
			if email_id.is_empty():
				continue
			_session_seen_ids[email_id] = true
			if _session_hidden_ids.has(email_id):
				continue
			_visible_emails.append(email)

	_rebuild_inbox_buttons()
	_select_first_available()


func _get_preview_emails() -> Array[Dictionary]:
	return [
		{
			"id": "preview_1",
			"subject": "Welcome to Mail Preview",
			"sender": "System",
			"body": "This is preview mode. Set use_preview_data to false to use MailManager data.",
			"is_read": false
		},
		{
			"id": "preview_2",
			"subject": "Long Message Test",
			"sender": "Commander",
			"body": "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6",
			"is_read": true
		},
		{
			"id": "preview_3",
			"subject": "Quest Available",
			"sender": "HQ",
			"body": "This is where your gameplay-unlocked emails will appear.",
			"is_read": false
		}
	]


func _get_mail_manager_emails() -> Array[Dictionary]:
	var manager := get_node_or_null("/root/MailManager")
	if manager == null or not manager.has_method("get_inbox_emails"):
		return []
	var emails: Variant = manager.call("get_inbox_emails")
	if emails is Array:
		return emails
	return []


func _rebuild_inbox_buttons() -> void:
	if _inbox_list == null:
		return

	for child in _inbox_list.get_children():
		child.queue_free()

	for i in range(_visible_emails.size()):
		var email: Dictionary = _visible_emails[i]
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		var sender: String = str(email.get("sender", "Unknown"))
		var subject: String = str(email.get("subject", "(no subject)"))
		var unread_prefix := ""
		if not bool(email.get("is_read", false)):
			unread_prefix = "* "
		button.text = "%s%s - %s" % [unread_prefix, sender, subject]
		button.pressed.connect(func() -> void: _open_email_at(i))
		_inbox_list.add_child(button)


func _select_first_available() -> void:
	if _visible_emails.is_empty():
		_current_index = -1
		_show_empty_state()
		return
	_open_email_at(0)


func _open_email_at(index: int) -> void:
	if index < 0 or index >= _visible_emails.size():
		return
	_current_index = index
	var email := _visible_emails[index]
	_show_email(email)
	_mark_read_if_real(email)


func _show_email(email: Dictionary) -> void:
	if _subject_label:
		_subject_label.text = str(email.get("subject", "(no subject)"))
	if _sender_label:
		_sender_label.text = "From: %s" % str(email.get("sender", "Unknown"))
	if _body_text:
		_body_text.text = str(email.get("body", ""))
		_body_text.scroll_to_line(0)


func _show_empty_state() -> void:
	if _subject_label:
		_subject_label.text = "No emails"
	if _sender_label:
		_sender_label.text = ""
	if _body_text:
		_body_text.text = "No delivered emails yet."


func _mark_read_if_real(email: Dictionary) -> void:
	if use_preview_data:
		return
	var manager := get_node_or_null("/root/MailManager")
	if manager == null or not manager.has_method("mark_email_read"):
		return
	var id: String = str(email.get("id", ""))
	if id.is_empty():
		return
	manager.call("mark_email_read", id)


func trigger_forward_action() -> void:
	_dispose_current_email("forward")
	print("forward")


func trigger_delete_action() -> void:
	_dispose_current_email("delete")
	print("delete")


func _dispose_current_email(chosen_action: String) -> void:
	if _current_index < 0 or _current_index >= _visible_emails.size():
		return

	var email: Dictionary = _visible_emails[_current_index]
	var email_id: String = str(email.get("id", ""))

	if use_preview_data:
		_visible_emails.remove_at(_current_index)
		_rebuild_inbox_buttons()
		if _visible_emails.is_empty():
			_current_index = -1
			_show_empty_state()
		else:
			_open_email_at(min(_current_index, _visible_emails.size() - 1))
		return

	var manager := get_node_or_null("/root/MailManager")
	if not email_id.is_empty() and not permanent_disposal:
		_session_hidden_ids[email_id] = true
		var expected := str(email.get("disposition", "forward")).to_lower()
		if expected != "forward" and expected != "delete":
			expected = "forward"
		_session_results[email_id] = {
			"chosen_action": chosen_action,
			"expected_action": expected,
			"correct": chosen_action == expected
		}
		_visible_emails.remove_at(_current_index)
		_rebuild_inbox_buttons()
		if _visible_emails.is_empty():
			_current_index = -1
			_show_empty_state()
		else:
			_open_email_at(min(_current_index, _visible_emails.size() - 1))
		return

	if manager and manager.has_method("classify_and_dispose_email") and not email_id.is_empty():
		manager.call("classify_and_dispose_email", email_id, chosen_action)
	_refresh_from_source()


func _on_logout_pressed() -> void:
	var manager := get_node_or_null("/root/MailManager")
	if manager == null:
		return

	var summary: Dictionary = {}
	if permanent_disposal and manager.has_method("get_disposal_summary"):
		summary = manager.call("get_disposal_summary")
	else:
		var total: int = _session_seen_ids.size()
		var disposed: int = _session_results.size()
		var correct: int = 0
		for email_id in _session_results.keys():
			var entry: Dictionary = _session_results[email_id]
			if bool(entry.get("correct", false)):
				correct += 1
		var incorrect: int = max(0, disposed - correct)
		var pending: int = max(0, total - disposed)
		var accuracy: float = 0.0
		if disposed > 0:
			accuracy = float(correct) / float(disposed)
		summary = {
			"total": total,
			"disposed": disposed,
			"correct": correct,
			"incorrect": incorrect,
			"pending": pending,
			"score_percent": int(round(accuracy * 100.0))
		}

	var message := "Day complete!\n\n"
	message += "Correct: %d\n" % int(summary.get("correct", 0))
	message += "Incorrect: %d\n" % int(summary.get("incorrect", 0))
	message += "Disposed: %d/%d\n" % [int(summary.get("disposed", 0)), int(summary.get("total", 0))]
	message += "Pending: %d\n" % int(summary.get("pending", 0))
	message += "Score: %d%%" % int(summary.get("score_percent", 0))

	var dialog := AcceptDialog.new()
	dialog.title = "End of Day"
	dialog.dialog_text = message
	dialog.unresizable = true
	get_tree().root.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

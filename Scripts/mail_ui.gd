extends Control

signal request_virus_release

@export var use_preview_data: bool = true
@export var inbox_list_path: NodePath
@export var subject_label_path: NodePath
@export var sender_label_path: NodePath
@export var body_text_path: NodePath
@export var forward_button_path: NodePath = ^"mailBackground/forwardBtn"
@export var delete_button_path: NodePath = ^"mailBackground/deleteBtn"
@export var logout_button_path: NodePath
@export var permanent_disposal: bool = false
@export var virus_controller_path: NodePath = ^"../../../Viruses"

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
var _email_glitch_enabled := false
var _email_glitch_elapsed := 0.0
var _email_glitch_interval := 0.06
var _base_subject_text := ""
var _base_sender_text := ""
var _base_body_text := ""
const _GLITCH_CHARSET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"


func _ready() -> void:
	_resolve_or_create_ui()
	_wire_virus_controller()
	_wire_buttons()
	_update_logout_button_state()
	set_process(false)
	_start_session_if_possible()

	if not use_preview_data:
		var manager := get_node_or_null("/root/MailManager")
		if manager and manager.has_signal("inbox_updated"):
			manager.inbox_updated.connect(_refresh_from_source)

	_refresh_from_source()


func _process(delta: float) -> void:
	if not _email_glitch_enabled:
		return
	if _current_index < 0:
		return
	_email_glitch_elapsed += maxf(0.0, delta)
	if _email_glitch_elapsed < _email_glitch_interval:
		return
	_email_glitch_elapsed = 0.0
	_apply_live_email_glitch()


func _start_session_if_possible() -> void:
	if use_preview_data:
		return
	var manager := get_node_or_null("/root/MailManager")
	if manager != null and manager.has_method("start_game_session"):
		# MailManager is an autoload singleton; always reset so each run of game.tscn gets a fresh timer.
		manager.call("start_game_session")


func _resolve_or_create_ui() -> void:
	_inbox_list = get_node_or_null(inbox_list_path) as VBoxContainer
	_subject_label = get_node_or_null(subject_label_path) as Label
	_sender_label = get_node_or_null(sender_label_path) as Label
	_body_text = get_node_or_null(body_text_path) as RichTextLabel
	_forward_button = get_node_or_null(forward_button_path) as BaseButton
	_delete_button = get_node_or_null(delete_button_path) as BaseButton
	_logout_button = get_node_or_null(logout_button_path) as BaseButton

	if _inbox_list and _subject_label and _sender_label and _body_text:
		_apply_mail_text_layout()
		return

	_build_fallback_ui()
	_apply_mail_text_layout()


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
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(body_scroll)

	_body_text = RichTextLabel.new()
	_body_text.name = "BodyText"
	_body_text.fit_content = false
	_body_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_body_text.scroll_active = false
	_body_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_text.set_v_size_flags(Control.SIZE_SHRINK_BEGIN)
	body_scroll.add_child(_body_text)


func _apply_mail_text_layout() -> void:
	if _body_text != null:
		_body_text.bbcode_enabled = true
		_body_text.fit_content = false
		_body_text.scroll_active = false
		_body_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_body_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body_text.set_v_size_flags(Control.SIZE_SHRINK_BEGIN)
		var parent := _body_text.get_parent()
		if parent is ScrollContainer:
			(parent as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if not _body_text.resized.is_connected(_on_mail_body_text_resized):
			_body_text.resized.connect(_on_mail_body_text_resized)
		_queue_mail_body_height_refresh()
	if _subject_label != null:
		_subject_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_subject_label.clip_text = false
		_subject_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _sender_label != null:
		_sender_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sender_label.clip_text = false
		_sender_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_mail_body_text_resized() -> void:
	_queue_mail_body_height_refresh()


func _queue_mail_body_height_refresh() -> void:
	if _body_text == null:
		return
	call_deferred("_run_mail_body_height_refresh")


func _run_mail_body_height_refresh() -> void:
	if _body_text == null or not is_instance_valid(_body_text) or not _body_text.is_inside_tree():
		return
	var h: float = _body_text.get_content_height()
	_body_text.custom_minimum_size = Vector2(0.0, maxf(h, 1.0))


func _wire_buttons() -> void:
	if _logout_button and not _logout_button.pressed.is_connected(_on_logout_pressed):
		_logout_button.pressed.connect(_on_logout_pressed)


func _refresh_from_source() -> void:
	var preferred_email_id := _get_current_email_id()

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
	if not _open_email_by_id(preferred_email_id):
		_select_first_available()
	_update_logout_button_state()


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
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var sender: String = str(email.get("sender", "Unknown"))
		var subject: String = str(email.get("subject", "(no subject)"))
		button.text = "%s - %s" % [sender, subject]
		button.pressed.connect(func() -> void: _open_email_at(i))
		_inbox_list.add_child(button)


func _select_first_available() -> void:
	if _visible_emails.is_empty():
		_current_index = -1
		_show_empty_state()
		return
	_open_email_at(0)


func _get_current_email_id() -> String:
	if _current_index < 0 or _current_index >= _visible_emails.size():
		return ""
	return str(_visible_emails[_current_index].get("id", ""))


func _open_email_by_id(email_id: String) -> bool:
	if email_id.is_empty():
		return false
	for i in range(_visible_emails.size()):
		if str(_visible_emails[i].get("id", "")) == email_id:
			_open_email_at(i)
			return true
	return false


func _open_email_at(index: int) -> void:
	if index < 0 or index >= _visible_emails.size():
		return
	_current_index = index
	var email := _visible_emails[index]
	_show_email(email)
	_mark_read_if_real(email)


func _show_email(email: Dictionary) -> void:
	_base_subject_text = str(email.get("subject", "(no subject)"))
	_base_sender_text = "From: %s" % str(email.get("sender", "Unknown"))
	_base_body_text = str(email.get("body", ""))

	if _subject_label:
		_subject_label.text = _base_subject_text
	if _sender_label:
		_sender_label.text = _base_sender_text
	if _body_text:
		_body_text.text = _base_body_text
		_body_text.scroll_to_line(0)
	_apply_live_email_glitch()
	_queue_mail_body_height_refresh()


func _show_empty_state() -> void:
	_base_subject_text = "No emails"
	_base_sender_text = ""
	_base_body_text = "No delivered emails yet."
	if _subject_label:
		_subject_label.text = _base_subject_text
	if _sender_label:
		_sender_label.text = _base_sender_text
	if _body_text:
		_body_text.text = _base_body_text
	_queue_mail_body_height_refresh()


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
		_update_logout_button_state()
		return

	var manager := get_node_or_null("/root/MailManager")
	if not email_id.is_empty() and not permanent_disposal:
		_session_hidden_ids[email_id] = true
		var expected := _get_expected_action(email)
		if expected != "forward" and expected != "delete":
			expected = "forward"
		var is_correct := chosen_action == expected
		_session_results[email_id] = {
			"chosen_action": chosen_action,
			"expected_action": expected,
			"correct": is_correct
		}
		if _should_trigger_virus(chosen_action, expected):
			_try_request_virus_release()
		_visible_emails.remove_at(_current_index)
		_rebuild_inbox_buttons()
		if _visible_emails.is_empty():
			_current_index = -1
			_show_empty_state()
		else:
			_open_email_at(min(_current_index, _visible_emails.size() - 1))
		_update_logout_button_state()
		return

	if manager and manager.has_method("classify_and_dispose_email") and not email_id.is_empty():
		var result: Variant = manager.call("classify_and_dispose_email", email_id, chosen_action)
		if result is Dictionary and _should_trigger_virus(
			chosen_action,
			str(result.get("expected_action", "forward"))
		):
			_try_request_virus_release()
	_refresh_from_source()
	_update_logout_button_state()


func _get_expected_action(email: Dictionary) -> String:
	var metadata: Dictionary = email.get("metadata", {})
	var expected := str(metadata.get("disposition", email.get("disposition", "forward"))).to_lower()
	if expected != "forward" and expected != "delete":
		expected = "forward"
	return expected


func _try_request_virus_release() -> void:
	var gp := get_node_or_null("/root/GameProgress")
	if gp == null or not gp.has_method("viruses_enabled_this_night"):
		return
	if not bool(gp.call("viruses_enabled_this_night")):
		return
	request_virus_release.emit()


func _should_trigger_virus(chosen_action: String, expected_action: String) -> bool:
	return chosen_action == "forward" and expected_action == "delete"


func _wire_virus_controller() -> void:
	var controller := get_node_or_null(virus_controller_path)
	if controller == null:
		push_warning("mail_ui.gd could not find virus controller at path: %s" % virus_controller_path)
		return
	if not controller.has_method("release_random_virus"):
		push_warning("Virus controller is missing release_random_virus().")
		return
	if not request_virus_release.is_connected(Callable(controller, "release_random_virus")):
		request_virus_release.connect(Callable(controller, "release_random_virus"))


func _on_logout_pressed() -> void:
	if _visible_emails.size() > 0:
		_update_logout_button_state()
		return

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

	var elapsed_seconds: int = 0
	if manager.has_method("get_elapsed_game_seconds"):
		elapsed_seconds = int(manager.call("get_elapsed_game_seconds"))
	summary["elapsed_seconds"] = maxi(0, elapsed_seconds)
	if manager.has_method("set_last_run_summary"):
		manager.call("set_last_run_summary", summary)

	if not use_preview_data:
		var gp := get_node_or_null("/root/GameProgress")
		if gp != null and gp.has_method("complete_shift_end_of_day"):
			gp.call("complete_shift_end_of_day")

	get_tree().change_scene_to_file("res://Scenes/end_screen.tscn")


func _update_logout_button_state() -> void:
	if _logout_button == null:
		return
	_logout_button.disabled = _visible_emails.size() > 0


func set_email_glitch_virus_active(active: bool = true) -> void:
	_email_glitch_enabled = active
	_email_glitch_elapsed = 0.0
	set_process(_email_glitch_enabled)
	if _email_glitch_enabled:
		_apply_live_email_glitch()


func _apply_live_email_glitch() -> void:
	if not _email_glitch_enabled:
		return
	if _subject_label:
		_subject_label.text = _glitch_text(_base_subject_text, 0.20)
	if _sender_label:
		_sender_label.text = _glitch_text(_base_sender_text, 0.14)
	if _body_text:
		_body_text.text = _glitch_text(_base_body_text, 0.10)
		_queue_mail_body_height_refresh()


func _glitch_text(source: String, chance: float) -> String:
	if source.is_empty():
		return source
	var out := ""
	var p := clampf(chance, 0.0, 1.0)
	var in_bbcode_tag := false
	for i in range(source.length()):
		var ch := source[i]
		if ch == "[":
			in_bbcode_tag = true
			out += ch
			continue
		if in_bbcode_tag:
			out += ch
			if ch == "]":
				in_bbcode_tag = false
			continue
		var code := source.unicode_at(i)
		var is_space := ch == " " or ch == "\n" or ch == "\t"
		if is_space or code < 33:
			out += ch
			continue
		if randf() < p:
			var idx := randi() % _GLITCH_CHARSET.length()
			out += _GLITCH_CHARSET[idx]
		else:
			out += ch
	return out

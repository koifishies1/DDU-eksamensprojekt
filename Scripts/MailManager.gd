extends Node
class_name MailManager

signal inbox_updated
signal email_delivered(email_id: String)
signal email_read(email_id: String)
signal flag_changed(flag_name: String, value: bool)
signal action_recorded(action_name: String, total: int)
signal email_disposed(email_id: String, chosen_action: String, was_correct: bool)

const SAVE_PATH := "user://mail_save.json"
const EMAIL_DB_PATH := "res://Data/emails.json"

var email_db: Dictionary = {}
var inbox: Array[String] = []
var read_emails: Dictionary = {}
var flags: Dictionary = {}
var actions: Dictionary = {}
var disposal_results: Dictionary = {}

var _delivery_counter: int = 0


func _ready() -> void:
	_load_email_database()
	_load_state()
	evaluate_unlocks()


func _load_email_database() -> void:
	email_db.clear()

	var loaded_any := false
	if FileAccess.file_exists(EMAIL_DB_PATH):
		var file := FileAccess.open(EMAIL_DB_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				for entry in parsed:
					if entry is Dictionary:
						register_email(entry)
				loaded_any = email_db.size() > 0
			else:
				push_warning("MailManager expected an Array in %s." % EMAIL_DB_PATH)
		else:
			push_warning("MailManager could not open %s." % EMAIL_DB_PATH)

	if not loaded_any:
		for email_data in _get_default_email_data():
			register_email(email_data)


func _get_default_email_data() -> Array[Dictionary]:
	return [
		{
			"id": "welcome_mail",
			"subject": "Welcome to your Inbox",
			"sender": "System",
			"body": "This inbox updates dynamically based on what you do in the game.",
			"conditions": {}
		},
		{
			"id": "mail_app_opened_hint",
			"subject": "You found the Mail app",
			"sender": "Tutorial Bot",
			"body": "Great. Try reading messages and exploring. New messages can depend on flags, actions, and previously read emails.",
			"conditions": {
				"required_actions": {"open_mail_app": 1}
			}
		},
		{
			"id": "first_read_followup",
			"subject": "Nice, you read your first email",
			"sender": "System",
			"body": "This email unlocked because you read the welcome message.",
			"conditions": {
				"required_read": ["welcome_mail"]
			}
		},
		{
			"id": "quest_ready",
			"subject": "Quest Briefing",
			"sender": "Commander",
			"body": "A new objective is available.",
			"conditions": {
				"required_flags": ["quest_unlocked"],
				"forbidden_flags": ["quest_complete"]
			}
		},
		{
			"id": "quest_complete_mail",
			"subject": "Objective Complete",
			"sender": "Commander",
			"body": "Excellent work. Your completion has been logged.",
			"conditions": {
				"required_flags": ["quest_complete"],
				"required_read": ["quest_ready"]
			}
		}
	]


func register_email(email_data: Dictionary) -> void:
	var id: String = str(email_data.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("MailManager.register_email called without a valid id.")
		return

	var normalized := {
		"id": id,
		"subject": str(email_data.get("subject", "")),
		"sender": str(email_data.get("sender", "Unknown")),
		"body": str(email_data.get("body", "")),
		"disposition": str(email_data.get("disposition", "")),
		"conditions": email_data.get("conditions", {}),
		"metadata": email_data.get("metadata", {}),
	}
	email_db[id] = normalized


func get_email(email_id: String) -> Dictionary:
	if not email_db.has(email_id):
		return {}
	var email: Dictionary = email_db[email_id].duplicate(true)
	email["is_read"] = is_email_read(email_id)
	email["is_delivered"] = has_email(email_id)
	email["is_disposed"] = disposal_results.has(email_id)
	return email


func get_inbox_ids() -> Array[String]:
	return inbox.duplicate()


func get_inbox_emails() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for email_id in inbox:
		result.append(get_email(email_id))
	return result


func has_email(email_id: String) -> bool:
	return inbox.has(email_id)


func is_email_read(email_id: String) -> bool:
	return bool(read_emails.get(email_id, false))


func deliver_email(email_id: String) -> bool:
	if not email_db.has(email_id):
		push_warning("Tried to deliver unknown email id: %s" % email_id)
		return false
	if has_email(email_id):
		return false

	inbox.append(email_id)
	_delivery_counter += 1
	_emit_state_changed(email_id)
	email_delivered.emit(email_id)
	return true


func mark_email_read(email_id: String) -> bool:
	if not has_email(email_id):
		return false
	if is_email_read(email_id):
		return false

	read_emails[email_id] = true
	email_read.emit(email_id)
	_emit_state_changed(email_id)
	evaluate_unlocks()
	return true


func remove_email(email_id: String) -> bool:
	var index := inbox.find(email_id)
	if index == -1:
		return false

	inbox.remove_at(index)
	read_emails.erase(email_id)
	_emit_state_changed(email_id)
	return true


func classify_and_dispose_email(email_id: String, chosen_action: String) -> Dictionary:
	var action := chosen_action.strip_edges().to_lower()
	if action != "forward" and action != "delete":
		return {"ok": false, "error": "invalid_action"}
	if not email_db.has(email_id):
		return {"ok": false, "error": "unknown_email"}
	if not has_email(email_id):
		return {"ok": false, "error": "email_not_in_inbox"}

	var expected_action := _get_expected_action(email_id)
	var is_correct := action == expected_action
	disposal_results[email_id] = {
		"chosen_action": action,
		"expected_action": expected_action,
		"correct": is_correct
	}

	remove_email(email_id)
	email_disposed.emit(email_id, action, is_correct)

	return {
		"ok": true,
		"email_id": email_id,
		"chosen_action": action,
		"expected_action": expected_action,
		"correct": is_correct
	}


func get_disposal_summary() -> Dictionary:
	var total_classifiable: int = 0
	for email_id in email_db.keys():
		var expected := _get_expected_action(str(email_id))
		if expected == "forward" or expected == "delete":
			total_classifiable += 1

	var disposed_count: int = disposal_results.size()
	var correct_count: int = 0
	for email_id in disposal_results.keys():
		var entry: Dictionary = disposal_results[email_id]
		if bool(entry.get("correct", false)):
			correct_count += 1

	var incorrect_count: int = max(0, disposed_count - correct_count)
	var pending_count: int = max(0, total_classifiable - disposed_count)
	var accuracy: float = 0.0
	if disposed_count > 0:
		accuracy = float(correct_count) / float(disposed_count)

	return {
		"total": total_classifiable,
		"disposed": disposed_count,
		"correct": correct_count,
		"incorrect": incorrect_count,
		"pending": pending_count,
		"accuracy": accuracy,
		"score_percent": int(round(accuracy * 100.0))
	}


func _get_expected_action(email_id: String) -> String:
	if not email_db.has(email_id):
		return "forward"
	var email: Dictionary = email_db[email_id]
	var metadata: Dictionary = email.get("metadata", {})
	var expected := str(metadata.get("disposition", email.get("disposition", "forward"))).to_lower()
	if expected != "forward" and expected != "delete":
		expected = "forward"
	return expected


func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)
	_emit_state_changed()
	evaluate_unlocks()


func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))


func record_action(action_name: String, amount: int = 1) -> void:
	var current: int = int(actions.get(action_name, 0))
	var total: int = max(0, current + amount)
	actions[action_name] = total
	action_recorded.emit(action_name, total)
	_emit_state_changed()
	evaluate_unlocks()


func get_action_count(action_name: String) -> int:
	return int(actions.get(action_name, 0))


func evaluate_unlocks() -> void:
	var delivered_any := false
	for email_id in email_db.keys():
		if has_email(email_id):
			continue
		if disposal_results.has(email_id):
			continue
		if _conditions_met(email_db[email_id].get("conditions", {})):
			deliver_email(email_id)
			delivered_any = true

	if delivered_any:
		evaluate_unlocks()


func _conditions_met(conditions: Dictionary) -> bool:
	var required_flags: Array = conditions.get("required_flags", [])
	for flag_name in required_flags:
		if not has_flag(str(flag_name)):
			return false

	var forbidden_flags: Array = conditions.get("forbidden_flags", [])
	for flag_name in forbidden_flags:
		if has_flag(str(flag_name)):
			return false

	var required_read: Array = conditions.get("required_read", [])
	for email_id in required_read:
		if not is_email_read(str(email_id)):
			return false

	var required_delivered: Array = conditions.get("required_delivered", [])
	for email_id in required_delivered:
		if not has_email(str(email_id)):
			return false

	var required_actions: Dictionary = conditions.get("required_actions", {})
	for action_name in required_actions.keys():
		var needed: int = int(required_actions[action_name])
		if get_action_count(str(action_name)) < needed:
			return false

	return true


func _emit_state_changed(_email_id: String = "") -> void:
	inbox_updated.emit()
	_save_state()


func _save_state() -> void:
	var data := {
		"inbox": inbox,
		"read_emails": read_emails,
		"flags": flags,
		"actions": actions,
		"disposal_results": disposal_results,
		"delivery_counter": _delivery_counter,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("MailManager could not save state to %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("MailManager could not load state from %s" % SAVE_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MailManager save file is invalid JSON dictionary.")
		return

	inbox.clear()
	for email_id in parsed.get("inbox", []):
		var id := str(email_id)
		if email_db.has(id):
			inbox.append(id)

	read_emails = parsed.get("read_emails", {})
	flags = parsed.get("flags", {})
	actions = parsed.get("actions", {})
	disposal_results = parsed.get("disposal_results", {})
	_delivery_counter = int(parsed.get("delivery_counter", inbox.size()))


func reset_all_mail_data() -> void:
	inbox.clear()
	read_emails.clear()
	flags.clear()
	actions.clear()
	disposal_results.clear()
	_delivery_counter = 0
	_save_state()
	evaluate_unlocks()

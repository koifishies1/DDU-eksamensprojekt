extends Control

@export var body_text_path: NodePath
@export var auto_discover_names: PackedStringArray = [
	"bodytext",
	"BodyText",
	"notepadBodyText",
	"NotepadBodyText"
]
const DAY_TEXTS_PATH := "res://Data/notepad_day_texts.json"

var _day_texts: Dictionary = {
	"1": "Dear Secretary,\n\nWelcome to the company.",
	"2": "Dear coworker,\n\nStay alert for phishing signs.",
	"3": "Dear coworker,\n\nNew warning signs are now in play.",
	"4": "Dear coworker,\n\nWatch for grammar issues and suspicious links.",
	"5": "Dear coworker,\n\nFinal day: stay sharp and finish strong."
}


func _ready() -> void:
	_load_day_texts_from_json()
	_apply_body_layout()
	_refresh_notepad_text()
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_signal("night_changed"):
		gp.night_changed.connect(_on_night_changed)


func _on_night_changed(_new_night: int) -> void:
	_refresh_notepad_text()


func _refresh_notepad_text() -> void:
	var body := _resolve_body_text_node()
	if body == null:
		push_warning("notepad_day_text.gd could not find notepad body text node.")
		return

	var day: int = 1
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("get_current_night"):
		day = int(gp.call("get_current_night"))
	var safe_day := clampi(day, 1, 5)
	var content: String = str(_day_texts.get(str(safe_day), _day_texts.get("1", "")))
	_set_text_on_node(body, content)


func _load_day_texts_from_json() -> void:
	if not FileAccess.file_exists(DAY_TEXTS_PATH):
		push_warning("Notepad day text JSON missing: %s" % DAY_TEXTS_PATH)
		return
	var file := FileAccess.open(DAY_TEXTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open notepad day text JSON: %s" % DAY_TEXTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid notepad day text JSON format (expected Dictionary).")
		return
	_day_texts = parsed as Dictionary


func _apply_body_layout() -> void:
	var body := _resolve_body_text_node()
	if body is RichTextLabel:
		var rtl := body as RichTextLabel
		rtl.fit_content = false
		rtl.scroll_active = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.set_v_size_flags(Control.SIZE_SHRINK_BEGIN)
		var parent := rtl.get_parent()
		if parent is ScrollContainer:
			(parent as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if not rtl.resized.is_connected(_on_notepad_body_resized):
			rtl.resized.connect(_on_notepad_body_resized)
		_queue_notepad_body_height_refresh()


func _on_notepad_body_resized() -> void:
	_queue_notepad_body_height_refresh()


func _queue_notepad_body_height_refresh() -> void:
	call_deferred("_run_notepad_body_height_refresh")


func _run_notepad_body_height_refresh() -> void:
	var rtl := _resolve_body_text_node() as RichTextLabel
	if rtl == null or not is_instance_valid(rtl) or not rtl.is_inside_tree():
		return
	var h: float = rtl.get_content_height()
	rtl.custom_minimum_size = Vector2(0.0, maxf(h, 1.0))


func _resolve_body_text_node() -> Control:
	if not NodePath(body_text_path).is_empty():
		var by_path := get_node_or_null(body_text_path)
		if by_path is Control:
			return by_path as Control

	for node_name in auto_discover_names:
		var found := find_child(StringName(node_name), true, false)
		if found is Control:
			return found as Control
	return null


func _set_text_on_node(target: Control, value: String) -> void:
	if target is RichTextLabel:
		(target as RichTextLabel).text = value
		_queue_notepad_body_height_refresh()
	elif target is Label:
		(target as Label).text = value
	elif target is TextEdit:
		(target as TextEdit).text = value

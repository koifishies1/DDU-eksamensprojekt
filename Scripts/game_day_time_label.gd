extends Label

## Shows progression day (`GameProgress.current_night`) and shift countdown from MailManager session timer.

@export var shift_duration_seconds: int = 300

var _last_day: int = -1
var _last_remaining: int = -1
var _timeout_triggered := false


func _ready() -> void:
	_refresh(true)
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_signal("night_changed"):
		gp.night_changed.connect(_on_night_changed)


func _on_night_changed(_new_night: int) -> void:
	_timeout_triggered = false
	_refresh(true)


func _process(_delta: float) -> void:
	_refresh(false)


func _refresh(force: bool) -> void:
	var day: int = 1
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("get_current_night"):
		day = int(gp.call("get_current_night"))

	var elapsed: int = 0
	var mm := get_node_or_null("/root/MailManager")
	if mm != null and mm.has_method("get_elapsed_game_seconds"):
		elapsed = int(mm.call("get_elapsed_game_seconds"))
	var remaining: int = maxi(0, shift_duration_seconds - elapsed)

	if not force and day == _last_day and remaining == _last_remaining:
		return
	_last_day = day
	_last_remaining = remaining
	text = "Day %d  %s" % [day, _format_mm_ss(remaining)]

	if remaining <= 0 and not _timeout_triggered:
		_timeout_triggered = true
		get_tree().change_scene_to_file("res://Scenes/lose_cinematic.tscn")


func _format_mm_ss(total_seconds: int) -> String:
	var s: int = maxi(0, total_seconds)
	var m: int = s / 60
	var r: int = s % 60
	return "%02d:%02d" % [m, r]

extends Node2D

const GAME_SCENE := "res://Scenes/game.tscn"
const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"

@export var correct_label_path: NodePath = ^"Background/stats/EmailsCorrect"
@export var time_label_path: NodePath = ^"Background/stats/TimeSpent"
@export var count_duration_seconds: float = 1.2

var _correct_label: Label
var _time_label: Label
var _target_correct: int = 0
var _target_elapsed: int = 0
var _display_correct: int = 0
var _display_elapsed: int = 0
var _count_elapsed: float = 0.0


func _ready() -> void:
	_correct_label = get_node_or_null(correct_label_path) as Label
	_time_label = get_node_or_null(time_label_path) as Label
	_read_summary()
	_update_labels()
	set_process(true)


func _process(delta: float) -> void:
	if _display_correct >= _target_correct and _display_elapsed >= _target_elapsed:
		set_process(false)
		return

	_count_elapsed += delta
	var progress: float = 1.0
	if count_duration_seconds > 0.0:
		progress = clamp(_count_elapsed / count_duration_seconds, 0.0, 1.0)

	_display_correct = int(round(lerpf(0.0, float(_target_correct), progress)))
	_display_elapsed = int(round(lerpf(0.0, float(_target_elapsed), progress)))
	_update_labels()


func _read_summary() -> void:
	var manager := get_node_or_null("/root/MailManager")
	if manager == null or not manager.has_method("get_last_run_summary"):
		return
	var summary_variant: Variant = manager.call("get_last_run_summary")
	if summary_variant is Dictionary:
		var summary: Dictionary = summary_variant
		_target_correct = maxi(0, int(summary.get("correct", 0)))
		_target_elapsed = maxi(0, int(summary.get("elapsed_seconds", 0)))


func _update_labels() -> void:
	if _correct_label:
		_correct_label.text = str(_display_correct)
	if _time_label:
		_time_label.text = _format_seconds(_display_elapsed)


func _format_seconds(total_seconds: int) -> String:
	var safe_seconds: int = maxi(0, total_seconds)
	var minutes: int = safe_seconds / 60
	var seconds: int = safe_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_continue_btn_pressed() -> void:
	# Next shift: night was already advanced when you logged out.
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_main_menu_btn_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_try_again_btn_pressed() -> void:
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("replay_last_shift_instead_of_advancing"):
		gp.call("replay_last_shift_instead_of_advancing")
	get_tree().change_scene_to_file(GAME_SCENE)

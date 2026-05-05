extends Node2D

const LABEL_SHOW_AFTER_SECONDS := 5.0
const MENU_CHANGE_AFTER_ANIMATION_SECONDS := 3.0
const LOSE_SONG_START_AFTER_SECONDS := 0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var lose_label: Label = $ColorRect/Label
@onready var paper_fall_player: AudioStreamPlayer = $paperFall
@onready var lose_song_player: AudioStreamPlayer = $loseSong


func _ready() -> void:
	if lose_label:
		lose_label.visible = false

	if animation_player != null:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		if animation_player.has_animation("falling"):
			animation_player.play("falling")
			if paper_fall_player != null and paper_fall_player.stream != null:
				paper_fall_player.play()

	var lose_song_timer := get_tree().create_timer(LOSE_SONG_START_AFTER_SECONDS)
	lose_song_timer.timeout.connect(_start_lose_song, CONNECT_ONE_SHOT)

	var timer := get_tree().create_timer(LABEL_SHOW_AFTER_SECONDS)
	timer.timeout.connect(_show_lose_label, CONNECT_ONE_SHOT)


func _show_lose_label() -> void:
	if lose_label:
		lose_label.visible = true


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"falling":
		return
	await get_tree().create_timer(MENU_CHANGE_AFTER_ANIMATION_SECONDS).timeout
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _start_lose_song() -> void:
	if paper_fall_player != null:
		paper_fall_player.stop()
	if lose_song_player != null and lose_song_player.stream != null:
		lose_song_player.play()

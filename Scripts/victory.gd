extends Node2D

const MAIN_MENU_SCENE := "res://Scenes/main_menu.tscn"
const VICTORY_ANIM := &"victory"

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if animation_player == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	if animation_player.has_animation(VICTORY_ANIM):
		animation_player.play(VICTORY_ANIM)
	else:
		push_warning("Victory: missing animation '%s'; opening main menu." % VICTORY_ANIM)
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == VICTORY_ANIM:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)

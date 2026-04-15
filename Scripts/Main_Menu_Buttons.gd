extends Node2D


func _on_start_knap_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/cinematic.tscn")

func _on_settings_knap_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/settings_menu.tscn")


func _on_exit_knap_pressed() -> void:
	get_tree().quit()

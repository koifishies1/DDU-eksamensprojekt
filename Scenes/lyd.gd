extends Control

func _ready():
	$VBoxContainer/MasterSlider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	$VBoxContainer/MusicSlider.value = db_to_linear(AudioServer.get_bus_volume_db(1))
	$VBoxContainer/SFXSlider.value = db_to_linear(AudioServer.get_bus_volume_db(2))
	$VBoxContainer/AmbienceSlider.value = db_to_linear(AudioServer.get_bus_volume_db(3))



func _on_master_slider_focus_exited() -> void:
	release_focus()
func _on_music_slider_focus_exited() -> void:
	release_focus()
func _on_ambience_slider_focus_exited() -> void:
	release_focus()
func _on_sfx_slider_focus_exited() -> void:
	release_focus()

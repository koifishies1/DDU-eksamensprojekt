extends TextureRect

@export var day_1_texture: Texture2D
@export var day_2_texture: Texture2D
@export var day_3_texture: Texture2D
@export var day_4_texture: Texture2D
@export var day_5_texture: Texture2D


func _ready() -> void:
	_refresh_texture()
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_signal("night_changed"):
		gp.night_changed.connect(_on_night_changed)


func _on_night_changed(_new_night: int) -> void:
	_refresh_texture()


func _refresh_texture() -> void:
	var night: int = 1
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("get_current_night"):
		night = int(gp.call("get_current_night"))

	var chosen: Texture2D = day_1_texture
	if night >= 5:
		chosen = _first_assigned([day_5_texture, day_4_texture, day_3_texture, day_2_texture, day_1_texture])
	elif night == 4:
		chosen = _first_assigned([day_4_texture, day_3_texture, day_2_texture, day_1_texture])
	elif night == 3:
		chosen = _first_assigned([day_3_texture, day_2_texture, day_1_texture])
	elif night == 2:
		chosen = _first_assigned([day_2_texture, day_1_texture])

	if chosen != null:
		texture = chosen


func _first_assigned(options: Array[Texture2D]) -> Texture2D:
	for t in options:
		if t != null:
			return t
	return null

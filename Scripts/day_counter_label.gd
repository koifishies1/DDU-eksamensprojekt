extends Label

## Optional UI helper: attach to any Label to show the current night from GameProgress.


func _ready() -> void:
	_refresh()
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_signal("night_changed"):
		gp.night_changed.connect(_on_night_changed)


func _on_night_changed(_new_night: int) -> void:
	_refresh()


func _refresh() -> void:
	var gp := get_node_or_null("/root/GameProgress")
	if gp == null:
		return
	var n: int = 1
	if gp.has_method("get_current_night"):
		n = int(gp.call("get_current_night"))
	text = "Night %d" % n

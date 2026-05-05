extends Control

@export var recycle_bin_path: NodePath = ^"../desktop/recyclebinIcon"
@export var spawn_min: Vector2 = Vector2(280.0, 80.0)
@export var spawn_max: Vector2 = Vector2(980.0, 520.0)
@export var debug_drag: bool = false
@export var total_virus_instances: int = 4
@export var unresolved_duplicate_interval: float = 5.0
@export var lose_fade_to_black_seconds: float = 1.0
@export var pink_virus_name: String = "PinkVice"
@export var pink_start_speed: float = 180.0
@export var pink_speedup_per_bounce: float = 35.0
@export var pink_max_speed: float = 900.0
@export var pink_top_z_index: int = 4095
@export var laughing_skull_path: NodePath = ^"laughingSkull"
@export var laughing_skull_seconds: float = 1.1
@export var laugh_sound_path: NodePath = ^"laughingSkull/evilLaugh"

var _template_virus: CanvasItem
var _pink_virus: CanvasItem
var _pink_velocity := Vector2.ZERO
var _dragged_virus: CanvasItem
var _virus_dragging := false
var _virus_drag_offset := Vector2.ZERO
var _was_left_pressed := false
var _unresolved_duplicate_timer := 0.0
var _virus_split_seq: int = 0
var _lose_scene_triggered := false
var _current_night: int = 1
var _invert_mouse_virus_active := false
var _email_glitch_virus_active := false
var _laughing_skull: AnimatedSprite2D
var _evil_laugh_player: AudioStreamPlayer2D
var _skull_show_seq: int = 0


func _ready() -> void:
	randomize()
	var night: int = 1
	var gp := get_node_or_null("/root/GameProgress")
	if gp != null and gp.has_method("get_current_night"):
		night = int(gp.call("get_current_night"))
	_current_night = night
	unresolved_duplicate_interval = NightRules.phone_duplicate_interval_seconds(night)
	set_process(true)
	_cache_template_virus()
	_cache_pink_virus()
	_cache_laughing_skull()
	_ensure_virus_pool()
	_hide_all_viruses()


func release_random_virus() -> bool:
	if _try_activate_special_virus():
		_show_laughing_skull()
		return true

	var hidden_candidates: Array[CanvasItem] = []
	for child in get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			if not _is_virus_item(item):
				continue
			if not item.visible:
				hidden_candidates.append(item)

	if hidden_candidates.is_empty():
		return false

	var spawned := hidden_candidates[randi() % hidden_candidates.size()]
	spawned.visible = true
	if _is_pink_virus(spawned):
		_spawn_pink_virus(spawned)
	else:
		spawned.z_index = 2000 + _count_visible_viruses()
	_set_item_center_global(spawned, _random_spawn_position())

	if spawned.has_method("play"):
		spawned.call("play")

	if _count_visible_viruses() == 1:
		_play_virus_sound()
	_show_laughing_skull()
	return true


func _cache_laughing_skull() -> void:
	_laughing_skull = get_node_or_null(laughing_skull_path) as AnimatedSprite2D
	_evil_laugh_player = get_node_or_null(laugh_sound_path) as AudioStreamPlayer2D
	if _laughing_skull != null:
		_laughing_skull.visible = false
		if _laughing_skull.has_method("stop"):
			_laughing_skull.stop()


func _show_laughing_skull() -> void:
	if _laughing_skull == null:
		return
	_skull_show_seq += 1
	var show_seq: int = _skull_show_seq
	_laughing_skull.visible = true
	if _laughing_skull.has_method("play"):
		_laughing_skull.play()
	if _evil_laugh_player != null and _evil_laugh_player.stream != null:
		_evil_laugh_player.play()
	await get_tree().create_timer(maxf(0.1, laughing_skull_seconds)).timeout
	if show_seq != _skull_show_seq:
		return
	if _laughing_skull.has_method("stop"):
		_laughing_skull.stop()
	_laughing_skull.visible = false


func _try_activate_special_virus() -> bool:
	if _current_night < 3:
		return false

	var candidates: Array[String] = []
	if not _invert_mouse_virus_active:
		candidates.append("invert_mouse")
	if not _email_glitch_virus_active:
		candidates.append("email_glitch")
	if candidates.is_empty():
		return false

	var chosen: String = candidates[randi() % candidates.size()]
	if chosen == "invert_mouse":
		var cursor := _find_cursor_node()
		if cursor != null and cursor.has_method("set_inverted_mouse_virus_active"):
			cursor.call("set_inverted_mouse_virus_active", true)
			_invert_mouse_virus_active = true
			return true
		return false

	if chosen == "email_glitch":
		var mail_ui := _find_mail_ui_node()
		if mail_ui != null and mail_ui.has_method("set_email_glitch_virus_active"):
			mail_ui.call("set_email_glitch_virus_active", true)
			_email_glitch_virus_active = true
			return true
		return false

	return false


func _find_cursor_node() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.get_node_or_null(^"TileMapLayer/cursor")


func _find_mail_ui_node() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.get_node_or_null(^"gameController/desktop/mailIcon/mail")


func _process(_delta: float) -> void:
	if _lose_scene_triggered:
		return

	var is_left_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse_pos := get_viewport().get_mouse_position()
	var visible_count := _count_visible_viruses()

	if visible_count >= 10:
		_lose_scene_triggered = true
		_run_lose_fade_then_cinematic()
		return

	if visible_count == 0:
		_dragged_virus = null
		_virus_dragging = false
		_was_left_pressed = is_left_pressed
		_unresolved_duplicate_timer = 0.0
		return

	_update_pink_virus_motion(_delta)

	_unresolved_duplicate_timer += _delta
	if _unresolved_duplicate_timer >= unresolved_duplicate_interval:
		_unresolved_duplicate_timer = 0.0
		_double_visible_viruses()

	if is_left_pressed and not _was_left_pressed:
		_dragged_virus = _pick_top_virus_at_point(mouse_pos)
		var hit := _dragged_virus != null
		if debug_drag:
			print("[VirusDrag] press mouse=", mouse_pos, " hit=", hit)
		if hit:
			_virus_dragging = true
			_virus_drag_offset = mouse_pos - _get_item_global_position(_dragged_virus)
			if _is_pink_virus(_dragged_virus):
				_dragged_virus.z_index = pink_top_z_index
			else:
				_dragged_virus.z_index = 3000
			if debug_drag:
				print("[VirusDrag] start drag offset=", _virus_drag_offset)

	if not is_left_pressed and _was_left_pressed:
		if debug_drag and _virus_dragging:
			print("[VirusDrag] release over_bin=", _is_virus_over_recycle_bin())
		if _virus_dragging and _is_virus_over_recycle_bin():
			_clear_virus(_dragged_virus)
		_virus_dragging = false
		_dragged_virus = null

	if _virus_dragging and is_left_pressed:
		_set_item_global_position(_dragged_virus, mouse_pos - _virus_drag_offset)
		if debug_drag:
			print("[VirusDrag] moving to=", _get_item_global_position(_dragged_virus))
		if _is_pink_virus(_dragged_virus):
			_dragged_virus.z_index = pink_top_z_index

	_ensure_pink_on_top()

	_was_left_pressed = is_left_pressed


func _run_lose_fade_then_cinematic() -> void:
	set_process(false)
	var root := get_tree().current_scene
	if root == null or lose_fade_to_black_seconds <= 0.0:
		get_tree().change_scene_to_file("res://Scenes/lose_cinematic.tscn")
		return

	var layer := CanvasLayer.new()
	layer.layer = 100
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.color = Color.BLACK
	overlay.modulate.a = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)
	root.add_child(layer)

	var tw := overlay.create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, lose_fade_to_black_seconds)
	await tw.finished
	get_tree().change_scene_to_file("res://Scenes/lose_cinematic.tscn")


func _is_virus_over_recycle_bin() -> bool:
	var bin := get_node_or_null(recycle_bin_path) as Control
	if bin == null or _dragged_virus == null:
		return false
	return bin.get_global_rect().intersects(_get_item_rect(_dragged_virus))


func _clear_virus(virus: CanvasItem) -> void:
	if virus == null:
		return

	if virus.has_method("stop"):
		virus.call("stop")
	virus.visible = false
	if _is_pink_virus(virus):
		_pink_velocity = Vector2.ZERO
	_play_trash_sound()

	if _count_visible_viruses() == 0:
		_stop_virus_sound()


func _play_virus_sound() -> void:
	for child in get_children():
		if _is_trash_sound_node(child):
			continue
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).stream != null:
			(child as AudioStreamPlayer).play()
			return
		if child is AudioStreamPlayer2D and (child as AudioStreamPlayer2D).stream != null:
			(child as AudioStreamPlayer2D).play()
			return


func _play_trash_sound() -> void:
	var player := get_node_or_null(^"trashSound") as AudioStreamPlayer
	if player != null and player.stream != null:
		player.play()


func _stop_virus_sound() -> void:
	for child in get_children():
		if _is_trash_sound_node(child):
			continue
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
		elif child is AudioStreamPlayer2D:
			(child as AudioStreamPlayer2D).stop()


func _is_trash_sound_node(node: Node) -> bool:
	return node.name == "trashSound"


func _is_point_inside_item(item: CanvasItem, point: Vector2) -> bool:
	return _get_item_rect(item).has_point(point)


func _get_item_rect(item: CanvasItem) -> Rect2:
	if item is Control:
		return (item as Control).get_global_rect()
	if item is AnimatedSprite2D:
		var sprite := item as AnimatedSprite2D
		var local_rect := _animated_sprite2d_local_rect(sprite)
		return _transformed_rect_global_aabb(sprite.get_global_transform(), local_rect)

	var global_pos := _get_item_global_position(item)
	if item.has_method("get_rect"):
		var rect_variant: Variant = item.call("get_rect")
		if rect_variant is Rect2:
			var local_rect: Rect2 = rect_variant
			return _transformed_rect_global_aabb(
				(item as Node2D).get_global_transform(),
				local_rect
			)

	return Rect2(global_pos - Vector2(32.0, 32.0), Vector2(64.0, 64.0))


## AnimatedSprite2D has no get_rect() in some Godot builds; derive bounds from the current frame texture.
func _animated_sprite2d_local_rect(sprite: AnimatedSprite2D) -> Rect2:
	var frames := sprite.sprite_frames
	if frames == null:
		return Rect2(Vector2(-32.0, -32.0), Vector2(64.0, 64.0))
	var anim: StringName = sprite.animation
	if String(anim).is_empty():
		anim = &"default"
	if not frames.has_animation(anim) or frames.get_frame_count(anim) <= 0:
		return Rect2(Vector2(-32.0, -32.0), Vector2(64.0, 64.0))
	var tex: Texture2D = frames.get_frame_texture(anim, sprite.frame)
	if tex == null:
		return Rect2(Vector2(-32.0, -32.0), Vector2(64.0, 64.0))
	var sz: Vector2 = tex.get_size()
	if sprite.centered:
		return Rect2(-sz * 0.5 + sprite.offset, sz)
	return Rect2(sprite.offset, sz)


func _transformed_rect_global_aabb(xf: Transform2D, local_rect: Rect2) -> Rect2:
	var p0: Vector2 = xf * local_rect.position
	var p1: Vector2 = xf * Vector2(local_rect.end.x, local_rect.position.y)
	var p2: Vector2 = xf * local_rect.end
	var p3: Vector2 = xf * Vector2(local_rect.position.x, local_rect.end.y)
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _set_item_center_global(item: CanvasItem, center_global: Vector2) -> void:
	var r := _get_item_rect(item)
	var cur_center := r.get_center()
	var delta: Vector2 = center_global - cur_center
	_set_item_global_position(item, _get_item_global_position(item) + delta)


func _get_item_global_position(item: CanvasItem) -> Vector2:
	if item is Node2D:
		return (item as Node2D).global_position
	if item is Control:
		return (item as Control).global_position
	return Vector2.ZERO


func _set_item_global_position(item: CanvasItem, target_position: Vector2) -> void:
	if item is Node2D:
		(item as Node2D).global_position = target_position
	elif item is Control:
		(item as Control).global_position = target_position


func _random_spawn_position() -> Vector2:
	return Vector2(
		randf_range(min(spawn_min.x, spawn_max.x), max(spawn_min.x, spawn_max.x)),
		randf_range(min(spawn_min.y, spawn_max.y), max(spawn_min.y, spawn_max.y))
	)


func _cache_template_virus() -> void:
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			var candidate := child as CanvasItem
			if _is_pink_virus(candidate):
				continue
			_template_virus = candidate
			return


func _ensure_virus_pool() -> void:
	if _template_virus == null:
		return
	var current: int = _count_non_pink_virus_items()
	var target: int = max(1, total_virus_instances)
	while current < target:
		var clone: CanvasItem = _template_virus.duplicate() as CanvasItem
		if clone == null:
			return
		clone.name = "%s_%d" % [_template_virus.name, current + 1]
		add_child(clone)
		current += 1


func _hide_all_viruses() -> void:
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			(child as CanvasItem).visible = false


func _count_virus_items() -> int:
	var count := 0
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			count += 1
	return count


func _count_non_pink_virus_items() -> int:
	var count := 0
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			var item := child as CanvasItem
			if _is_pink_virus(item):
				continue
			count += 1
	return count


func _count_visible_viruses() -> int:
	var count := 0
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			if (child as CanvasItem).visible:
				count += 1
	return count


func _pick_top_virus_at_point(point: Vector2) -> CanvasItem:
	var picked: CanvasItem
	var best_z := -INF
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			var item := child as CanvasItem
			if not item.visible:
				continue
			if _is_point_inside_item(item, point) and item.z_index >= best_z:
				best_z = item.z_index
				picked = item
	return picked


func _is_virus_item(node: Node) -> bool:
	return node is CanvasItem and node is not AudioStreamPlayer and node is not AudioStreamPlayer2D


## Every interval: clone each visible virus once -> count goes N -> 2N.
func _double_visible_viruses() -> void:
	var sources: Array[CanvasItem] = []
	for child in get_children():
		if _is_virus_item(child):
			var item := child as CanvasItem
			if _is_pink_virus(item):
				continue
			if item.visible:
				sources.append(item)
	if sources.is_empty():
		return

	var base_z: int = 2000
	for child in get_children():
		if _is_virus_item(child):
			base_z = max(base_z, (child as CanvasItem).z_index)
	base_z = min(base_z, RenderingServer.CANVAS_ITEM_Z_MAX - 1)

	var i: int = 0
	for src in sources:
		var dup: CanvasItem = src.duplicate() as CanvasItem
		if dup == null:
			continue
		_virus_split_seq += 1
		dup.name = "%s_split_%d" % [src.name, _virus_split_seq]
		add_child(dup)
		dup.visible = true
		dup.z_index = clampi(
			base_z + 1 + i,
			RenderingServer.CANVAS_ITEM_Z_MIN,
			RenderingServer.CANVAS_ITEM_Z_MAX
		)
		i += 1
		_set_item_center_global(dup, _random_spawn_position())
		if dup.has_method("play"):
			dup.call("play")


func _cache_pink_virus() -> void:
	_pink_virus = null
	for child in get_children():
		if child is CanvasItem and _is_pink_virus(child as CanvasItem):
			_pink_virus = child as CanvasItem
			_spawn_pink_virus(_pink_virus)
			return


func _is_pink_virus(item: CanvasItem) -> bool:
	if item == null:
		return false
	return item.name == pink_virus_name


func _spawn_pink_virus(item: CanvasItem) -> void:
	if item == null:
		return
	item.z_index = _pink_z_index()
	_init_pink_velocity()


func _init_pink_velocity() -> void:
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	_pink_velocity = dir.normalized() * max(0.0, pink_start_speed)


func _ensure_pink_on_top() -> void:
	if _pink_virus != null and _pink_virus.visible:
		_pink_virus.z_index = _pink_z_index()


func _update_pink_virus_motion(delta: float) -> void:
	if _pink_virus == null or not _pink_virus.visible:
		return
	if _virus_dragging and _dragged_virus == _pink_virus:
		return
	if _pink_velocity.length_squared() <= 0.0001:
		_init_pink_velocity()

	var rect := _get_item_rect(_pink_virus)
	var center := rect.get_center()
	center += _pink_velocity * maxf(0.0, delta)

	var half := rect.size * 0.5
	var viewport_rect := get_viewport_rect()
	var min_x := viewport_rect.position.x + half.x
	var max_x := viewport_rect.end.x - half.x
	var min_y := viewport_rect.position.y + half.y
	var max_y := viewport_rect.end.y - half.y

	var bounced := false
	if center.x < min_x:
		center.x = min_x
		_pink_velocity.x = absf(_pink_velocity.x)
		bounced = true
	elif center.x > max_x:
		center.x = max_x
		_pink_velocity.x = -absf(_pink_velocity.x)
		bounced = true

	if center.y < min_y:
		center.y = min_y
		_pink_velocity.y = absf(_pink_velocity.y)
		bounced = true
	elif center.y > max_y:
		center.y = max_y
		_pink_velocity.y = -absf(_pink_velocity.y)
		bounced = true

	if bounced:
		var new_speed: float = minf(
			_pink_velocity.length() + maxf(0.0, pink_speedup_per_bounce),
			maxf(0.0, pink_max_speed)
		)
		if _pink_velocity.length_squared() > 0.0001:
			_pink_velocity = _pink_velocity.normalized() * new_speed

	_set_item_center_global(_pink_virus, center)


func _pink_z_index() -> int:
	return clampi(
		pink_top_z_index,
		RenderingServer.CANVAS_ITEM_Z_MIN,
		RenderingServer.CANVAS_ITEM_Z_MAX
	)

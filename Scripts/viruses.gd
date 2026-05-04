extends Control

@export var recycle_bin_path: NodePath = ^"../desktop/recyclebinIcon"
@export var spawn_min: Vector2 = Vector2(280.0, 80.0)
@export var spawn_max: Vector2 = Vector2(980.0, 520.0)
@export var debug_drag: bool = false
@export var drag_hit_radius: float = 90.0
@export var total_virus_instances: int = 4
@export var enable_annoying_effects: bool = true
@export var jitter_mouse: bool = true
@export var mouse_jitter_interval: float = 0.2
@export var mouse_jitter_pixels: float = 10.0
@export var unresolved_duplicate_interval: float = 5.0
@export var lose_virus_threshold: int = 10
@export var lose_cinematic_path: String = "res://Scenes/lose_cinematic.tscn"

var _template_virus: CanvasItem
var _dragged_virus: CanvasItem
var _virus_dragging := false
var _virus_drag_offset := Vector2.ZERO
var _was_left_pressed := false
var _mouse_jitter_timer := 0.0
var _unresolved_duplicate_timer := 0.0
var _virus_split_seq: int = 0
var _lose_cut_triggered: bool = false


func _ready() -> void:
	randomize()
	set_process(true)
	_cache_template_virus()
	_ensure_virus_pool()
	_hide_all_viruses()


func release_random_virus() -> bool:
	var hidden_candidates: Array[CanvasItem] = []
	for child in get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			if not item.visible:
				hidden_candidates.append(item)

	if hidden_candidates.is_empty():
		return false

	var spawned := hidden_candidates[randi() % hidden_candidates.size()]
	spawned.visible = true
	spawned.z_index = 2000 + _count_visible_viruses()
	_set_item_global_position(spawned, _random_spawn_position())

	if spawned.has_method("play"):
		spawned.call("play")

	if _count_visible_viruses() == 1:
		_play_virus_sound()
	_maybe_cut_to_lose()
	return true


func _process(_delta: float) -> void:
	var is_left_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mouse_pos := get_viewport().get_mouse_position()
	var visible_count := _count_visible_viruses()

	if visible_count == 0:
		_dragged_virus = null
		_virus_dragging = false
		_was_left_pressed = is_left_pressed
		_unresolved_duplicate_timer = 0.0
		return

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

	if enable_annoying_effects:
		_apply_annoying_effects(_delta, visible_count)

	_was_left_pressed = is_left_pressed
	_maybe_cut_to_lose()


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
	if item is AnimatedSprite2D:
		var center := (item as AnimatedSprite2D).global_position
		var radius := _get_sprite_hit_radius(item as AnimatedSprite2D)
		return center.distance_to(point) <= radius
	return _get_item_rect(item).has_point(point)


func _get_item_rect(item: CanvasItem) -> Rect2:
	if item is Control:
		return (item as Control).get_global_rect()

	var global_pos := _get_item_global_position(item)
	if item.has_method("get_rect"):
		var rect_variant: Variant = item.call("get_rect")
		if rect_variant is Rect2:
			var local_rect: Rect2 = rect_variant
			return Rect2(global_pos + local_rect.position, local_rect.size)

	return Rect2(global_pos - Vector2(32.0, 32.0), Vector2(64.0, 64.0))


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


func _get_sprite_hit_radius(sprite: AnimatedSprite2D) -> float:
	var radius := drag_hit_radius
	var frames := sprite.sprite_frames
	if frames != null:
		var anim := sprite.animation
		if anim.is_empty():
			anim = &"default"
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			var frame_texture := frames.get_frame_texture(anim, sprite.frame)
			if frame_texture != null:
				var frame_size := frame_texture.get_size() * sprite.global_scale.abs()
				radius = max(radius, max(frame_size.x, frame_size.y) * 0.5)
	return radius


func _cache_template_virus() -> void:
	for child in get_children():
		if child is CanvasItem and child is not AudioStreamPlayer and child is not AudioStreamPlayer2D:
			_template_virus = child as CanvasItem
			return


func _ensure_virus_pool() -> void:
	if _template_virus == null:
		return
	var current: int = _count_virus_items()
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


func _apply_annoying_effects(delta: float, visible_count: int) -> void:
	if not jitter_mouse or visible_count <= 0:
		return

	_mouse_jitter_timer -= delta
	if _mouse_jitter_timer > 0.0:
		return
	_mouse_jitter_timer = max(0.05, mouse_jitter_interval)

	var current: Vector2 = get_viewport().get_mouse_position()
	var offset: Vector2 = Vector2(
		randf_range(-mouse_jitter_pixels, mouse_jitter_pixels),
		randf_range(-mouse_jitter_pixels, mouse_jitter_pixels)
	) * clamp(float(visible_count), 1.0, 3.0)
	var target: Vector2 = current + offset
	var viewport_rect: Rect2 = get_viewport_rect()
	target.x = clamp(target.x, viewport_rect.position.x, viewport_rect.end.x)
	target.y = clamp(target.y, viewport_rect.position.y, viewport_rect.end.y)
	Input.warp_mouse(target)


func _is_virus_item(node: Node) -> bool:
	return node is CanvasItem and node is not AudioStreamPlayer and node is not AudioStreamPlayer2D


## Every interval: clone each visible virus once → count goes N → 2N.
func _double_visible_viruses() -> void:
	var sources: Array[CanvasItem] = []
	for child in get_children():
		if _is_virus_item(child) and (child as CanvasItem).visible:
			sources.append(child as CanvasItem)
	if sources.is_empty():
		return

	var base_z: int = 2000
	for child in get_children():
		if _is_virus_item(child):
			base_z = max(base_z, (child as CanvasItem).z_index)

	var i: int = 0
	for src in sources:
		var dup: CanvasItem = src.duplicate() as CanvasItem
		if dup == null:
			continue
		_virus_split_seq += 1
		dup.name = "%s_split_%d" % [src.name, _virus_split_seq]
		add_child(dup)
		dup.visible = true
		dup.z_index = base_z + 1 + i
		i += 1
		_set_item_global_position(dup, _random_spawn_position())
		if dup.has_method("play"):
			dup.call("play")
	_maybe_cut_to_lose()


func _maybe_cut_to_lose() -> void:
	if _lose_cut_triggered:
		return
	if _count_visible_viruses() < lose_virus_threshold:
		return
	if not ResourceLoader.exists(lose_cinematic_path):
		push_warning("viruses.gd: lose scene not found: %s" % lose_cinematic_path)
		return
	_lose_cut_triggered = true
	_stop_virus_sound()
	var transition := get_tree().root.get_node_or_null("TransitionFade")
	if transition and transition.has_method("fade_to_black_then_scene"):
		transition.call("fade_to_black_then_scene", lose_cinematic_path)
	else:
		get_tree().change_scene_to_file(lose_cinematic_path)

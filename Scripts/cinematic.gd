extends Node2D

const START_DELAY := 1.5
const FADE_DURATION := 1.5
const CURSOR_FADE_DURATION := 0.6
const BOOTUP_EARLY_OFFSET := 2.0
const BOOTUP_MAX_LENGTH := 10
const KEYBOARD_MAX_LENGTH := 3
const KEYBOARD_START_DELAY := 0.4

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var cinematic_sprite: AnimatedSprite2D = $AnimationPlayer/AnimatedSprite2D
@onready var cursor_sprite: TextureRect = $cursor
@onready var keyboard_sound: AudioStreamPlayer = $KeyboardSound
@onready var bootup_sound: AudioStreamPlayer = $BootupSound
@onready var bootup_audio_manager: Node = get_node_or_null("/root/BootupAudio")

func _ready() -> void:
	cinematic_sprite.modulate.a = 0.0
	cinematic_sprite.stop()

	if animation_player.has_animation("opening"):
		animation_player.play("opening")

	var bootup_start_time: float = max(START_DELAY - BOOTUP_EARLY_OFFSET, 0.0)
	if bootup_start_time > 0.0:
		await get_tree().create_timer(bootup_start_time).timeout

	if bootup_audio_manager != null:
		bootup_audio_manager.call("play_bootup", bootup_sound.stream, BOOTUP_MAX_LENGTH, bootup_sound.volume_db)
	else:
		bootup_sound.play()
		_schedule_sound_cutoff(bootup_sound, BOOTUP_MAX_LENGTH)

	var remaining_delay: float = START_DELAY - bootup_start_time
	if remaining_delay > 0.0:
		await get_tree().create_timer(remaining_delay).timeout

	if KEYBOARD_START_DELAY > 0.0:
		var keyboard_timer: SceneTreeTimer = get_tree().create_timer(KEYBOARD_START_DELAY)
		keyboard_timer.timeout.connect(_play_keyboard_sound, CONNECT_ONE_SHOT)
	else:
		_play_keyboard_sound()

	cinematic_sprite.play("default")

	var fade_tween: Tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(cinematic_sprite, "modulate:a", 1.0, FADE_DURATION)
	fade_tween.tween_property(cursor_sprite, "modulate:a", 0.0, CURSOR_FADE_DURATION)
	await fade_tween.finished

	await cinematic_sprite.animation_finished
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

func _schedule_sound_cutoff(player: AudioStreamPlayer, seconds: float) -> void:
	if seconds <= 0.0:
		return

	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	timer.timeout.connect(_stop_player_if_playing.bind(player), CONNECT_ONE_SHOT)

func _stop_player_if_playing(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player) and player.playing:
		player.stop()

func _play_keyboard_sound() -> void:
	keyboard_sound.play()
	_schedule_sound_cutoff(keyboard_sound, KEYBOARD_MAX_LENGTH)

extends Node

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func play_bootup(stream: AudioStream, max_length: float = -1.0, volume_db: float = 0.0) -> void:
	if stream == null:
		return

	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()

	if max_length > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(max_length)
		timer.timeout.connect(_stop_if_playing, CONNECT_ONE_SHOT)

func _stop_if_playing() -> void:
	if _player.playing:
		_player.stop()

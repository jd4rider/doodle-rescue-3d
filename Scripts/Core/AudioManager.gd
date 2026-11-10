extends Node
## Sound effects and two music beds, all synthesised into WAVs by
## Tools/audio.py. Browsers keep WebAudio suspended until a real gesture, so
## `kick()` is called on the first tap instead of in `_ready`.

const SFX_DIR := "res://Assets/Audio/SFX/"
const MUSIC_DIR := "res://Assets/Audio/Music/"
const SILENT_DB := -60.0

var music_volume := 0.4
var sfx_volume := 0.8

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _buzz: AudioStreamPlayer
var _mood := ""
var _kicked := false
var _buzz_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(12):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = SILENT_DB
	add_child(_music)
	_buzz = AudioStreamPlayer.new()
	_buzz.volume_db = SILENT_DB
	add_child(_buzz)
	apply_settings(Save.data.get("settings", {}))


func kick() -> void:
	_kicked = true
	if _mood != "":
		play_music(_mood)


func apply_settings(settings: Dictionary) -> void:
	music_volume = clampf(float(settings.get("music", 0.4)), 0.0, 1.0)
	sfx_volume = clampf(float(settings.get("sfx", 0.8)), 0.0, 1.0)
	if _music != null:
		_music.volume_db = linear_to_db(maxf(0.02, music_volume)) - 8.0 if _music.playing else SILENT_DB
	if _buzz != null and not _buzz.playing:
		_buzz.volume_db = SILENT_DB


func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	_cache[path] = stream
	return stream


func _looped(path: String) -> AudioStream:
	var stream := _stream(path)
	if stream is AudioStreamWAV:
		var copy := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		var bytes := 2 if copy.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels := 2 if copy.stereo else 1
		copy.loop_end = int(copy.data.size() / (bytes * channels))
		return copy
	return stream


func play_sfx(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if sfx_volume <= 0.001:
		return
	var stream := _stream(SFX_DIR + name + ".wav")
	if stream == null:
		return
	var target: AudioStreamPlayer = null
	for player in _players:
		if not player.playing:
			target = player
			break
	if target == null:
		target = _players[0]
	target.stream = stream
	target.pitch_scale = clampf(pitch, 0.6, 1.8)
	target.volume_db = volume_db + linear_to_db(maxf(0.05, sfx_volume))
	target.play()


func ui_click() -> void:
	play_sfx("ui_click", randf_range(0.97, 1.03), -8.0)


func ui_back() -> void:
	play_sfx("ui_back", randf_range(0.96, 1.02), -9.0)


func draw_start() -> void:
	play_sfx("draw", randf_range(0.85, 0.95), -6.0)


func draw_end() -> void:
	play_sfx("snap", randf_range(0.96, 1.06), -4.0)


func place() -> void:
	play_sfx("place", randf_range(0.96, 1.08), -3.0)


func star(index: int) -> void:
	play_sfx("star", 1.0 + index * 0.09, -4.0)


func win() -> void:
	play_sfx("win", 1.0, -3.0)


func fail() -> void:
	play_sfx("sad", 1.0, -4.0)


func hint() -> void:
	play_sfx("chime", 1.0, -5.0)


func unlock() -> void:
	play_sfx("unlock", 1.0, -4.0)


func thud() -> void:
	play_sfx("thud", randf_range(0.9, 1.1), -5.0)


func wood_hit() -> void:
	play_sfx("wood", randf_range(0.9, 1.1), -6.0)


func metal_hit() -> void:
	play_sfx("metal", randf_range(0.92, 1.08), -6.0)


func bee(amount: float) -> void:
	_buzz_target = clampf(amount, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _buzz == null:
		return
	if _buzz_target > 0.02 and sfx_volume > 0.001:
		if not _buzz.playing:
			_buzz.stream = _looped(SFX_DIR + "bees.wav")
			_buzz.play()
		var target_db := linear_to_db(maxf(0.02, sfx_volume * _buzz_target * 0.55)) - 8.0
		_buzz.volume_db = lerpf(_buzz.volume_db, target_db, 0.12)
	elif _buzz.playing:
		_buzz.volume_db = lerpf(_buzz.volume_db, SILENT_DB, 0.2)
		if _buzz.volume_db < -55.0:
			_buzz.stop()


func play_music(mood: String) -> void:
	_mood = mood
	var stream := _looped(MUSIC_DIR + mood + ".wav")
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = linear_to_db(maxf(0.02, music_volume)) - 8.0
	if _kicked:
		_music.play()


func stop_music() -> void:
	_mood = ""
	_music.stop()

extends Node
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var current_track: String = ""
var enabled: bool = true

func _ready() -> void:
	for bus in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -15)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effects"), -7)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	for _i in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Effects"
		add_child(player)
		voices.append(player)

func set_enabled(value: bool) -> void:
	enabled = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not value)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"), not value)

func track(name: String) -> void:
	if name == current_track: return
	current_track = name
	var stream: AudioStreamOggVorbis = load("res://assets/audio/%s.ogg" % name)
	stream.loop = true
	music.stream = stream
	music.play()

func cue(name: String) -> void:
	if not enabled or voices.is_empty(): return
	var player: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	player.stream = load("res://assets/audio/%s.wav" % name)
	player.play()

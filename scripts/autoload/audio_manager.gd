extends Node
## Synthesises every sound at boot so the project ships with zero audio files.
## SFX: cash register, door bell, fryer sizzle, steam, reactions, level-up.
## Music: a small lo-fi loop. Ambience: crowd murmur scaled by customer count.

const RATE := 16000

var _sfx: Dictionary = {}
var _players: Array = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sizzle: AudioStreamPlayer
var _ready_done := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1234
	_setup_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "SFX"
	_ambience.volume_db = -80.0
	add_child(_ambience)
	_sizzle = AudioStreamPlayer.new()
	_sizzle.bus = "SFX"
	_sizzle.volume_db = -80.0
	add_child(_sizzle)
	_build_sfx()
	_ready_done = true
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var m := AudioServer.get_bus_index("Music")
	var s := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(m, linear_to_db(maxf(float(Game.settings.get("music", 0.6)), 0.0001)))
	AudioServer.set_bus_volume_db(s, linear_to_db(maxf(float(Game.settings.get("sfx", 0.8)), 0.0001)))


func play(id: String, pitch_jitter: float = 0.05) -> void:
	if not _ready_done or not _sfx.has(id):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[id]
			p.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func start_music() -> void:
	if _music.stream == null:
		_music.stream = _build_music()
	if not _music.playing:
		_music.volume_db = -6.0
		_music.play()


func start_shift_ambience() -> void:
	if _ambience.stream == null:
		_ambience.stream = _noise_loop(4.0, 0.18, 2.5, 0.85)
	if _sizzle.stream == null:
		_sizzle.stream = _noise_loop(2.0, 0.22, 11.0, 0.35)
	_ambience.play()
	_sizzle.play()


func stop_shift_ambience() -> void:
	_ambience.stop()
	_sizzle.stop()


## Crowd volume follows the number of customers; sizzle follows active fryers.
func set_activity(customers: int, frying: int) -> void:
	var crowd := clampf(customers / 10.0, 0.0, 1.0)
	_ambience.volume_db = lerpf(-40.0, -14.0, crowd) if customers > 0 else -80.0
	_sizzle.volume_db = -16.0 if frying > 0 else -80.0


# --- Synthesis ---------------------------------------------------------------

func _build_sfx() -> void:
	_sfx["cash"] = _tones([[1318.5, 0.0, 0.25], [1760.0, 0.08, 0.35]], 0.45, 8.0)
	_sfx["bell"] = _tones([[987.8, 0.0, 0.6], [1480.0, 0.0, 0.3]], 0.7, 5.0)
	_sfx["happy"] = _tones([[660.0, 0.0, 0.1], [880.0, 0.07, 0.12], [1046.5, 0.14, 0.14]], 0.32, 14.0)
	_sfx["angry"] = _tones([[220.0, 0.0, 0.25], [164.8, 0.12, 0.3]], 0.42, 6.0, true)
	_sfx["levelup"] = _tones([[523.3, 0.0, 0.1], [659.3, 0.08, 0.1], [784.0, 0.16, 0.1], [1046.5, 0.24, 0.3]], 0.6, 6.0)
	_sfx["click"] = _tones([[1200.0, 0.0, 0.03]], 0.05, 60.0)
	_sfx["pop"] = _tones([[520.0, 0.0, 0.06], [780.0, 0.02, 0.05]], 0.1, 30.0)
	_sfx["steam"] = _noise_burst(0.5, 0.35, 0.6)
	_sfx["burn"] = _noise_burst(0.45, 0.6, 0.08)
	_sfx["mistake"] = _tones([[300.0, 0.0, 0.12], [250.0, 0.1, 0.18]], 0.3, 10.0, true)


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## notes: [[freq, start_s, length_s], ...] with exponential decay.
func _tones(notes: Array, total: float, decay: float, square: bool = false) -> AudioStreamWAV:
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	for note in notes:
		var f: float = note[0]
		var s0 := int(float(note[1]) * RATE)
		var len_s := int(float(note[2]) * RATE)
		for i in range(len_s):
			var idx := s0 + i
			if idx >= n:
				break
			var t := float(i) / RATE
			var env := exp(-t * decay) * minf(1.0, t * 400.0)
			var v := sin(TAU * f * t)
			if square:
				v = signf(v) * 0.5 + sin(TAU * f * 2.0 * t) * 0.2
			else:
				v += 0.25 * sin(TAU * f * 2.0 * t)
			buf[idx] += v * env * 0.35
	return _wav(buf)


func _noise_burst(total: float, vol: float, smooth: float) -> AudioStreamWAV:
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(PI * t) * (1.0 - t)
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), smooth)
		buf[i] = last * env * vol
	return _wav(buf)


## Looping noise with slow amplitude wobble (crowd murmur / fryer sizzle).
func _noise_loop(seconds: float, vol: float, wobble_hz: float, smooth: float) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / RATE
		var wob := 0.6 + 0.4 * sin(TAU * wobble_hz * t) * sin(TAU * wobble_hz * 0.37 * t + 1.3)
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), smooth)
		# Crackle for sizzle
		var crackle := 0.0
		if smooth < 0.5 and _rng.randf() < 0.002:
			crackle = _rng.randf_range(-0.8, 0.8)
		buf[i] = (last * wob + crackle) * vol
	# Crossfade loop seam
	var fade := mini(800, n / 4)
	for i in fade:
		var a := float(i) / fade
		buf[i] = buf[i] * a + buf[n - fade + i] * (1.0 - a)
	return _wav(buf, true)


## A gentle 4-bar lo-fi loop: pad chords + bass + pentatonic plucks.
func _build_music() -> AudioStreamWAV:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var chords := [[261.6, 329.6, 392.0], [220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7]]
	var bass := [65.4, 55.0, 87.3, 98.0]
	var penta := [523.3, 587.3, 659.3, 784.0, 880.0]
	var bars := 4
	var n := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	var mrng := RandomNumberGenerator.new()
	mrng.seed = 77
	for bar in bars:
		var start := int(bar * 4 * beat * RATE)
		var bar_len := int(4 * beat * RATE)
		# Pad
		for i in bar_len:
			var t := float(i) / RATE
			var env := minf(1.0, t * 3.0) * minf(1.0, (float(bar_len - i) / RATE) * 3.0)
			var v := 0.0
			for f in chords[bar]:
				v += sin(TAU * f * t) * 0.06 + sin(TAU * f * 1.003 * t) * 0.04
			v += sin(TAU * bass[bar] * t) * 0.16 * (0.6 + 0.4 * absf(sin(PI * t / beat)))
			buf[start + i] += v * env
		# Plucks on 8th notes, sparse
		for step in 8:
			if mrng.randf() < 0.55:
				var f: float = penta[mrng.randi() % penta.size()]
				var s0 := start + int(step * beat * 0.5 * RATE)
				var ln := int(beat * 0.9 * RATE)
				for i in ln:
					if s0 + i >= n:
						break
					var t := float(i) / RATE
					buf[s0 + i] += sin(TAU * f * t) * exp(-t * 7.0) * 0.09
	# Soft "vinyl" hiss
	for i in n:
		buf[i] = buf[i] * 0.9 + mrng.randf_range(-0.004, 0.004)
	return _wav(buf, true)

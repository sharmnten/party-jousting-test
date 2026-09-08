class_name GameFeedback
extends Node2D
class Spark:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var color := Color.WHITE
	var life: float = 0.5
var sparks: Array[Spark] = []
var muted: bool = false
var sounds: Array[AudioStreamPlayer] = []
var tones: Dictionary = {}
var voice: int = 0

func _exit_tree() -> void:
	for sound in sounds:
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
	tones.clear()

func _ready() -> void:
	for i in range(8):
		var sound := AudioStreamPlayer.new()
		sound.volume_db = -20
		add_child(sound)
		sounds.append(sound)
	for cue in ["flap", "hit", "coin", "power", "out", "go", "win"]:
		tones[cue] = _tone(cue)

func burst(location: Vector2, color: Color, amount: int = 12) -> void:
	for i in range(amount):
		var spark := Spark.new()
		spark.position = location
		spark.velocity = Vector2.from_angle(randf() * TAU) * randf_range(35, 180)
		spark.color = color
		spark.life = randf_range(0.25, 0.65)
		sparks.append(spark)

func play(cue: String) -> void:
	if muted or not tones.has(cue):
		return
	var sound := sounds[voice % sounds.size()]
	voice += 1
	sound.stream = tones[cue]
	sound.play()

func _process(delta: float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var spark := sparks[i]
		spark.life -= delta
		spark.velocity.y += 240 * delta
		spark.position += spark.velocity * delta
		if spark.life <= 0:
			sparks.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for spark in sparks:
		draw_circle(spark.position, maxf(1.0, spark.life * 6), Color(spark.color, minf(1, spark.life * 3)))

func _tone(cue: String) -> AudioStreamWAV:
	var frequency: float = 440
	var duration: float = 0.12
	match cue:
		"flap": frequency = 300
		"hit": frequency = 110
		"coin": frequency = 950
		"power": frequency = 660
		"out":
			frequency = 160
			duration = 0.3
		"go": frequency = 520
		"win":
			frequency = 780
			duration = 0.4
	var count := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0
	for i in range(count):
		var t := float(i) / count
		phase += TAU * frequency * (1.0 + t * (0.6 if cue != "out" else -0.7)) / 22050.0
		var envelope := minf(t * 30, 1) * pow(1.0 - t, 2)
		data.encode_s16(i * 2, int(sin(phase) * envelope * 18000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = data
	return wav

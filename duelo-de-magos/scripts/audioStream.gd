extends AudioStreamPlayer

var menuMusic = preload("res://assets/audio/aventura-en-la-playa-8-bit.mp3")
var gameMusic = preload("res://assets/audio/fiesta-playera-8-bit.mp3")

func _ready():
	bus = "Music"
	volume_db = -15

func play_menu():
	if stream == menuMusic and playing:
		return
	_fade_to(menuMusic)

func play_game():
	if stream == gameMusic and playing:
		return
	_fade_to(gameMusic)

func _fade_to(new_music: AudioStream):
	if playing:
		var tween_out = create_tween()
		tween_out.tween_property(self, "volume_db", -90, 1.0)
		await tween_out.finished
		stop()
	
	#pa cambiar musiquita
	stream = new_music
	volume_db = -90
	play()
	
	var tween_in = create_tween()
	tween_in.tween_property(self, "volume_db", 0, 1.5)

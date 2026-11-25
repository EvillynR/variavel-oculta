class_name StoryAudio
extends Node
## Versão 5.7 — sons da história (efeitos curtos e ambiente em laço).
## Os arquivos ficam em assets/audio/ (gerados por tools/gerar_sons.py) e são
## carregados pelo nome: play("erro"), play("notas/do"), ambient("musica_ambiente").
## Toca também com o jogo pausado (cenas de filme, painel do enigma).

const DIR := "res://assets/audio/%s.wav"

## Últimos sons tocados (para os testes automáticos conferirem).
var history: PackedStringArray = []
var ambient_name := ""

var _ambient: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Ambiente"
	_ambient.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambient)


func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := sound if sound.begins_with("res://") else DIR % sound
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("StoryAudio: som %s não encontrado." % path)
	_cache[sound] = s
	return s


## Efeito curto (um player por som, some sozinho quando acaba).
func play(sound: String, volume_db: float = 0.0) -> void:
	history.append(sound)
	var s := stream(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Som de fundo em laço ("" desliga). Chamadas repetidas com o mesmo nome não reiniciam.
func ambient(sound: String, volume_db: float = -10.0) -> void:
	if sound == ambient_name:
		return
	ambient_name = sound
	_ambient.stop()
	if sound == "":
		return
	var s := stream(sound)
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	if s == null:
		return
	_ambient.stream = s
	_ambient.volume_db = volume_db
	_ambient.play()

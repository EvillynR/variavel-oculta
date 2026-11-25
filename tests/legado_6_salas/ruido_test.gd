extends SceneTree
## Prompt 2 — ruído dos passos (player_noise no JSON → SoundStimulus → audição
## existente). Polvo real em PATROLLING; a protagonista fica FORA do cone de
## visão dele, para que só a audição conte.
## Uso: godot --headless --fixed-fps 60 --path . --script res://tests/ruido_test.gd

const T := preload("res://tests/test_input.gd")
const HOME := Vector3(-21.2, 0, -18.7)
var main: Node
var player: CharacterBody3D
var polvo: MonsterController
var reactions: Array = []
var emitted: Array = []
var passed := 0
var failed := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _phys(6)
	player = main.get_node("Player")
	polvo = main.get_node("Room1Gameplay/Polvo")
	for m in get_nodes_in_group("monster"):
		if m != polvo:
			m.process_mode = Node.PROCESS_MODE_DISABLED
	polvo.sound_perceived.connect(func(s, r): if s.source_id == &"protagonista": reactions.append(r))
	player.noise_emitted.connect(func(s): emitted.append(s))
	var cfg := GameData.get_instance().player_noise
	_check("JSON: player_noise com walk, run e crouch", cfg.has("walk") and cfg.has("run") and cfg.has("crouch")
		and cfg.run.loudness > cfg.walk.loudness and cfg.walk.loudness > cfg.crouch.loudness, str(cfg))
	polvo.activate(&"teste_ruido", polvo.global_position, true)
	await _phys(2)

	print("--- mesma distância (3,6 a 5,9 m), fora da visão")
	var far_a := Vector3(-22.0, 0.05, -22.3)
	await _segment("crouch", far_a, 90)
	_check("agachada: passos emitidos (som mínimo)", emitted.size() >= 1 and emitted.all(func(s): return absf(s.loudness - cfg.crouch.loudness) < 0.001), "%d passos" % emitted.size())
	_check("agachada: o Polvo NÃO investiga", not reactions.has(SoundStimulus.Reaction.INVESTIGATE) and polvo.state == MonsterController.State.PATROLLING, "%s / %s" % [_names(reactions), polvo.get_state_name()])
	await _segment("walk", far_a, 50)
	_check("andando na mesma distância: som médio ainda não basta", emitted.size() >= 1 and not reactions.has(SoundStimulus.Reaction.INVESTIGATE), _names(reactions))
	await _segment("run", far_a, 40)
	_check("correndo: passos altos (passos_corrida)", emitted.any(func(s): return s.kind == SoundStimulus.KIND_RUN and absf(s.loudness - cfg.run.loudness) < 0.001), "")
	_check("correndo na mesma distância: o Polvo INVESTIGA", reactions.has(SoundStimulus.Reaction.INVESTIGATE) and polvo.state == MonsterController.State.INVESTIGATING, "%s / %s" % [_names(reactions), polvo.get_state_name()])
	_check("investiga o local do som, não persegue (não a viu)", polvo.state != MonsterController.State.CHASING, polvo.get_state_name())

	print("--- andando perto (~2 m), fora da visão")
	await _segment("walk", Vector3(-22.6, 0.05, -19.6), 45)
	_check("andando perto: o Polvo investiga", reactions.has(SoundStimulus.Reaction.INVESTIGATE), _names(reactions))
	await _segment("idle", Vector3(-22.6, 0.05, -19.9), 60)
	_check("parada não faz barulho", emitted.is_empty(), "%d passos" % emitted.size())
	print("RESULTADO: %d/%d testes passaram" % [passed, passed + failed])
	quit(1 if failed > 0 else 0)


## Reposiciona o Polvo em vigia e anda n quadros (−Z) no modo pedido.
func _segment(mode: String, start: Vector3, frames: int) -> void:
	T.release_moves()
	for a in ["run", "crouch"]:
		Input.action_release(a)
	polvo.global_position = HOME
	polvo.rotation.y = atan2(-1.0, 0.0)   # olha para +X
	polvo._last_heard_id = 0
	polvo._change_state(MonsterController.State.PATROLLING)
	player.global_position = start
	player.velocity = Vector3.ZERO
	await _phys(20)
	reactions.clear()
	emitted.clear()
	if mode == "run":
		Input.action_press("run")
	elif mode == "crouch":
		Input.action_press("crouch")
	for i in frames:
		if mode != "idle":
			T.press_world(player, Vector3(0, 0, -1))
		await physics_frame
		# Depois de ouvir, ele se vira para o som e pode vê-la — isso é esperado.
		if polvo.perception.can_see(player) and not reactions.has(SoundStimulus.Reaction.INVESTIGATE):
			_check("protagonista fora da visão do Polvo durante o teste", false, mode)
			break
	T.release_moves()
	Input.action_release("run")
	Input.action_release("crouch")
	await _phys(3)


func _names(list: Array) -> String:
	return str(list.map(func(r): return SoundStimulus.reaction_name(r)))


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, info: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("%s %s  %s" % ["OK    " if ok else "FALHA ", label, info])

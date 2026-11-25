class_name SoundStimulusSource
extends Node3D
## Fonte reutilizável de estímulos sonoros (Etapa 5, Fase 3).
## Coloque como filho de qualquer coisa que faça barulho (porta, objeto que
## cai, mecanismo, a protagonista correndo) e chame emit_stimulus() no momento
## da ação. A fonte não conhece os monstros: entrega o estímulo ao grupo
## SoundStimulus.LISTENER_GROUP, e cada monstro decide pela própria audição.
##
## Não toca áudio. Um som provisório/definitivo pode ser ligado depois ao
## sinal stimulus_emitted (ex.: um AudioStreamPlayer3D irmão), sem que a
## lógica dependa dele.
##
## Pontos de integração preparados (ainda NÃO ligados — ver docs/relatorios/ETAPA_5_ALTERACOES.md):
## - corrida da protagonista: filho do Player, kind = passos_corrida,
##   chamado pelo script da protagonista enquanto corre (min_interval limita);
## - objetos derrubados / portas / mecanismos: filho do objeto, chamado pelo
##   script da ação (ex.: Interactable ou PuzzleManager) quando ela existir.

signal stimulus_emitted(stimulus: SoundStimulus)

@export var source_id: StringName = &""
## Tipo do som (ver constantes KIND_* em SoundStimulus; aceita tipos novos).
@export var kind: StringName = SoundStimulus.KIND_GENERIC
## 1 = intensidade de referência. 0,5 = metade do alcance; 2 = o dobro.
@export_range(0.0, 5.0, 0.05) var loudness: float = 1.0
## Intervalo mínimo (s) entre emissões. Impede que ações contínuas (correr)
## virem um rastreador da posição da protagonista a cada quadro.
@export var min_interval: float = 0.5
@export var enabled: bool = true
## Corpo físico da própria fonte (ex.: a porta), ignorado no teste de parede.
@export var source_body: CollisionObject3D

var _last_emit_msec: int = -1000000
var emitted_count: int = 0


## Emite um estímulo na posição atual da fonte. Retorna o estímulo emitido,
## ou null se desativada ou ainda no intervalo mínimo.
## loudness_scale multiplica a intensidade configurada (ex.: queda mais alta).
func emit_stimulus(loudness_scale: float = 1.0) -> SoundStimulus:
	if not enabled or not is_inside_tree():
		return null
	var now := Time.get_ticks_msec()
	if now - _last_emit_msec < int(min_interval * 1000.0):
		return null
	_last_emit_msec = now
	var id := source_id if source_id != &"" else StringName(String(get_path()))
	var stimulus := SoundStimulus.new(global_position, loudness * loudness_scale, kind, id)
	stimulus.source_body = source_body
	emitted_count += 1
	stimulus_emitted.emit(stimulus)
	SoundStimulus.broadcast(get_tree(), stimulus)
	return stimulus


## Libera a próxima emissão imediatamente (ex.: ao reiniciar uma sala).
func reset_interval() -> void:
	_last_emit_msec = -1000000

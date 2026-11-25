class_name SoundStimulus
extends RefCounted
## Um estímulo sonoro lógico (Etapa 5, Fase 3). Não depende de áudio: é só
## o registro de que "algo fez barulho aqui". Criado por SoundStimulusSource
## (ou por SoundStimulus.scripted para ordens diretas de roteiro/teste) e
## entregue aos ouvintes do grupo LISTENER_GROUP.

## Grupo dos nós que recebem estímulos (MonsterController entra nele).
## Um ouvinte implementa receive_sound_stimulus(stimulus: SoundStimulus) -> int.
const LISTENER_GROUP := &"sound_listener"

## Tipos conhecidos. Os perfis de audição podem ignorar ou pesar cada tipo.
## Novos tipos podem ser criados livremente (são StringName).
const KIND_GENERIC := &"generico"
const KIND_RUN := &"passos_corrida"          # ponto de integração: corrida da protagonista
const KIND_OBJECT_DROP := &"objeto_derrubado" # ponto de integração: objetos que caem
const KIND_DOOR := &"porta"                   # ponto de integração: portas
const KIND_MECHANISM := &"mecanismo"          # ponto de integração: mecanismos/enigmas
const KIND_SCRIPTED := &"roteiro"             # ordem direta (hear_stimulus(position))

## Resultado da avaliação de um estímulo por um monstro.
enum Reaction {
	INVESTIGATE,      ## mudou/atualizou a investigação
	OUT_OF_RANGE,     ## longe demais para esta audição
	BELOW_THRESHOLD,  ## ouvido, mas fraco demais para justificar investigação
	IGNORED_KIND,     ## tipo de som que este monstro ignora
	IGNORED_STATE,    ## estado atual não reage a sons (ex.: INACTIVE, CHASING)
	DUPLICATE,        ## o mesmo estímulo (mesmo id) já foi processado
	MERGED,           ## mesmo local de uma investigação em curso/recente
	DEAF,             ## sensibilidade 0: só ordens diretas de roteiro
}

static var _next_id: int = 1

var id: int
var position: Vector3
## 1 = intensidade de referência (ouvido a hearing_radius com sensibilidade 1).
var loudness: float = 1.0
var kind: StringName = KIND_GENERIC
## Identificador legível da fonte (ex.: &"room_1.armario"); só diagnóstico.
var source_id: StringName = &""
## Corpo físico da fonte, ignorado no teste de obstrução (pode ser null).
var source_body: CollisionObject3D
## Ordem direta: ignora alcance/limiar (comportamento antigo de hear_stimulus).
var scripted: bool = false
var emitted_msec: int


func _init(at: Vector3 = Vector3.ZERO, intensity: float = 1.0, sound_kind: StringName = KIND_GENERIC, from_id: StringName = &"") -> void:
	id = _next_id
	_next_id += 1
	position = at
	loudness = maxf(intensity, 0.0)
	kind = sound_kind
	source_id = from_id
	emitted_msec = Time.get_ticks_msec()


## Estímulo de roteiro/teste: o monstro investiga sem conferir alcance.
static func scripted_at(at: Vector3, from_id: StringName = &"roteiro") -> SoundStimulus:
	var s := SoundStimulus.new(at, 1.0, KIND_SCRIPTED, from_id)
	s.scripted = true
	return s


## Entrega o estímulo a todos os ouvintes da árvore. Quem emite não precisa
## conhecer os monstros. Retorna quantos ouvintes decidiram investigar.
static func broadcast(tree: SceneTree, stimulus: SoundStimulus) -> int:
	if tree == null or stimulus == null:
		return 0
	var investigating := 0
	for listener in tree.get_nodes_in_group(LISTENER_GROUP):
		if listener.has_method("receive_sound_stimulus"):
			if listener.receive_sound_stimulus(stimulus) == Reaction.INVESTIGATE:
				investigating += 1
	return investigating


static func reaction_name(reaction: int) -> String:
	return Reaction.keys()[reaction]

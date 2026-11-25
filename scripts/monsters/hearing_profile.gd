class_name HearingProfile
extends Resource
## Parâmetros de audição de uma criatura (Etapa 5, Fase 3).
## Cada MonsterConfig aponta para o seu (campo hearing_profile). Perfis
## genéricos reutilizáveis ficam em data/monsters/hearing/.
##
## Como um som é avaliado (MonsterPerception.evaluate_sound):
##   intensidade efetiva = loudness × peso do tipo × (obstrução, se houver parede)
##   alcance             = hearing_radius × intensidade efetiva × sensitivity
##   distância > alcance                        -> OUT_OF_RANGE (nada acontece)
##   nível = 1 − distância / alcance  (0..1)
##   nível < investigate_threshold              -> BELOW_THRESHOLD (irrelevante)
##   senão                                      -> pode investigar

## 0 = surdo a fontes de som (só ordens diretas de roteiro). 1 = normal.
@export_range(0.0, 3.0, 0.05) var sensitivity: float = 1.0
## Distância (m) em que um som de intensidade 1 é ouvido com sensibilidade 1.
@export var hearing_radius: float = 8.0
## Nível mínimo (0..1) para o som justificar investigação. 0 = qualquer som
## ouvido; 0,5 = só sons na metade mais próxima do alcance.
@export_range(0.0, 1.0, 0.01) var investigate_threshold: float = 0.25
## Multiplicador da intensidade quando há parede entre o som e o monstro.
## 1 = paredes não abafam; 0 = paredes bloqueiam totalmente.
@export_range(0.0, 1.0, 0.05) var wall_occlusion: float = 0.5

@export_group("Resposta por tipo de som")
## Tipos ignorados por completo (ex.: [&"passos_corrida"]).
@export var ignored_kinds: Array[StringName] = []
## Peso por tipo: {&"porta": 1.5}. Tipo ausente = 1.
@export var kind_weights: Dictionary = {}

@export_group("Estados")
## Estados em que um som pode levar à investigação (nomes de
## MonsterController.State). O padrão reproduz o hear_stimulus anterior.
## INACTIVE/AWAKENING nunca reagem: o despertar é dos gatilhos.
@export var reactive_states: PackedStringArray = ["PATROLLING", "RETURNING", "SEARCHING", "INVESTIGATING"]

@export_group("Duplicatas")
## Sons a menos disto (m) do ponto que está sendo (ou acabou de ser)
## investigado são tratados como o mesmo estímulo.
@export var merge_radius: float = 1.5
## Por quanto tempo (s) um ponto recém-investigado ainda absorve sons repetidos.
@export var merge_time: float = 4.0

@export_multiline var notes: String = ""


func weight_for(kind: StringName) -> float:
	return float(kind_weights.get(kind, 1.0))


func reacts_in(state_name: String) -> bool:
	return state_name in reactive_states

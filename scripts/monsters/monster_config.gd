class_name MonsterConfig
extends Resource
## Parâmetros de comportamento de uma criatura. Cada monstro tem o seu .tres;
## a lógica (monster_controller.gd) é compartilhada.

@export var monster_id: StringName
@export var display_name: String = ""

@export_group("Velocidades (m/s)")
@export var patrol_speed: float = 1.4
@export var investigate_speed: float = 1.8
@export var search_speed: float = 2.0
@export var chase_speed: float = 3.6
@export var acceleration: float = 8.0
## Graus por segundo ao virar o corpo.
@export var turn_speed_degrees: float = 220.0

@export_group("Visão")
@export var sight_distance: float = 12.0
@export_range(10.0, 360.0) var sight_fov_degrees: float = 110.0
@export var eye_height: float = 2.8
## Tempo vendo a protagonista até reagir.
@export var reaction_time: float = 0.35
## Tempo sem ver a protagonista até desistir da perseguição e procurar.
@export var lose_sight_time: float = 1.5

@export_group("Tempos dos estados")
## Sem animação disponível, o despertar é uma pausa com sinal emitido.
@export var awakening_duration: float = 1.5
@export var investigate_look_time: float = 2.5
@export var search_duration: float = 8.0
@export var search_radius: float = 4.0
@export var search_point_wait: float = 1.0
@export var search_points: int = 3

@export_group("Perseguição")
@export var catch_distance: float = 1.3
## 0..1, repassado à câmera (set_tension) durante a perseguição.
@export var chase_camera_tension: float = 1.0

@export_group("Navegação")
## Fase 4: camadas de navegação usadas pelo monstro (rotas e pontos mais
## próximos). Cada sala física tem a sua; padrão 1 = Room 1 (Polvo igual).
@export_flags_3d_navigation var navigation_layers: int = 1
## Sem avançar este tanto (m) durante stuck_timeout, considera preso.
@export var stuck_min_progress: float = 0.2
@export var stuck_timeout: float = 1.5
## Distância mínima de mudança do alvo para recalcular a rota.
@export var repath_distance: float = 0.4

# ======================================================================
# Etapa 5 — campos novos. Os valores padrão reproduzem exatamente o
# comportamento anterior (o Polvo continua igual sem editar o .tres).
# Os sistemas que leem estes campos chegam nas Fases 2 e 3.
# ======================================================================

@export_group("Sala e narrativa")
## Sala (RoomData.id) a que a criatura pertence.
@export var room_id: StringName
## Estados que a criatura pode usar (nomes de MonsterController.State).
## Vazio = todos (comportamento atual).
@export var allowed_states: PackedStringArray = []
## Evento narrativo por estado: {"AWAKENING": &"evento_id", ...}.
## Lido pelo NarrativeManager (Fase 2); não altera o comportamento.
@export var state_events: Dictionary = {}

@export_group("Audição")
## Fase 3: perfil completo de audição (alcance, sensibilidade, limiar,
## paredes, tipos, duplicatas). Quando atribuído, substitui os dois campos
## abaixo. Vazio = usa noise_sensitivity/hearing_radius (compatibilidade).
@export var hearing_profile: HearingProfile
## Compatibilidade (Fase 1): usado só sem hearing_profile.
## 0 = não reage a fontes de som (o hear_stimulus(position) de roteiro
## continua funcionando). 1 = sensibilidade normal; >1 = mais sensível.
@export_range(0.0, 3.0, 0.05) var noise_sensitivity: float = 0.0
## Compatibilidade (Fase 1): usado só sem hearing_profile.
@export var hearing_radius: float = 8.0

@export_group("Retorno")
## true = depois de investigar/procurar volta ao posto (comportamento atual).
@export var return_to_home: bool = true
## Distância máxima do posto antes de desistir e voltar. 0 = sem limite.
@export var leash_radius: float = 0.0

@export_group("Recursos visuais e sonoros")
## Cena do modelo definitivo, instanciada no encaixe visual (Fase 3).
## Vazio = mantém o placeholder atual.
@export var visual_scene: PackedScene
## Deslocamento do modelo em relação ao corpo.
@export var visual_offset: Vector3 = Vector3.ZERO
## Estado -> nome da animação no AnimationPlayer do modelo.
## Ex.: {"PATROLLING": "walk", "CHASING": "run"}. Animação ausente é ignorada.
@export var animation_map: Dictionary = {}
## Evento -> AudioStream (ex.: {"awakening": preload(...)}). Som ausente é ignorado.
@export var sound_bank: Dictionary = {}
## Como o placeholder atual é exibido e o que deve substituí-lo.
@export_multiline var placeholder_notes: String = ""


var _legacy_hearing: HearingProfile


## Perfil de audição efetivo: o atribuído, ou um montado a partir dos
## campos antigos (noise_sensitivity/hearing_radius), sem alterar o .tres.
func get_hearing() -> HearingProfile:
	if hearing_profile != null:
		return hearing_profile
	if _legacy_hearing == null:
		_legacy_hearing = HearingProfile.new()
	_legacy_hearing.sensitivity = noise_sensitivity
	_legacy_hearing.hearing_radius = hearing_radius
	return _legacy_hearing

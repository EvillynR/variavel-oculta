class_name NarrativeEvent
extends Resource
## Um evento narrativo (Etapa 5, Fase 1): mensagem telefônica, diálogo,
## documento, registro de pesquisa, bilhete, informação ambiental, despertar
## de criatura, descoberta ou revelação.
## Só dados. Quem decide quando disparar é o NarrativeManager (Fase 2), que
## avalia gatilho + condições; quem exibe é uma interface futura que escuta
## o sinal do NarrativeManager.

enum EventType {
	PHONE_CALL,
	DIALOGUE,
	DOCUMENT,
	RESEARCH_LOG,
	NOTE,
	ENVIRONMENT,
	CREATURE_AWAKENING,
	DISCOVERY,
	REVELATION,
	CUTSCENE,      ## cena de filme (roteiro em data/story.json, exibida pelo StoryDirector)
}

## Três níveis da progressão narrativa.
enum Tier { INITIAL = 1, INTERMEDIATE = 2, FINAL = 3 }

## O que faz o NarrativeManager avaliar o evento.
enum TriggerType {
	MANUAL,           ## só por chamada explícita (ex.: sequência da Etapa 7)
	INTERACTION,      ## trigger_id = id de Interactable
	CLUE_DISCOVERED,  ## trigger_id = id de ClueData
	PUZZLE_SOLVED,    ## trigger_id = id de PuzzleData
	ROOM_ENTERED,     ## trigger_id = id de RoomData
	ROOM_COMPLETED,   ## trigger_id = id de RoomData
	MONSTER_STATE,    ## trigger_id = monster_id; trigger_state = nome do estado
	EVENT_FINISHED,   ## trigger_id = id de outro NarrativeEvent
}

const CONTENT_TEST := 0
const CONTENT_PROVISIONAL := 1
const CONTENT_FINAL := 2

@export var id: StringName
@export var type: EventType = EventType.NOTE
@export var tier: Tier = Tier.INITIAL
## Sala/local a que o evento pertence (vazio = global).
@export var room_id: StringName
## RoomData.ContentStatus (0 teste, 1 provisório, 2 final).
@export_range(0, 2) var content_status: int = CONTENT_PROVISIONAL

@export_group("Texto")
@export var speaker: String = ""
@export var title: String = ""
@export_multiline var lines: PackedStringArray = []
## Prompt 3: objetivo exibido na HUD quando o evento dispara (vazio = mantém).
@export var objective: String = ""
## Prompt 3 (PHONE_CALL): "chamada" (tela de chamada + legendas) ou "alerta" (aviso curto).
@export var phone_kind: StringName = &"chamada"

@export_group("Execução")
## Desligado = nunca dispara (nem manualmente) até ser habilitado.
@export var enabled: bool = true
## Obrigatório quando enabled = false (ex.: "Sequência de despertar — Etapa 7").
@export var disabled_reason: String = ""
@export var trigger: TriggerType = TriggerType.MANUAL
@export var trigger_id: StringName
## Para MONSTER_STATE: nome do estado (ex.: "AWAKENING", "CHASING").
@export var trigger_state: StringName
## true = dispara uma única vez (padrão; obrigatório para revelações).
@export var once: bool = true
## Maior primeiro quando vários eventos ficam prontos no mesmo instante.
@export var priority: int = 0

@export_group("Condições (todas precisam ser verdadeiras)")
@export var required_interactions: Array[StringName] = []
@export var required_clues: Array[StringName] = []
@export var required_puzzles_solved: Array[StringName] = []
@export var required_rooms_completed: Array[StringName] = []
@export var required_events: Array[StringName] = []
## O evento não dispara se algum destes já tiver disparado.
@export var blocked_by_events: Array[StringName] = []

@export_group("Segredos")
## Etiquetas do que o evento revela (ex.: &"origem_criaturas", &"vigilancia").
@export var reveals: Array[StringName] = []


## Pode ser disparado automaticamente por gatilho de jogo?
func can_auto_trigger() -> bool:
	return enabled and trigger != TriggerType.MANUAL


func has_conditions() -> bool:
	return not (required_interactions.is_empty() and required_clues.is_empty()
		and required_puzzles_solved.is_empty() and required_rooms_completed.is_empty()
		and required_events.is_empty())

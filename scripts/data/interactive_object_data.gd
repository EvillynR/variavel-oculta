class_name InteractiveObjectData
extends Resource
## Definição de um objeto interativo (Prompt 2), carregada de data/game_data.json.
## O nó Interactable da cena é ligado a esta definição pelo interaction_id e
## recebe dela ação, texto, uso único, prioridade e condições. Os efeitos são
## executados pelos sistemas que já existem (nenhum controlador paralelo):
##   reveal_clue      -> ClueManager.discover_from_object (via ClueData.source_object_id)
##   activate_monster -> MonsterTrigger do monstro da sala (via RoomData.activation_interaction_ids)
##   unlock_door      -> Door.unlock() da porta {"door_id": ...} (Prompt 1)
##   music_sequence   -> StoryDirector: o professor toca a melodia da sala
##                       {"room_id": ...} e depois acorda (versão 5.7, Música)
##   (sempre)         -> PuzzleManager.register_interaction, que alimenta enigmas,
##                       gatilhos e o NarrativeManager.

## FUNCTIONAL: existe na cena (scene_node) e funciona.
## PLANNED: só reservado nos dados; não existe na cena e não pode ter efeitos.
## TEST_ONLY: usado apenas pelos testes automatizados; não existe na cena.
enum Implementation { FUNCTIONAL, PLANNED, TEST_ONLY }

const EFFECT_TYPES := ["reveal_clue", "activate_monster", "unlock_door", "open_puzzle", "music_sequence"]
## Modos de tranca aceitos no campo "door" (portas físicas, scripts/world/door.gd).
const DOOR_LOCKS := ["none", "room_available", "manual"]

@export var id: StringName
@export var room_id: StringName
@export var implementation: Implementation = Implementation.PLANNED
## Caminho do nó Interactable a partir da cena principal (só FUNCTIONAL).
@export var scene_node: NodePath
@export var action_id: StringName = &"examinar"
@export var prompt_text: String = "E"
@export var one_shot: bool = false
@export var enabled: bool = true
@export var selection_priority: int = 0

@export_group("Condições (todas precisam ser verdadeiras para interagir)")
@export var required_interactions: Array[StringName] = []
@export var required_clues: Array[StringName] = []
@export var required_puzzles_solved: Array[StringName] = []
@export var required_rooms_completed: Array[StringName] = []

@export_group("Efeitos e narrativa")
## [{"type": "reveal_clue", "clue_id": ...}, {"type": "activate_monster", "monster_id": ...}]
@export var effects: Array[Dictionary] = []
## Derivado pelo carregador: eventos narrativos disparados por este objeto
## (gatilho INTERACTION) ou que exigem a interação com ele.
@export var narrative_event_ids: Array[StringName] = []
@export_multiline var notes: String = ""

@export_group("Porta (Prompt 1)")
## Só para objetos que são portas físicas (Door). Vazio = não é porta.
## {"lock": "none" | "room_available" | "manual", "room_id": "room_x",
##  "allow_if_previous_pending": bool, "start_open": bool}
@export var door: Dictionary = {}


func is_door() -> bool:
	return not door.is_empty()


func has_conditions() -> bool:
	return not (required_interactions.is_empty() and required_clues.is_empty()
		and required_puzzles_solved.is_empty() and required_rooms_completed.is_empty())


func is_functional() -> bool:
	return implementation == Implementation.FUNCTIONAL

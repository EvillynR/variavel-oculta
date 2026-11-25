class_name RoomData
extends Resource
## Dados de uma sala (ou de um local narrativo) — Etapa 5, Fase 1.
## Só dados: o estado em jogo fica no RoomProgressManager (Fase 2).
## Enigmas, pistas e monstros são referenciados por id; a validação
## cruzada fica em NarrativeDatabase.validate().

## CLASSROOM: uma das seis salas com matéria, enigma e criatura.
## STORY_AREA: local narrativo sem enigma escolar (monitoramento, subsolo).
enum Kind { CLASSROOM, STORY_AREA }

## PHYSICAL: existe geometria e um nó âncora na cena.
## INTEGRATION_POINT: ainda não há geometria; só o ponto de integração.
enum GeometryStatus { PHYSICAL, INTEGRATION_POINT }

## TEST: usa questões de teste. PROVISIONAL: conteúdo provisório.
## FINAL: conteúdo definitivo — não pode apontar para enigmas de teste.
## PENDING (Fase 4): sala preparada, mas ainda sem enigma/gatilho reais; pode
## ficar sem enigma, porém nunca é resolvida e precisa listar pending_items.
## (Novo valor no fim: os .tres existentes mantêm o mesmo número.)
enum ContentStatus { TEST, PROVISIONAL, FINAL, PENDING }

## Estados de progressão usados em jogo (Fase 2). Ficam aqui para que
## dados e sistemas compartilhem a mesma definição.
enum RoomState { LOCKED, AVAILABLE, ACTIVE, MONSTER_AWAKE, SOLVED, COMPLETED }

@export var id: StringName
@export var kind: Kind = Kind.CLASSROOM
## Ordem no percurso (1..6 para as salas).
@export var order: int = 0
@export var subject: String = ""
@export var display_name: String = ""
@export var content_status: ContentStatus = ContentStatus.TEST

@export_group("Cena")
@export var geometry_status: GeometryStatus = GeometryStatus.PHYSICAL
## Caminho do nó da sala a partir da cena principal (ex.: "School/Room 1").
## Vazio quando geometry_status = INTEGRATION_POINT.
@export var scene_anchor: NodePath
## O nome técnico do nó não corresponde ao papel narrativo (ex.: "Exit").
@export var technical_name_provisional: bool = false
@export_multiline var technical_notes: String = ""

@export_group("Jogabilidade")
@export var puzzle_ids: Array[StringName] = []
@export var clue_ids: Array[StringName] = []
## Ids de Interactable que pertencem a esta sala.
@export var interaction_ids: Array[StringName] = []
## Gatilhos de ativação do monstro (espelham o MonsterTrigger da cena).
@export var activation_interaction_ids: Array[StringName] = []
@export var activation_puzzle_ids: Array[StringName] = []
## Versão 5.7: objetos que acordam o professor pelo roteiro (StoryDirector),
## ex.: o piano da Música (ele toca a melodia e depois acorda).
@export var activation_story_ids: Array[StringName] = []
@export var monster_id: StringName

@export_group("Conclusão")
## Enigmas que precisam estar resolvidos. Vazio = todos de puzzle_ids.
@export var required_puzzle_ids: Array[StringName] = []
## Saída liberada pelos enigmas (PuzzleData.unlocks_exit).
@export var exit_id: StringName
## Evento narrativo disparado quando a sala é concluída.
@export var exit_event_id: StringName

@export_group("Narrativa")
## 1 = inicial, 2 = intermediário, 3 = final (NarrativeEvent.Tier).
@export_range(1, 3) var narrative_tier: int = 1
@export var narrative_event_ids: Array[StringName] = []

# ======================================================================
# Etapa 5, Fase 4 — campos novos, com padrões neutros.
# ======================================================================

@export_group("Identidade")
## Identidade temática da sala (o que a matéria vira dentro do terror).
@export_multiline var theme: String = ""

@export_group("Entrada e conexões")
## Salas que precisam estar concluídas, além da anterior na ordem.
@export var entry_required_rooms: Array[StringName] = []
## Áreas da cena que realmente se ligam à sala (ex.: "School/Corridor").
## Só para salas físicas; validado contra a cena pelos testes.
@export var connected_area_paths: Array[NodePath] = []
@export_multiline var connection_notes: String = ""

@export_group("Pontos de integração")
## Ids reservados para objetos/mecanismos previstos que ainda não existem
## como Interactable (formato "room_x.nome"). Não valem como gatilho.
@export var planned_interaction_ids: Array[StringName] = []
## O que falta para a sala ficar jogável (cenário, enigma, modelo...).
@export var pending_items: PackedStringArray = []

@export_group("Navegação")
## Camada de navegação (1..32) da região desta sala; 0 = sem navegação
## (obrigatório em pontos de integração). Monstros da sala usam esta camada.
@export_range(0, 32) var navigation_layer: int = 0
## Navmesh assado da sala (data/navigation/). Vazio = sem navegação.
@export var navigation_mesh: NavigationMesh
## Nó NavigationRegion3D da cena principal que usa o navmesh.
@export var navigation_region_path: NodePath


func get_required_puzzles() -> Array[StringName]:
	return required_puzzle_ids if not required_puzzle_ids.is_empty() else puzzle_ids


func is_classroom() -> bool:
	return kind == Kind.CLASSROOM


func is_pending() -> bool:
	return content_status == ContentStatus.PENDING


## Bit da camada de navegação (0 se a sala não tem navegação).
func navigation_layer_bit() -> int:
	return 1 << (navigation_layer - 1) if navigation_layer > 0 else 0

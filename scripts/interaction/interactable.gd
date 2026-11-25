class_name Interactable
extends Area3D
## Objeto com o qual a protagonista pode interagir por proximidade + ação
## "interact" (tecla E). Estar dentro da área NÃO conta como interação:
## a interação só acontece quando o PlayerInteractor chama interact().

signal interacted(interactable: Interactable, actor: Node3D)

## Id único e estável (ex.: &"room_1.experimento"). É o id que chega ao
## sistema de enigmas e aos gatilhos de monstros.
@export var interaction_id: StringName
## Ação realizada (ex.: &"examinar", &"manipular", &"ler").
@export var action_id: StringName = &"examinar"
@export var prompt_text: String = "E"
@export var enabled: bool = true
## true = só pode ser usado uma vez (ex.: alavanca). Documentos podem
## ser relidos; o sistema de enigmas já ignora interações repetidas.
@export var one_shot: bool = false
## Prioridade quando vários objetos estão ao alcance.
@export var selection_priority: int = 0
@export var show_prompt: bool = true
@export var prompt_height: float = 1.2

var _used := false
var _prompt: Label3D
## Corpos ignorados na checagem de linha de visada do PlayerInteractor (ex.: as
## folhas da própria porta, que ficam entre a protagonista e o centro do vão).
var line_of_sight_exclude: Array[RID] = []
## Prompt 2: definição carregada de data/game_data.json ("objects").
var definition: InteractiveObjectData


func _ready() -> void:
	add_to_group("interactable")
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if interaction_id == &"":
		push_error("%s: interaction_id vazio." % get_path())
	else:
		_apply_definition()

	if one_shot:
		_restore_used_state.call_deferred()

	if show_prompt:
		_prompt = Label3D.new()
		_prompt.text = prompt_text
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.no_depth_test = true
		_prompt.font_size = 30
		_prompt.position = Vector3(0, prompt_height, 0)
		_prompt.visible = false
		add_child(_prompt)


func can_interact() -> bool:
	return enabled and not (one_shot and _used) and conditions_met()


## Condições do objeto no JSON (todas precisam ser verdadeiras). Objeto sem
## condições: sempre true (comportamento anterior).
func conditions_met() -> bool:
	if definition == null or not definition.has_conditions():
		return true
	var tree := get_tree()
	var puzzles := tree.get_first_node_in_group("puzzle_manager")
	var clues := tree.get_first_node_in_group("clue_manager")
	var rooms := tree.get_first_node_in_group("room_progress_manager")
	for iid in definition.required_interactions:
		if puzzles == null or not puzzles.has_interaction(iid):
			return false
	for cid in definition.required_clues:
		if clues == null or not clues.is_discovered(cid):
			return false
	for pid in definition.required_puzzles_solved:
		if puzzles == null or not puzzles.is_solved(pid):
			return false
	for rid in definition.required_rooms_completed:
		if rooms == null or not rooms.is_completed(rid):
			return false
	return true


## Copia ação, texto, uso único, prioridade e estado inicial da definição do
## objeto no JSON. Objeto da cena sem cadastro é um erro de dados.
func _apply_definition() -> void:
	definition = GameData.get_instance().get_object(interaction_id)
	if definition == null:
		push_error("%s: \"%s\" não está cadastrado em data/game_data.json (objects)." % [get_path(), interaction_id])
		return
	if not definition.is_functional():
		push_error("%s: \"%s\" está na cena, mas o JSON o marca como %s." % [get_path(), interaction_id,
			InteractiveObjectData.Implementation.find_key(definition.implementation)])
	action_id = definition.action_id
	prompt_text = definition.prompt_text
	one_shot = definition.one_shot
	enabled = definition.enabled
	selection_priority = definition.selection_priority


## Troca o texto do prompt em tempo de jogo (ex.: portas: Abrir / Fechar / Trancada).
func set_prompt_text(text: String) -> void:
	prompt_text = text
	if _prompt != null:
		_prompt.text = text


## Liga/desliga o objeto em tempo de jogo; ao desligar, o prompt some na hora.
func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		set_highlighted(false)


## Chamado somente pelo PlayerInteractor depois de a ação ser pressionada.
func interact(actor: Node3D) -> bool:
	if not can_interact():
		return false
	_used = true
	# Esconde o prompt antes de avisar os outros sistemas, para que ele já
	# esteja oculto no mesmo quadro em que o monstro desperta.
	if one_shot:
		set_highlighted(false)
	interacted.emit(self, actor)
	return true


## Ao carregar um estado salvo, um objeto de uso único já usado continua indisponível.
func _restore_used_state() -> void:
	var puzzles := get_tree().get_first_node_in_group("puzzle_manager")
	if puzzles != null and puzzles.has_method("has_interaction") and puzzles.has_interaction(interaction_id):
		_used = true
		set_highlighted(false)


func set_highlighted(value: bool) -> void:
	if _prompt != null:
		_prompt.visible = value and can_interact()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var interactor := get_tree().get_first_node_in_group("player_interactor")
		if interactor != null:
			interactor.register_candidate(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		var interactor := get_tree().get_first_node_in_group("player_interactor")
		if interactor != null:
			interactor.unregister_candidate(self)

class_name InteractionRouter
extends Node
## Encaminha interações confirmadas para o sistema de enigmas e pistas.
## Não valida nada: o PuzzleManager e o ClueManager já fazem isso.

@export var interactor: PlayerInteractor
@export var puzzle_manager: PuzzleManager
@export var clue_manager: ClueManager
## Log no console (não aparece na tela). Desligado por padrão; também é
## ativado pelo argumento --debug-monsters.
@export var debug_log: bool = false

var _feedback_layer: CanvasLayer
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _feedback_timer: Timer


func _ready() -> void:
	if interactor == null:
		push_error("InteractionRouter: interactor não atribuído.")
		return
	interactor.interaction_performed.connect(_on_interaction_performed)
	if "--debug-monsters" in OS.get_cmdline_user_args():
		debug_log = true
	_build_feedback_ui()


func _build_feedback_ui() -> void:
	# Feedback visual para que interações não pareçam "não fazer nada".
	_feedback_layer = CanvasLayer.new()
	_feedback_layer.name = "InteractionFeedback"
	_feedback_layer.layer = 20
	_feedback_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_feedback_layer)

	_feedback_panel = PanelContainer.new()
	_feedback_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_feedback_panel.offset_left = 120.0
	_feedback_panel.offset_top = 24.0
	_feedback_panel.offset_right = -120.0
	_feedback_panel.offset_bottom = 100.0
	_feedback_panel.visible = false
	_feedback_layer.add_child(_feedback_panel)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 20)
	_feedback_label.text = ""
	_feedback_panel.add_child(_feedback_label)

	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = 4.0
	_feedback_timer.timeout.connect(func(): _feedback_panel.visible = false)
	add_child(_feedback_timer)


func _show_feedback(message: String) -> void:
	if _feedback_label == null or message.strip_edges() == "":
		return
	_feedback_label.text = message
	_feedback_panel.visible = true
	_feedback_timer.start()


func _on_interaction_performed(interaction_id: StringName, action_id: StringName, _target: Interactable) -> void:
	# Prompt 1: portas físicas tratam o próprio estado (abrir/fechar/trancada) e
	# não entram no histórico de enigmas nem disparam gatilhos.
	var door := _target.get_parent() as Door if _target != null else null
	if door != null:
		_show_feedback(door.consume_message())
		if debug_log:
			print("[Interação] porta %s -> %s" % [interaction_id, door.get_state_name()])
		return
	# Prompt 2: esconderijos tratam a entrada/saída sozinhos (HidingSpot).
	var spot := _target.get_parent() as HidingSpot if _target != null else null
	if spot != null:
		_show_feedback("Você se escondeu. Não faça barulho." if spot.is_occupied() else "")
		return
	var opened_puzzle_message := ""
	var is_new := puzzle_manager != null and puzzle_manager.register_interaction(interaction_id)
	var clues: Array[ClueData] = []
	if clue_manager != null:
		clues = clue_manager.discover_from_object(interaction_id)

	# Execute os efeitos declarados no JSON. O roteador continua usando os
	# sistemas existentes; não cria uma segunda validação de enigmas/pistas.
	var definition: InteractiveObjectData = GameData.get_instance().get_object(interaction_id)
	if definition != null:
		for effect in definition.effects:
			if not effect is Dictionary:
				continue
			match StringName(str(effect.get("type", ""))):
				&"reveal_clue":
					var clue_id := StringName(str(effect.get("clue_id", "")))
					if clue_manager != null and clue_id != &"":
						clue_manager.discover(clue_id)
				&"unlock_door":
					var door_id := StringName(str(effect.get("door_id", "")))
					for node in get_tree().get_nodes_in_group("door"):
						if node is Door and node.door_id == door_id:
							node.unlock()
				&"open_puzzle":
					var pid := StringName(str(effect.get("puzzle_id", "")))
					var ui := get_tree().get_first_node_in_group("puzzle_ui")
					if ui != null and ui.has_method("open_by_id"):
						opened_puzzle_message = ui.open_by_id(pid)
				&"activate_monster":
					# Barulho acontece uma vez só (o livro só cai na primeira vez).
					if not is_new and puzzle_manager != null:
						continue
					var monster_id := StringName(str(effect.get("monster_id", "")))
					for node in get_tree().get_nodes_in_group("monster"):
						if node is MonsterController and node.resolve_config() != null and node.resolve_config().monster_id == monster_id:
							node.activate(interaction_id, _target.global_position if _target != null else node.global_position)
	var feedback_parts: Array[String] = []
	if opened_puzzle_message != "":
		feedback_parts.append(opened_puzzle_message)
	if not clues.is_empty():
		for clue in clues:
			feedback_parts.append("Pista encontrada: " + clue.title)
	# Pistas: o StoryDirector mostra o documento (título + texto) na tela.
	var shows_document := false
	if definition != null:
		for effect in definition.effects:
			if effect is Dictionary and String(effect.get("type", "")) in ["reveal_clue", "music_sequence"]:
				shows_document = true   # versão 5.7: o piano da Música fala pelo diretor
	# Objetos que disparam uma cena de filme ou um documento: a própria cena
	# fala por eles (o aviso aparecia por baixo das barras da cena).
	if definition != null and not shows_document:
		var ndb := GameData.get_instance().narrative_db
		for eid in definition.narrative_event_ids:
			var ev := ndb.get_event(eid)
			if ev != null and ev.type in [NarrativeEvent.EventType.CUTSCENE, NarrativeEvent.EventType.DOCUMENT, NarrativeEvent.EventType.NOTE, NarrativeEvent.EventType.RESEARCH_LOG]:
				shows_document = true
	var director := get_tree().get_first_node_in_group("story_director")
	if shows_document and director != null and director.enabled:
		return
	var opens_puzzle := false
	if definition != null:
		for effect in definition.effects:
			if effect is Dictionary and String(effect.get("type", "")) == "open_puzzle":
				opens_puzzle = true
	if opens_puzzle and feedback_parts.is_empty():
		return   # o painel do enigma abriu: nada de aviso por cima
	if feedback_parts.is_empty():
		match action_id:
			&"ler":
				feedback_parts.append("Você examinou o documento. Procure informações úteis nas pistas.")
			&"manipular":
				feedback_parts.append("Você manipulou o objeto.")
			_:
				feedback_parts.append("Você examinou o objeto.")
	if definition != null:
		for effect in definition.effects:
			if not effect is Dictionary:
				continue
			if String(effect.get("type", "")) == "activate_monster":
				feedback_parts.append("Você ouviu um ruído próximo. Algo despertou...")
	# "Já examinou" só para objetos comuns: o cadeado/cofre da pergunta sempre
	# mostra o motivo de ainda não abrir (faltam pistas / ele está acordado),
	# em vez de parecer travado para sempre.
	if not is_new and feedback_parts.size() == 1 and opened_puzzle_message == "":
		feedback_parts[0] = "Você já examinou este objeto."
	_show_feedback("\n".join(feedback_parts))
	if debug_log:
		print("[Interação] %s (%s) nova=%s pistas=%s" % [interaction_id, action_id, is_new, clues.map(func(c): return c.id)])

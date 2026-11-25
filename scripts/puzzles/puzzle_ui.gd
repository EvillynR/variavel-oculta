class_name PuzzleUI
extends CanvasLayer
## Interface mínima e reutilizável para os enigmas carregados de game_data.json.
## Não contém respostas corretas nem regras próprias: tudo passa pelo PuzzleManager.
##
## Versão 5.7: códigos (DOOR_CODE) têm um teclado numérico na tela (clique ou
## números do teclado, Backspace apaga) com o visor "_ _ _ _"; ao completar os
## dígitos a resposta é enviada sozinha. Números (NUMERIC) já abrem com o
## campo de texto selecionado e as alternativas aceitam as teclas 1, 2, 3...

## O que está digitado no teclado da tela (o pedestal da porta mostra igual).
signal entrada_mudou(puzzle_id: StringName, texto: String)

@export var puzzle_manager_path: NodePath = NodePath("../Systems/PuzzleManager")
@export var clue_manager_path: NodePath = NodePath("../Systems/ClueManager")

var puzzle_manager: PuzzleManager
var clue_manager: ClueManager
var _root: Control
var _panel: PanelContainer
var _content: VBoxContainer
var _feedback: Label
var _answer: LineEdit
var _active_puzzle: PuzzleData
var _code := ""
var _code_len := 4
var _code_display: Label
var _keypad_buttons: Array[Button] = []
var _option_buttons: Array[Button] = []
var _code_locked := false
var _queued_puzzle: PuzzleData
var _previous_pause_state := false

func _ready() -> void:
	add_to_group("puzzle_ui")
	# versão 5.7: acima dos escritos do mapa (50), abaixo das cenas de filme (60)
	layer = maxi(layer, 55)
	_ready_frames = Engine.get_physics_frames()
	process_mode = Node.PROCESS_MODE_ALWAYS
	puzzle_manager = get_node_or_null(puzzle_manager_path) as PuzzleManager
	clue_manager = get_node_or_null(clue_manager_path) as ClueManager
	_build_ui()
	if puzzle_manager == null:
		push_error("PuzzleUI: PuzzleManager não encontrado.")
		return
	puzzle_manager.puzzle_became_available.connect(_on_puzzle_available)
	puzzle_manager.answer_submitted.connect(_on_answer_submitted)
	if clue_manager != null:
		clue_manager.clue_discovered.connect(_on_clue_discovered)

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PuzzleOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.03, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-400, -280)
	_panel.size = Vector2(800, 560)
	_panel.custom_minimum_size = Vector2(800, 560)
	_root.add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_panel.add_child(_content)

## Prompt 3: até aqui a UI nunca tinha funcionado na cena principal (os
## caminhos padrão eram relativos à própria UI e não achavam os managers).
## Agora ela abre sozinha só quando um enigma fica disponível DURANTE o jogo,
## por ação da protagonista, e na sala em que ela está — nunca na abertura
## (enigmas sem requisito ficam disponíveis no primeiro quadro) nem em outra sala.
@export var open_only_in_current_room: bool = true
## Só para testes antigos (anteriores à UI funcionar): não abre sozinha.
static var testing_disable_auto_open: bool = false
## Versão final: o enigma abre quando a protagonista usa o mecanismo da sala
## (efeito "open_puzzle" do objeto), não sozinho quando fica disponível.
@export var auto_open_when_available: bool = false
var _ready_frames: int = 0


func _on_puzzle_available(puzzle: PuzzleData) -> void:
	if puzzle == null:
		return
	if not auto_open_when_available or testing_disable_auto_open or Engine.get_physics_frames() < _ready_frames + 3:
		return
	if open_only_in_current_room:
		var rooms := get_tree().get_first_node_in_group("room_progress_manager")
		if rooms == null or rooms.current_room != puzzle.room_id:
			return
	# Permite enigmas cadastrados para qualquer sala. A disponibilidade e a
	# progressão continuam sob controle do PuzzleManager e dos dados JSON.
	_open_puzzle(puzzle)

## Abre o enigma pelo id (efeito "open_puzzle" de um objeto). Devolve uma
## mensagem curta quando NÃO abre (já resolvido / falta pista), "" se abriu.
func open_by_id(puzzle_id: StringName) -> String:
	if puzzle_manager == null:
		return ""
	var puzzle: PuzzleData = puzzle_manager.database.get_puzzle(puzzle_id) if puzzle_manager.database != null else null
	if puzzle == null:
		return ""
	if puzzle_manager.is_solved(puzzle_id):
		return "Já está resolvido."
	if not puzzle_manager.is_available(puzzle_id):
		return "Ainda falta alguma coisa. Procure pistas pela sala."
	var director := get_tree().get_first_node_in_group("story_director")
	if director != null and director.has_method("puzzle_block_reason"):
		var why: String = director.puzzle_block_reason(puzzle)
		if why != "":
			return why
	_open_puzzle(puzzle)
	return ""


func _open_puzzle(puzzle: PuzzleData) -> void:
	if puzzle_manager == null or not puzzle_manager.is_available(puzzle.id):
		return
	if _root.visible:
		_queued_puzzle = puzzle
		return
	_active_puzzle = puzzle
	_previous_pause_state = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	_rebuild_content()

func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "%s  —  %s" % [ _active_puzzle.subject, _active_puzzle.title ]
	heading.add_theme_font_size_override("font_size", 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(heading)
	var description := Label.new()
	description.text = _active_puzzle.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(description)

	var hints := _discovered_hints_text()
	if hints != "":
		# versão 5.7: as pistas ficam numa caixa com rolagem — com muitas pistas
		# o texto empurrava o teclado/os botões para fora da tela
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 120)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_content.add_child(scroll)
		var clue_label := Label.new()
		clue_label.text = "PISTAS ENCONTRADAS\n" + hints
		clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		clue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_label.add_theme_font_size_override("font_size", 14)
		scroll.add_child(clue_label)

	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_feedback)

	_answer = null
	_code_display = null
	_keypad_buttons.clear()
	_option_buttons.clear()
	match _active_puzzle.question_type:
		PuzzleData.QuestionType.MULTIPLE_CHOICE:
			var tip := Label.new()
			tip.text = "Clique na alternativa ou aperte o número dela no teclado."
			_content.add_child(tip)
			for i in _active_puzzle.options.size():
				var option_button := Button.new()
				option_button.text = "%d. %s" % [i + 1, _active_puzzle.options[i]]
				option_button.pressed.connect(_submit_answer.bind(i))
				_content.add_child(option_button)
				_option_buttons.append(option_button)
			if not _option_buttons.is_empty():
				_option_buttons[0].grab_focus.call_deferred()
		PuzzleData.QuestionType.DOOR_CODE:
			_build_keypad()
		_:
			var instruction := Label.new()
			instruction.text = _input_instruction(_active_puzzle.question_type)
			instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(instruction)
			_answer = LineEdit.new()
			_answer.placeholder_text = "Digite sua resposta..."
			_answer.text_submitted.connect(_on_text_submitted)
			_content.add_child(_answer)
			_answer.grab_focus.call_deferred()
			var submit := Button.new()
			submit.text = "Confirmar"
			submit.pressed.connect(_on_submit_pressed)
			_content.add_child(submit)

	var close_button := Button.new()
	close_button.text = "Fechar (Esc)"
	close_button.pressed.connect(close_puzzle)
	_content.add_child(close_button)
	_center_panel.call_deferred()


## Mantém o painel inteiro e centralizado na tela (o conteúdo pode crescer).
func _center_panel() -> void:
	if _panel == null or not is_inside_tree():
		return
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_panel.position = ((vp - _panel.size) * 0.5).max(Vector2(0, 8))

## Teclado numérico na tela (códigos de cadeado, cofre, porta).
func _build_keypad() -> void:
	_code = ""
	_code_locked = false
	_code_len = maxi(_active_puzzle.correct_answer.length(), 1)
	var instruction := Label.new()
	instruction.text = "Digite o código: clique nos números ou use o teclado (Backspace apaga). Com %d dígitos ele confere sozinho." % _code_len
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(instruction)
	var center := CenterContainer.new()
	_content.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	_code_display = Label.new()
	_code_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_display.add_theme_font_size_override("font_size", 40)
	_code_display.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	box.add_child(_code_display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Apagar", "0", "Limpar"]:
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(84, 40)
		b.focus_mode = Control.FOCUS_NONE
		if k == "Apagar":
			b.pressed.connect(_code_backspace)
		elif k == "Limpar":
			b.pressed.connect(_code_clear)
		else:
			b.pressed.connect(_code_digit.bind(k))
		grid.add_child(b)
		_keypad_buttons.append(b)
	_update_code_display()


func _code_digit(d: String) -> void:
	if _code_locked or _active_puzzle == null or _code.length() >= _code_len:
		return
	_code += d
	_update_code_display()
	if _code.length() >= _code_len:
		_code_locked = true
		var answer := _code
		# deixa o último dígito aparecer antes de conferir
		await get_tree().create_timer(0.25, true).timeout
		if _active_puzzle != null and _root.visible:
			_submit_answer(answer)


func _code_backspace() -> void:
	if _code_locked or _code.is_empty():
		return
	_code = _code.substr(0, _code.length() - 1)
	_update_code_display()


func _code_clear() -> void:
	if _code_locked:
		return
	_code = ""
	_update_code_display()


func _update_code_display() -> void:
	if _code_display == null:
		return
	var parts := PackedStringArray()
	for i in _code_len:
		parts.append(_code[i] if i < _code.length() else "_")
	_code_display.text = " ".join(parts)
	if _active_puzzle != null:
		entrada_mudou.emit(_active_puzzle.id, _code)


## Código digitado agora no teclado da tela (para testes e o pedestal).
func get_code() -> String:
	return _code


func _input_instruction(kind: int) -> String:
	match kind:
		PuzzleData.QuestionType.NUMERIC:
			return "Digite um número. Você pode usar vírgula ou ponto decimal."
		PuzzleData.QuestionType.DOOR_CODE:
			return "Digite o código do mecanismo."
		PuzzleData.QuestionType.LOGIC_SEQUENCE, PuzzleData.QuestionType.IMAGE_ORDER, PuzzleData.QuestionType.MUSIC_SEQUENCE:
			return "Digite os elementos na ordem correta, separados por vírgula."
		PuzzleData.QuestionType.OBJECT_MATCHING:
			return "Associe cada item no formato item=destino; item=destino."
		_:
			return "Digite sua resposta com base nas pistas encontradas."

func _on_text_submitted(_text: String) -> void:
	_on_submit_pressed()

func _on_submit_pressed() -> void:
	if _active_puzzle == null or _answer == null:
		return
	var raw := _answer.text.strip_edges()
	var answer: Variant = raw
	match _active_puzzle.question_type:
		PuzzleData.QuestionType.LOGIC_SEQUENCE, PuzzleData.QuestionType.IMAGE_ORDER, PuzzleData.QuestionType.MUSIC_SEQUENCE:
			var sequence := PackedStringArray()
			for part in raw.split(",", false):
				sequence.append(part.strip_edges())
			answer = sequence
		PuzzleData.QuestionType.OBJECT_MATCHING:
			var pairs := {}
			for part in raw.split(";", false):
				var pair := part.split("=", false, 1)
				if pair.size() == 2:
					pairs[pair[0].strip_edges()] = pair[1].strip_edges()
			answer = pairs
	_submit_answer(answer)

func _submit_answer(answer: Variant) -> void:
	if _active_puzzle == null or puzzle_manager == null:
		return
	var submitted_puzzle := _active_puzzle
	var result := puzzle_manager.submit_answer(submitted_puzzle.id, answer)
	match result:
		PuzzleManager.SubmitResult.INCORRECT:
			_feedback.text = "Resposta incorreta. Procure mais pistas e tente novamente."
			if _answer != null:
				_answer.grab_focus()
			if _code_display != null:
				_code_display.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
				_code_display.text = "ERRADO"
				await get_tree().create_timer(0.7, true).timeout
				if _code_display != null and is_instance_valid(_code_display):
					_code_display.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
					_code = ""
					_code_locked = false
					_update_code_display()
		PuzzleManager.SubmitResult.CORRECT:
			_feedback.text = "Correto! " + submitted_puzzle.solution_explanation
			# Dá tempo para ler o retorno; o jogador fecha manualmente.
			for child in _content.get_children():
				if child is Button and child.text != "Fechar (Esc)":
					child.disabled = true
			for b in _keypad_buttons:
				b.disabled = true
			_code_locked = true
			if _code_display != null:
				_code_display.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		PuzzleManager.SubmitResult.NOT_AVAILABLE:
			_feedback.text = "Este enigma ainda não está disponível."
		PuzzleManager.SubmitResult.ALREADY_SOLVED:
			_feedback.text = "Este enigma já foi resolvido."
		_:
			_feedback.text = "Não foi possível enviar a resposta."

func _on_answer_submitted(puzzle: PuzzleData, correct: bool) -> void:
	if _active_puzzle != null and puzzle.id == _active_puzzle.id and correct:
		_feedback.text = "Correto! " + puzzle.solution_explanation

func _on_clue_discovered(_clue: ClueData) -> void:
	if _root.visible and _active_puzzle != null:
		_rebuild_content()

func _discovered_hints_text() -> String:
	if _active_puzzle == null or puzzle_manager == null:
		return ""
	var lines := PackedStringArray()
	for clue in puzzle_manager.get_discovered_hints(_active_puzzle.id):
		lines.append("• %s: %s" % [clue.title, clue.content])
	return "\n".join(lines)

func close_puzzle() -> void:
	if _root == null or not _root.visible:
		return
	_root.visible = false
	if _active_puzzle != null and _code_display != null:
		_code = ""
		entrada_mudou.emit(_active_puzzle.id, "")
	_active_puzzle = null
	_code_display = null
	_keypad_buttons.clear()
	_option_buttons.clear()
	get_tree().paused = _previous_pause_state
	if _queued_puzzle != null:
		var next_puzzle := _queued_puzzle
		_queued_puzzle = null
		_open_puzzle(next_puzzle)

func _unhandled_input(event: InputEvent) -> void:
	if _root != null and _root.visible and event.is_action_pressed("ui_cancel"):
		close_puzzle()
		get_viewport().set_input_as_handled()


## Números do teclado físico: digitam no teclado da tela ou escolhem a alternativa.
func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible or _active_puzzle == null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var digit := -1
	if k.keycode >= KEY_0 and k.keycode <= KEY_9:
		digit = k.keycode - KEY_0
	elif k.keycode >= KEY_KP_0 and k.keycode <= KEY_KP_9:
		digit = k.keycode - KEY_KP_0
	if _code_display != null:
		if digit >= 0:
			_code_digit(str(digit))
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_BACKSPACE:
			_code_backspace()
			get_viewport().set_input_as_handled()
	elif not _option_buttons.is_empty() and digit >= 1 and digit <= _option_buttons.size():
		if not _option_buttons[digit - 1].disabled:
			_submit_answer(digit - 1)
		get_viewport().set_input_as_handled()


## Prompt 3: usado pela pausa (Esc fecha o enigma em vez de abrir a pausa).
func is_open() -> bool:
	return _root != null and _root.visible

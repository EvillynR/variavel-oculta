class_name PuzzleData
extends Resource
## Dados de um enigma. Não contém lógica de apresentação nem de monstros:
## monster_id é só uma referência que os sistemas de monstro poderão ler.

enum QuestionType {
	MULTIPLE_CHOICE,          ## options + correct_option
	NUMERIC,                  ## correct_answer (número) + numeric_tolerance
	DOOR_CODE,                ## correct_answer (dígitos/símbolos)
	LOGIC_SEQUENCE,           ## correct_sequence
	OBJECT_MATCHING,          ## correct_pairs (objeto -> destino)
	IMAGE_ORDER,              ## correct_sequence (ids das imagens em ordem)
	DOCUMENT_INTERPRETATION,  ## correct_answer + accepted_answers (texto livre)
	MUSIC_SEQUENCE,           ## correct_sequence (notas), aceita entrada nota a nota
}

@export var id: StringName
@export var room_id: StringName
@export var subject: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var question_type: QuestionType = QuestionType.MULTIPLE_CHOICE

@export_group("Resposta")
## Alternativas exibidas (MULTIPLE_CHOICE).
@export var options: PackedStringArray = []
## Índice da alternativa correta em options (MULTIPLE_CHOICE).
@export var correct_option: int = -1
## Resposta única (NUMERIC, DOOR_CODE, DOCUMENT_INTERPRETATION).
@export var correct_answer: String = ""
## Formas alternativas aceitas (DOCUMENT_INTERPRETATION).
@export var accepted_answers: PackedStringArray = []
## Ordem correta (LOGIC_SEQUENCE, IMAGE_ORDER, MUSIC_SEQUENCE).
@export var correct_sequence: PackedStringArray = []
## Pares corretos (OBJECT_MATCHING): chave = objeto, valor = destino.
@export var correct_pairs: Dictionary = {}
@export var numeric_tolerance: float = 0.0
@export var case_sensitive: bool = false
@export var ignore_accents: bool = true
@export_multiline var solution_explanation: String = ""

@export_group("Pistas e condições")
## Pistas relacionadas (ids de ClueData). Não revelam a resposta por padrão.
@export var hint_ids: Array[StringName] = []
## Interações que precisam ter acontecido antes de a resposta ser aceita.
@export var required_interactions: Array[StringName] = []
## Pistas que precisam ter sido descobertas antes de a resposta ser aceita.
@export var required_clue_ids: Array[StringName] = []
## Enigmas que precisam estar resolvidos antes deste.
@export var prerequisite_puzzle_ids: Array[StringName] = []

@export_group("Consequências")
## Monstro associado (lido pelos sistemas de monstro; não usado aqui).
@export var monster_id: StringName
## Saída que este enigma ajuda a liberar. Vazio = não libera nada.
@export var unlocks_exit: StringName
## MUSIC_SEQUENCE: uma nota errada gera evento de erro (o monstro decide
## o que fazer com ele). Desligado = errar só reinicia a sequência.
@export var wrong_step_emits_event: bool = false


func is_sequence_type() -> bool:
	return question_type in [
		QuestionType.LOGIC_SEQUENCE,
		QuestionType.IMAGE_ORDER,
		QuestionType.MUSIC_SEQUENCE,
	]

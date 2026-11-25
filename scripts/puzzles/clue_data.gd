class_name ClueData
extends Resource
## Dados de uma pista (documento, objeto, anotação...).

enum SourceType { DOCUMENT, OBJECT, NOTE, AUDIO, PHOTO, OTHER }

@export var id: StringName
@export var room_id: StringName
## Enigma ao qual a pista pertence (pode ficar vazio em pistas só narrativas).
@export var puzzle_id: StringName
@export var source_type: SourceType = SourceType.DOCUMENT
## Id do objeto interativo que revela esta pista.
@export var source_object_id: StringName
@export var title: String = ""
@export_multiline var content: String = ""
## Pistas que precisam ter sido descobertas antes desta.
@export var required_clue_ids: Array[StringName] = []
## Marque somente quando revelar a resposta fizer parte do enigma.
@export var reveals_answer: bool = false
## Etiquetas para a narrativa (ex.: &"lore", &"subsolo", &"voz_telefone").
@export var narrative_tags: Array[StringName] = []

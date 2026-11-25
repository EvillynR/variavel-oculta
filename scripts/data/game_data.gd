class_name GameData
extends RefCounted
## Banco de dados configuráveis do jogo (Prompt 2).
##
## Fonte principal: res://data/game_data.json. Este carregador lê o JSON uma vez,
## converte cada entrada nos tipos que os sistemas já usam (PuzzleData, ClueData,
## RoomData, NarrativeEvent, MonsterConfig, HearingProfile e
## InteractiveObjectData) e valida tudo. Os sistemas recebem estes objetos em
## memória: não há um segundo banco (.tres) em paralelo.
##
## Uso:
##   GameData.get_instance()           -> banco do jogo (carregado uma vez)
##   GameData.load_text(texto, nome)   -> banco avulso (testes de validação)
##   db.errors / db.warnings           -> mensagens legíveis ("onde: o quê")
##   db.puzzle_db / db.narrative_db    -> bancos usados pelos managers
##   db.get_monster(id), db.get_hearing_profile(id), db.get_object(id)
##
## O carregamento nunca interrompe o jogo: com erros, eles são listados no
## console (push_error) e ficam em db.errors; os testes exigem db.errors vazio.

const DEFAULT_PATH := "res://data/game_data.json"
const FORMAT_VERSION := 1
const TEST_ROOM := &"room_test"

## Campos calculados pelo carregador: não podem ser escritos no JSON.
const DERIVED := {
	"rooms": ["interaction_ids", "planned_interaction_ids", "activation_interaction_ids"],
	"clues": ["source_object_id"],
}

static var _instance: GameData

var source := ""
var errors: PackedStringArray = []
var warnings: PackedStringArray = []

var puzzle_db := PuzzleDatabase.new()
var narrative_db := NarrativeDatabase.new()
var hearing_profiles := {}   # StringName -> HearingProfile
var objects: Array[InteractiveObjectData] = []
## Prompt 2: ruído dos passos da protagonista {"walk"|"run"|"crouch": {"loudness", "interval"}}.
var player_noise: Dictionary = {}

var _enums := {
	"RoomData": {"kind": RoomData.Kind, "geometry_status": RoomData.GeometryStatus, "content_status": RoomData.ContentStatus},
	"NarrativeEvent": {"type": NarrativeEvent.EventType, "tier": NarrativeEvent.Tier, "trigger": NarrativeEvent.TriggerType,
		"content_status": {"TEST": 0, "PROVISIONAL": 1, "FINAL": 2}},
	"PuzzleData": {"question_type": PuzzleData.QuestionType},
	"ClueData": {"source_type": ClueData.SourceType},
	"InteractiveObjectData": {"implementation": InteractiveObjectData.Implementation},
}


# ======================================================== acesso

static func get_instance() -> GameData:
	if _instance == null:
		_instance = load_file(DEFAULT_PATH)
		for e in _instance.errors:
			push_error("GameData: " + e)
		for w in _instance.warnings:
			push_warning("GameData: " + w)
	return _instance


static func load_file(path: String) -> GameData:
	var db := GameData.new()
	db.source = path
	if not FileAccess.file_exists(path):
		db.errors.append("%s: arquivo não encontrado." % path)
		return db
	db._load(FileAccess.get_file_as_string(path))
	return db


static func load_text(text: String, source_name: String = "(texto)") -> GameData:
	var db := GameData.new()
	db.source = source_name
	db._load(text)
	return db


func is_valid() -> bool:
	return errors.is_empty()


func get_monster(monster_id: StringName) -> MonsterConfig:
	return narrative_db.get_monster(monster_id)


func get_hearing_profile(profile_id: StringName) -> HearingProfile:
	return hearing_profiles.get(profile_id)


func get_object(object_id: StringName) -> InteractiveObjectData:
	for o in objects:
		if o.id == object_id:
			return o
	return null


func get_objects_for_room(room_id: StringName) -> Array[InteractiveObjectData]:
	var result: Array[InteractiveObjectData] = []
	for o in objects:
		if o.room_id == room_id:
			result.append(o)
	return result


# ======================================================== carregamento

func _load(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s, linha %d: JSON inválido — %s" % [source, json.get_error_line() + 1, json.get_error_message()])
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("%s: a raiz do JSON precisa ser um objeto { ... }." % source)
		return
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		errors.append("%s: format_version %s não suportado (esperado %d)." % [source, data.get("format_version"), FORMAT_VERSION])
		return
	var known_top := ["format_version", "description", "final_destination_id", "hearing_profiles", "monsters",
		"puzzles", "clues", "rooms", "events", "objects", "player_noise"]
	for key in data:
		if not key in known_top:
			errors.append("%s: seção desconhecida \"%s\" (aceitas: %s)." % [source, key, ", ".join(known_top)])
	for section in ["hearing_profiles", "monsters", "puzzles", "clues", "rooms", "events", "objects"]:
		if typeof(data.get(section, [])) != TYPE_ARRAY:
			errors.append("%s: \"%s\" precisa ser uma lista [ ... ]." % [source, section])
			return

	narrative_db.final_destination_id = StringName(str(data.get("final_destination_id", "")))
	_load_player_noise(data.get("player_noise", {}))

	for entry in _entries(data, "hearing_profiles", "id"):
		var p := HearingProfile.new()
		var where := _where("hearing_profiles", entry)
		var copy: Dictionary = entry.duplicate()
		copy.erase("id")
		_apply(p, copy, "HearingProfile", where)
		p.resource_name = str(entry.get("id"))  # id do perfil, visível em depuração e testes
		hearing_profiles[StringName(str(entry.get("id")))] = p

	var monsters: Array[MonsterConfig] = []
	for entry in _entries(data, "monsters", "monster_id"):
		var m := MonsterConfig.new()
		_apply(m, entry, "MonsterConfig", _where("monsters", entry, "monster_id"))
		monsters.append(m)
	narrative_db.monsters = monsters

	var puzzles: Array[PuzzleData] = []
	for entry in _entries(data, "puzzles", "id"):
		var p := PuzzleData.new()
		_apply(p, entry, "PuzzleData", _where("puzzles", entry))
		puzzles.append(p)
	puzzle_db.puzzles = puzzles

	var clues: Array[ClueData] = []
	for entry in _entries(data, "clues", "id"):
		var c := ClueData.new()
		_apply(c, entry, "ClueData", _where("clues", entry), DERIVED.clues)
		clues.append(c)
	puzzle_db.clues = clues

	var rooms: Array[RoomData] = []
	for entry in _entries(data, "rooms", "id"):
		var r := RoomData.new()
		_apply(r, entry, "RoomData", _where("rooms", entry), DERIVED.rooms)
		rooms.append(r)
	narrative_db.rooms = rooms

	var events: Array[NarrativeEvent] = []
	for entry in _entries(data, "events", "id"):
		var e := NarrativeEvent.new()
		_apply(e, entry, "NarrativeEvent", _where("events", entry))
		events.append(e)
	narrative_db.events = events

	for entry in _entries(data, "objects", "id"):
		var o := InteractiveObjectData.new()
		var copy: Dictionary = entry.duplicate()
		# Nomes curtos no JSON -> campos do recurso.
		for pair in [["action", "action_id"], ["prompt", "prompt_text"]]:
			if copy.has(pair[0]):
				copy[pair[1]] = copy[pair[0]]
				copy.erase(pair[0])
		var conditions: Variant = copy.get("conditions", {})
		copy.erase("conditions")
		var where := _where("objects", entry)
		if typeof(conditions) != TYPE_DICTIONARY:
			errors.append("%s: \"conditions\" precisa ser um objeto { ... }." % where)
		else:
			for k in conditions:
				copy[k] = conditions[k]
		_apply(o, copy, "InteractiveObjectData", where, ["narrative_event_ids"])
		objects.append(o)

	_link_objects()
	_validate_objects()
	_derive_narrative_refs()

	for problem in puzzle_db.validate():
		errors.append("enigmas/pistas: " + problem)
	for problem in narrative_db.validate(puzzle_db):
		errors.append("salas/eventos/monstros: " + problem)
	for w in narrative_db.get_warnings(puzzle_db):
		warnings.append("salas/eventos/monstros: " + w)


## Entradas de uma seção, com checagem de tipo, id obrigatório e id duplicado.
func _entries(data: Dictionary, section: String, id_key: String) -> Array:
	var result := []
	var seen := {}
	var list: Array = data.get(section, [])
	for i in list.size():
		var entry: Variant = list[i]
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s[%d]: cada item precisa ser um objeto { ... }." % [section, i])
			continue
		var id := str(entry.get(id_key, ""))
		if id == "":
			errors.append("%s[%d]: \"%s\" obrigatório e não pode ser vazio." % [section, i, id_key])
			continue
		if seen.has(id):
			errors.append("%s[%d]: id \"%s\" repetido (já usado em %s[%d])." % [section, i, id, section, seen[id]])
			continue
		seen[id] = i
		entry["__index"] = i
		result.append(entry)
	return result


func _where(section: String, entry: Dictionary, id_key: String = "id") -> String:
	return "%s[%d] \"%s\"" % [section, entry.get("__index", -1), entry.get(id_key, "")]


## Copia os campos do JSON para o recurso, convertendo e conferindo os tipos.
func _apply(res: Resource, entry: Dictionary, cls: String, where: String, derived: Array = []) -> void:
	var props := {}
	for prop in res.get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (prop.usage & PROPERTY_USAGE_STORAGE) and not prop.name.begins_with("_"):
			props[prop.name] = prop
	for key in entry:
		if key == "__index":
			continue
		if key in derived:
			errors.append("%s: \"%s\" é calculado pelo carregador e não pode ser escrito no JSON (%s)." % [where, key, _derived_hint(key)])
			continue
		if not props.has(key):
			errors.append("%s: campo desconhecido \"%s\"." % [where, key])
			continue
		var ok := [true]
		var value: Variant = _convert(entry[key], props[key], res, cls, where, ok)
		if ok[0]:
			res.set(key, value)


func _derived_hint(key: String) -> String:
	match key:
		"source_object_id": return "use um efeito {\"type\": \"reveal_clue\"} no objeto que revela a pista"
		"activation_interaction_ids": return "use um efeito {\"type\": \"activate_monster\"} no objeto"
		"interaction_ids", "planned_interaction_ids": return "vem dos \"objects\" da sala (FUNCTIONAL / PLANNED)"
		"narrative_event_ids": return "vem dos eventos com gatilho INTERACTION ou que exigem a interação"
	return "campo derivado"


func _convert(value: Variant, prop: Dictionary, res: Resource, cls: String, where: String, ok: Array) -> Variant:
	var name: String = prop.name
	var fail := func(expected: String) -> Variant:
		errors.append("%s: \"%s\" deveria ser %s, mas é %s." % [where, name, expected, JSON.stringify(value)])
		ok[0] = false
		return null
	if _enums.has(cls) and _enums[cls].has(name):
		var enum_dict: Dictionary = _enums[cls][name]
		if typeof(value) != TYPE_STRING or not enum_dict.has(value):
			errors.append("%s: \"%s\" = %s inválido; aceitos: %s." % [where, name, JSON.stringify(value), ", ".join(enum_dict.keys())])
			ok[0] = false
			return null
		return enum_dict[value]
	match prop.type:
		TYPE_BOOL:
			return value if typeof(value) == TYPE_BOOL else fail.call("true/false")
		TYPE_INT:
			if typeof(value) == TYPE_FLOAT and value == floorf(value):
				return int(value)
			return value if typeof(value) == TYPE_INT else fail.call("um número inteiro")
		TYPE_FLOAT:
			return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fail.call("um número")
		TYPE_STRING:
			return value if typeof(value) == TYPE_STRING else fail.call("um texto")
		TYPE_STRING_NAME:
			return StringName(value) if typeof(value) == TYPE_STRING else fail.call("um texto (id)")
		TYPE_NODE_PATH:
			return NodePath(value) if typeof(value) == TYPE_STRING else fail.call("um caminho de nó (texto)")
		TYPE_VECTOR3:
			if typeof(value) == TYPE_ARRAY and value.size() == 3:
				return Vector3(value[0], value[1], value[2])
			return fail.call("uma lista [x, y, z]")
		TYPE_PACKED_STRING_ARRAY:
			if typeof(value) != TYPE_ARRAY or value.any(func(v): return typeof(v) != TYPE_STRING):
				return fail.call("uma lista de textos")
			return PackedStringArray(value)
		TYPE_ARRAY:
			if typeof(value) != TYPE_ARRAY:
				return fail.call("uma lista")
			var current: Array = res.get(name)
			if not current.is_typed():
				return value
			match current.get_typed_builtin():
				TYPE_STRING_NAME:
					if value.any(func(v): return typeof(v) != TYPE_STRING):
						return fail.call("uma lista de ids (textos)")
					var ids: Array[StringName] = []
					for v in value:
						ids.append(StringName(v))
					return ids
				TYPE_NODE_PATH:
					if value.any(func(v): return typeof(v) != TYPE_STRING):
						return fail.call("uma lista de caminhos de nó (textos)")
					var paths: Array[NodePath] = []
					for v in value:
						paths.append(NodePath(v))
					return paths
				TYPE_DICTIONARY:
					if value.any(func(v): return typeof(v) != TYPE_DICTIONARY):
						return fail.call("uma lista de objetos { ... }")
					var dicts: Array[Dictionary] = []
					dicts.assign(value)
					return dicts
			# Proteção: lista tipada de um tipo não previsto não é aceita em silêncio.
			errors.append("%s: \"%s\" é uma lista tipada (%s) que o carregador ainda não converte." % [where, name, type_string(current.get_typed_builtin())])
			ok[0] = false
			return null
		TYPE_DICTIONARY:
			if typeof(value) != TYPE_DICTIONARY:
				return fail.call("um objeto { ... }")
			return _convert_dictionary(name, value, where, ok)
		TYPE_OBJECT:
			return _convert_resource(name, value, where, ok)
	return value


## Dicionários: os ids viram StringName (como nos .tres originais).
func _convert_dictionary(name: String, value: Dictionary, where: String, ok: Array) -> Dictionary:
	var out := {}
	for k in value:
		var v: Variant = value[k]
		match name:
			"state_events":  # estado -> id de evento
				out[k] = StringName(str(v))
			"kind_weights":  # tipo de som -> peso
				out[StringName(k)] = float(v)
			"sound_bank":  # evento -> AudioStream
				if typeof(v) != TYPE_STRING or not ResourceLoader.exists(v):
					errors.append("%s: som \"%s\" -> %s não existe." % [where, k, v])
					ok[0] = false
				else:
					out[k] = load(v)
			_:
				out[k] = v
	return out


func _convert_resource(name: String, value: Variant, where: String, ok: Array) -> Variant:
	if value == null:
		return null
	if typeof(value) != TYPE_STRING:
		errors.append("%s: \"%s\" deveria ser um id ou caminho (texto)." % [where, name])
		ok[0] = false
		return null
	if name == "hearing_profile":
		if not hearing_profiles.has(StringName(value)):
			errors.append("%s: perfil de audição \"%s\" não existe em hearing_profiles (disponíveis: %s)." % [where, value, ", ".join(hearing_profiles.keys())])
			ok[0] = false
			return null
		return hearing_profiles[StringName(value)]
	if not ResourceLoader.exists(value):
		errors.append("%s: \"%s\" aponta para %s, que não existe." % [where, name, value])
		ok[0] = false
		return null
	return load(value)


# ======================================================== objetos

## Aplica os efeitos declarados nos objetos aos campos que os sistemas existentes
## leem (pista -> source_object_id; monstro -> activation_interaction_ids) e
## calcula as listas de objetos de cada sala.
func _link_objects() -> void:
	for room in narrative_db.rooms:
		var functional: Array[StringName] = []
		var planned: Array[StringName] = []
		for o in objects:
			if o.room_id != room.id:
				continue
			if o.implementation == InteractiveObjectData.Implementation.FUNCTIONAL:
				functional.append(o.id)
			elif o.implementation == InteractiveObjectData.Implementation.PLANNED:
				planned.append(o.id)
		room.interaction_ids = functional
		room.planned_interaction_ids = planned
		room.activation_interaction_ids = [] as Array[StringName]

	for o in objects:
		var where := "objects \"%s\"" % o.id
		for i in o.effects.size():
			var effect: Dictionary = o.effects[i]
			var type := str(effect.get("type", ""))
			var ewhere := "%s, efeito %d (%s)" % [where, i, type]
			match type:
				"reveal_clue":
					var clue := puzzle_db.get_clue(StringName(str(effect.get("clue_id", ""))))
					if clue == null:
						errors.append("%s: pista \"%s\" não existe em clues." % [ewhere, effect.get("clue_id", "")])
					elif clue.source_object_id != &"" and clue.source_object_id != o.id:
						errors.append("%s: a pista \"%s\" já é revelada por \"%s\"; uma pista tem um único objeto de origem." % [ewhere, clue.id, clue.source_object_id])
					else:
						clue.source_object_id = o.id
				"activate_monster":
					var monster_id := StringName(str(effect.get("monster_id", "")))
					var room := narrative_db.get_room_for_monster(monster_id)
					if narrative_db.get_monster(monster_id) == null:
						errors.append("%s: monstro \"%s\" não existe em monsters." % [ewhere, monster_id])
					elif room == null or room.id != o.room_id:
						errors.append("%s: o monstro \"%s\" não é da sala \"%s\" do objeto." % [ewhere, monster_id, o.room_id])
					else:
						room.activation_interaction_ids.append(o.id)
				"open_puzzle":
					var pz := puzzle_db.get_puzzle(StringName(str(effect.get("puzzle_id", ""))))
					if pz == null:
						errors.append("%s: enigma \"%s\" não existe em puzzles." % [ewhere, effect.get("puzzle_id", "")])
					elif pz.room_id != o.room_id:
						errors.append("%s: o enigma \"%s\" é de outra sala." % [ewhere, pz.id])
				"music_sequence":
					var mroom := narrative_db.get_room(StringName(str(effect.get("room_id", ""))))
					if mroom == null or mroom.id != o.room_id:
						errors.append("%s: a sala \"%s\" não é a do objeto." % [ewhere, effect.get("room_id", "")])
					elif mroom.monster_id == &"":
						errors.append("%s: a sala \"%s\" não tem professor para tocar." % [ewhere, mroom.id])
					else:
						mroom.activation_story_ids.append(o.id)
				"unlock_door":
					var target := get_object(StringName(str(effect.get("door_id", ""))))
					if target == null or not target.is_door():
						errors.append("%s: porta \"%s\" não existe em objects (objeto com campo \"door\")." % [ewhere, effect.get("door_id", "")])
				_:
					errors.append("%s: tipo de efeito \"%s\" desconhecido (aceitos: %s)." % [ewhere, type, ", ".join(InteractiveObjectData.EFFECT_TYPES)])
			for key in effect:
				if not key in ["type", "clue_id", "monster_id", "door_id", "puzzle_id", "room_id"]:
					errors.append("%s: campo \"%s\" desconhecido no efeito." % [ewhere, key])


func _validate_objects() -> void:
	var I := InteractiveObjectData.Implementation
	var scene_nodes := {}
	for o in objects:
		var where := "objects \"%s\"" % o.id
		var room := narrative_db.get_room(o.room_id)
		if not String(o.id).begins_with(String(o.room_id) + "."):
			errors.append("%s: o id precisa começar pela sala (\"%s.nome\")." % [where, o.room_id])
		if o.is_door():
			for key in o.door:
				if not key in ["lock", "room_id", "allow_if_previous_pending", "start_open"]:
					errors.append("%s: campo \"%s\" desconhecido em \"door\"." % [where, key])
			var lock := str(o.door.get("lock", "none"))
			if not lock in InteractiveObjectData.DOOR_LOCKS:
				errors.append("%s: door.lock \"%s\" inválido (aceitos: %s)." % [where, lock, ", ".join(InteractiveObjectData.DOOR_LOCKS)])
			elif lock == "room_available":
				var lr := narrative_db.get_room(StringName(str(o.door.get("room_id", ""))))
				if lr == null:
					errors.append("%s: door.room_id \"%s\" não existe em rooms." % [where, o.door.get("room_id", "")])
				elif not lr.is_classroom():
					errors.append("%s: door.room_id \"%s\" precisa ser uma sala de aula (a tranca segue a progressão)." % [where, lr.id])
		match o.implementation:
			I.FUNCTIONAL:
				if room == null:
					errors.append("%s: sala \"%s\" não existe em rooms." % [where, o.room_id])
				elif room.geometry_status != RoomData.GeometryStatus.PHYSICAL:
					errors.append("%s: objeto FUNCTIONAL numa sala sem cenário físico (%s). Use PLANNED até a geometria existir." % [where, o.room_id])
				if o.scene_node.is_empty():
					errors.append("%s: objeto FUNCTIONAL precisa de \"scene_node\" (caminho do Interactable na cena)." % where)
				elif scene_nodes.has(o.scene_node):
					errors.append("%s: scene_node \"%s\" já usado por \"%s\"." % [where, o.scene_node, scene_nodes[o.scene_node]])
				else:
					scene_nodes[o.scene_node] = o.id
			I.PLANNED:
				if room == null:
					errors.append("%s: sala \"%s\" não existe em rooms." % [where, o.room_id])
				if not o.scene_node.is_empty():
					errors.append("%s: objeto PLANNED não pode ter scene_node (ainda não existe na cena)." % where)
				if not o.effects.is_empty() or o.has_conditions():
					errors.append("%s: objeto PLANNED não pode ter efeitos nem condições — um objeto sem função na cena não vira funcional só nos dados." % where)
			I.TEST_ONLY:
				if not o.scene_node.is_empty():
					errors.append("%s: objeto TEST_ONLY não pode ter scene_node." % where)
				if o.room_id != TEST_ROOM and room != null and not room.is_pending():
					warnings.append("%s: objeto de teste numa sala real." % where)
		for iid in o.required_interactions:
			if get_object(iid) == null:
				errors.append("%s: condição exige a interação \"%s\", que não existe em objects." % [where, iid])
		for cid in o.required_clues:
			if puzzle_db.get_clue(cid) == null:
				errors.append("%s: condição exige a pista \"%s\", que não existe." % [where, cid])
		for pid in o.required_puzzles_solved:
			if puzzle_db.get_puzzle(pid) == null:
				errors.append("%s: condição exige o enigma \"%s\", que não existe." % [where, pid])
		for rid in o.required_rooms_completed:
			if narrative_db.get_room(rid) == null:
				errors.append("%s: condição exige a sala \"%s\", que não existe." % [where, rid])
	# Referências de interação feitas por enigmas e eventos têm de existir.
	for p in puzzle_db.puzzles:
		for iid in p.required_interactions:
			if get_object(iid) == null:
				errors.append("puzzles \"%s\": exige a interação \"%s\", que não existe em objects." % [p.id, iid])
	for e in narrative_db.events:
		var refs: Array = e.required_interactions.duplicate()
		if e.trigger == NarrativeEvent.TriggerType.INTERACTION:
			refs.append(e.trigger_id)
		for iid in refs:
			var o := get_object(iid)
			if o == null:
				errors.append("events \"%s\": usa a interação \"%s\", que não existe em objects." % [e.id, iid])
			elif o.implementation == InteractiveObjectData.Implementation.PLANNED and e.enabled:
				errors.append("events \"%s\": está ativo mas depende do objeto PLANNED \"%s\", que não existe na cena." % [e.id, iid])


func _derive_narrative_refs() -> void:
	for o in objects:
		var refs: Array[StringName] = []
		for e in narrative_db.events:
			if (e.trigger == NarrativeEvent.TriggerType.INTERACTION and e.trigger_id == o.id) or o.id in e.required_interactions:
				refs.append(e.id)
		o.narrative_event_ids = refs


## Prompt 2: "player_noise" — intensidade (SoundStimulus.loudness) e intervalo
## (s de jogo) dos passos ao andar, correr e andar agachada.
func _load_player_noise(section: Variant) -> void:
	player_noise = {}
	if typeof(section) != TYPE_DICTIONARY:
		errors.append("%s: \"player_noise\" precisa ser um objeto { ... }." % source)
		return
	for key in section:
		if not key in ["walk", "run", "crouch", "notes"]:
			errors.append("%s: player_noise: modo \"%s\" desconhecido (aceitos: walk, run, crouch)." % [source, key])
			continue
		if key == "notes":
			continue
		var cfg: Variant = section[key]
		if typeof(cfg) != TYPE_DICTIONARY or typeof(cfg.get("loudness")) not in [TYPE_INT, TYPE_FLOAT] or typeof(cfg.get("interval")) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s: player_noise.%s precisa de \"loudness\" e \"interval\" numéricos." % [source, key])
			continue
		if float(cfg.loudness) < 0.0 or float(cfg.interval) <= 0.0:
			errors.append("%s: player_noise.%s: loudness ≥ 0 e interval > 0." % [source, key])
			continue
		player_noise[key] = {"loudness": float(cfg.loudness), "interval": float(cfg.interval)}

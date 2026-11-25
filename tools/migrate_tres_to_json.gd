extends SceneTree
## Migração única (Prompt 2): lê os recursos .tres e a cena principal e gera
## data/game_data.json, que passa a ser a fonte principal dos dados configuráveis.
## Não altera nem apaga nenhum .tres. Não sobrescreve o JSON sem "-- --force".
## Uso: godot --headless -s tools/migrate_tres_to_json.gd [-- --force]
##
## Regras da conversão:
##  - só campos diferentes do padrão da classe são gravados (o carregador usa os
##    mesmos padrões), exceto os identificadores, sempre gravados;
##  - enums são gravados pelo NOME (ex.: "CLASSROOM"), não pelo número;
##  - perfis de audição viram uma lista própria e são referenciados por id
##    (nome do arquivo); navmeshes continuam .tres (geometria) e são
##    referenciados pelo caminho;
##  - os Interactables da cena viram "objects"; as pistas reveladas por um objeto
##    (ClueData.source_object_id) e o despertar de monstro (MonsterTrigger da
##    cena) viram "effects" do objeto; ids planejados das salas viram objetos
##    com implementation = "PLANNED".

const OUT := "res://data/game_data.json"

var ENUMS := {
	"RoomData": {"kind": RoomData.Kind, "geometry_status": RoomData.GeometryStatus, "content_status": RoomData.ContentStatus},
	"NarrativeEvent": {"type": NarrativeEvent.EventType, "tier": NarrativeEvent.Tier, "trigger": NarrativeEvent.TriggerType},
	"PuzzleData": {"question_type": PuzzleData.QuestionType},
	"ClueData": {"source_type": ClueData.SourceType},
}
## NarrativeEvent.content_status é int 0..2 com o mesmo significado de RoomData.ContentStatus.
const EVENT_CONTENT := ["TEST", "PROVISIONAL", "FINAL"]

var hearing_ids := {}  # HearingProfile -> id


func _initialize() -> void:
	if not ResourceLoader.exists("res://data/narrative/narrative_database.tres"):
		push_error("Migração já concluída: os .tres originais foram arquivados em docs/legado/legado_tres_pre_json.zip. A fonte de dados é data/game_data.json.")
		quit(1)
		return
	if FileAccess.file_exists(OUT) and not "--force" in OS.get_cmdline_user_args():
		push_error("%s já existe. Use -- --force para regravar (apaga edições feitas no JSON)." % OUT)
		quit(1)
		return
	var pdb: PuzzleDatabase = load("res://data/puzzle_database.tres")
	var ndb: NarrativeDatabase = load("res://data/narrative/narrative_database.tres")

	var data := {}
	data["format_version"] = 1
	data["description"] = "Banco de dados configuráveis do jogo (fonte principal). Gerado a partir dos .tres pela migração do Prompt 2; edite este arquivo, não os .tres."
	data["final_destination_id"] = String(ndb.final_destination_id)

	# Perfis de audição: todos os .tres da pasta (inclusive os genéricos sem monstro).
	var profiles := []
	var dir := DirAccess.open("res://data/monsters/hearing")
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var p: HearingProfile = load("res://data/monsters/hearing/" + f)
		var id := f.get_basename()
		hearing_ids[p] = id
		var entry := {"id": id}
		entry.merge(_serialize(p, "HearingProfile"))
		profiles.append(entry)
	data["hearing_profiles"] = profiles

	data["monsters"] = ndb.monsters.map(func(m): return _serialize(m, "MonsterConfig", ["monster_id"]))
	data["puzzles"] = pdb.puzzles.map(func(p): return _serialize(p, "PuzzleData", ["id", "room_id"]))
	# source_object_id sai da pista: vira efeito "reveal_clue" do objeto.
	data["clues"] = pdb.clues.map(func(c): return _serialize(c, "ClueData", ["id", "room_id"], ["source_object_id"]))
	# interaction_ids / planned_interaction_ids / activation_interaction_ids saem
	# das salas: são derivados dos objetos pelo carregador.
	var derived_room_fields := ["interaction_ids", "planned_interaction_ids", "activation_interaction_ids"]
	data["rooms"] = ndb.rooms.map(func(r): return _serialize(r, "RoomData", ["id", "kind", "order", "subject", "geometry_status", "content_status"], derived_room_fields))
	data["events"] = ndb.events.map(func(e): return _serialize(e, "NarrativeEvent", ["id", "type", "trigger"]))

	data["objects"] = await _objects(pdb, ndb)

	var text := JSON.stringify(data, "  ", false)
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(text + "\n")
	file.close()
	print("Gravado %s: %d perfis, %d monstros, %d enigmas, %d pistas, %d salas, %d eventos, %d objetos" % [
		OUT, profiles.size(), data.monsters.size(), data.puzzles.size(), data.clues.size(),
		data.rooms.size(), data.events.size(), data.objects.size()])
	quit()


func _objects(pdb: PuzzleDatabase, ndb: NarrativeDatabase) -> Array:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# Gatilhos de monstro configurados na cena: interação -> monster_id.
	var activates := {}
	for trigger in main.find_children("*", "Node", true, false):
		if trigger is MonsterTrigger and trigger.get_parent() is MonsterController:
			var m: MonsterController = trigger.get_parent()
			for iid in trigger.activation_interaction_ids:
				activates[iid] = String(m.config.monster_id)
	var result := []
	var known := {}
	for node in main.find_children("*", "Area3D", true, false):
		if not (node is Interactable):
			continue
		var it: Interactable = node
		var id := String(it.interaction_id)
		var room := ndb.get_room(StringName(id.get_slice(".", 0)))
		var effects := []
		for clue in pdb.get_clues_for_object(it.interaction_id):
			effects.append({"type": "reveal_clue", "clue_id": String(clue.id)})
		if activates.has(it.interaction_id):
			effects.append({"type": "activate_monster", "monster_id": activates[it.interaction_id]})
		var obj := {
			"id": id,
			"room_id": String(room.id) if room else "",
			"implementation": "FUNCTIONAL",
			"scene_node": str(main.get_path_to(it)),
			"action": String(it.action_id),
			"prompt": it.prompt_text,
		}
		if it.one_shot: obj["one_shot"] = true
		if not it.enabled: obj["enabled"] = false
		if it.selection_priority != 0: obj["selection_priority"] = it.selection_priority
		obj["effects"] = effects
		result.append(obj)
		known[id] = true
	# Pistas cujo objeto de origem não existe na cena (conteúdo de TESTE usado só
	# pelos testes automatizados): o vínculo é preservado num objeto TEST_ONLY.
	for clue in pdb.clues:
		var src := String(clue.source_object_id)
		if src == "" or known.has(src):
			continue
		var existing := result.filter(func(o): return o.id == src)
		if existing.is_empty():
			result.append({"id": src, "room_id": String(clue.room_id), "implementation": "TEST_ONLY",
				"effects": [{"type": "reveal_clue", "clue_id": String(clue.id)}],
				"notes": "Objeto só de teste automatizado: não existe na cena."})
			known[src] = true
		else:
			existing[0].effects.append({"type": "reveal_clue", "clue_id": String(clue.id)})
	for room in ndb.rooms:
		for iid in room.planned_interaction_ids:
			if known.has(String(iid)):
				continue
			result.append({"id": String(iid), "room_id": String(room.id), "implementation": "PLANNED", "effects": [],
				"notes": "Objeto previsto: ainda não existe na cena nem tem função."})
	main.queue_free()
	return result


## Campos de script diferentes do padrão da classe.
func _serialize(res: Resource, cls: String, always: Array = [], skip: Array = []) -> Dictionary:
	var defaults: Resource = res.get_script().new()
	var out := {}
	for prop in res.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (prop.usage & PROPERTY_USAGE_STORAGE):
			continue
		var name: String = prop.name
		if name in skip or name.begins_with("_"):
			continue
		var value: Variant = res.get(name)
		if not (name in always) and _same(value, defaults.get(name)):
			continue
		out[name] = _convert(value, cls, name)
	return out


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Resource or b is Resource:
		return a == b
	return var_to_str(a) == var_to_str(b)


func _convert(value: Variant, cls: String, name: String) -> Variant:
	if ENUMS.has(cls) and ENUMS[cls].has(name):
		return ENUMS[cls][name].find_key(value)
	if cls == "NarrativeEvent" and name == "content_status":
		return EVENT_CONTENT[int(value)]
	if value is HearingProfile:
		return hearing_ids.get(value, value.resource_path)
	if value is Resource:
		return value.resource_path
	if value == null:
		return null
	match typeof(value):
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_VECTOR3:
			return [value.x, value.y, value.z]
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var arr := []
			for v in value:
				arr.append(_convert(v, "", ""))
			return arr
		TYPE_DICTIONARY:
			var d := {}
			for k in value:
				d[str(k)] = _convert(value[k], "", "")
			return d
	return value

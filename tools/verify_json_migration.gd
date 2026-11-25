extends SceneTree
## Verificação da migração (Prompt 2): compara, campo a campo, os dados
## carregados de data/game_data.json com os recursos .tres originais.
## Só funciona enquanto os .tres originais existem no projeto; depois do
## arquivamento (docs/legado/legado_tres_pre_json.zip) ela informa que a migração já foi
## concluída. Uso: godot --headless -s tools/verify_json_migration.gd

var diffs := 0
var checked := 0


func _initialize() -> void:
	if not ResourceLoader.exists("res://data/narrative/narrative_database.tres"):
		print("Os .tres originais não estão mais no projeto (migração concluída e arquivada).")
		quit()
		return
	var db := GameData.load_file(GameData.DEFAULT_PATH)
	for e in db.errors:
		print("ERRO JSON  ", e)
	var old_p: PuzzleDatabase = load("res://data/puzzle_database.tres")
	var old_n: NarrativeDatabase = load("res://data/narrative/narrative_database.tres")

	_list("puzzles", old_p.puzzles, db.puzzle_db.puzzles, "id")
	_list("clues", old_p.clues, db.puzzle_db.clues, "id")
	_list("rooms", old_n.rooms, db.narrative_db.rooms, "id")
	_list("events", old_n.events, db.narrative_db.events, "id")
	_list("monsters", old_n.monsters, db.narrative_db.monsters, "monster_id")
	_cmp("final_destination_id", old_n.final_destination_id, db.narrative_db.final_destination_id)
	var dir := DirAccess.open("res://data/monsters/hearing")
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var old: HearingProfile = load("res://data/monsters/hearing/" + f)
			_res("hearing_profiles/" + f.get_basename(), old, db.get_hearing_profile(StringName(f.get_basename())))
	# A configuração do Polvo usada pela cena.
	_res("polvo_config.tres", load("res://data/monsters/polvo_config.tres"), db.get_monster(&"octopus"))

	print("RESULTADO: %d campos comparados, %d diferenças, %d erros de JSON" % [checked, diffs, db.errors.size()])
	quit(0 if diffs == 0 and db.errors.is_empty() else 1)


func _list(label: String, old_list: Array, new_list: Array, key: String) -> void:
	_cmp(label + ".quantidade", old_list.size(), new_list.size())
	for i in old_list.size():
		var old: Resource = old_list[i]
		var found: Resource = null
		for n in new_list:
			if n.get(key) == old.get(key):
				found = n
		_res("%s/%s" % [label, old.get(key)], old, found)
		# Ordem preservada (a ordem define, p.ex., a primeira sala disponível).
		_cmp("%s/%s.posição" % [label, old.get(key)], i, new_list.find(found))


func _res(label: String, old: Resource, new: Resource) -> void:
	if new == null:
		diffs += 1
		print("FALTA      %s" % label)
		return
	for prop in old.get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and (prop.usage & PROPERTY_USAGE_STORAGE) and not prop.name.begins_with("_"):
			var a: Variant = old.get(prop.name)
			var b: Variant = new.get(prop.name)
			if a is HearingProfile and b is HearingProfile:
				_res(label + "." + prop.name, a, b)
			elif a is Resource or b is Resource:
				_cmp(label + "." + prop.name, a.resource_path if a else "", b.resource_path if b else "")
			else:
				_cmp(label + "." + prop.name, a, b)


func _cmp(label: String, a: Variant, b: Variant) -> void:
	checked += 1
	if typeof(a) != typeof(b) or var_to_str(a) != var_to_str(b):
		diffs += 1
		print("DIFERENTE  %s: .tres=%s json=%s" % [label, var_to_str(a), var_to_str(b)])

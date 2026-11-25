class_name ApresentacaoSala
extends Node
## Versão 6.1 — ATALHO DE APRESENTAÇÃO.
## Abra uma das cenas de scenes/apresentacao/ no editor e aperte F6
## ("Executar a cena atual"): o jogo começa no corredor, na frente da porta
## daquela sala, com as salas anteriores já resolvidas (mapa, pistas, portas e
## professores no estado certo). O estado vem de data/apresentacao/<sala>.json,
## gravado jogando a história inteira de verdade:
##   godot --headless --fixed-fps 60 --path . --script res://tests/historia_completa_test.gd -- --gerar-saves-apresentacao
## Observação: ele grava por cima do "Continuar" do menu (o save normal).

@export_enum("room_1", "room_2", "room_3", "room_4", "room_5", "final") var sala := "room_1"

const MAIN := "res://scenes/main.tscn"


func _ready() -> void:
	var path := "res://data/apresentacao/%s.json" % sala
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Apresentação: %s não encontrado ou inválido." % path)
		return
	SaveSystem.write_save(data)
	SaveSystem.pending_action = "continue"
	get_tree().change_scene_to_file.call_deferred(MAIN)


## Usado pelo menu principal (botões "Apresentação").
static func ir_para(tree: SceneTree, nome: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/apresentacao/%s.json" % nome))
	if typeof(data) != TYPE_DICTIONARY:
		return
	SaveSystem.write_save(data)
	SaveSystem.pending_action = "continue"
	tree.change_scene_to_file(MAIN)

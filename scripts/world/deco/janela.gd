extends Node3D
## Janela de escola japonesa: caixilho de madeira escura e vidro em grade.
## A frente (lado de onde se vê) é o +Z local.

@export var largura := 2.4
@export var altura := 1.8
@export var colunas := 3
@export var linhas := 2
## 0 = vidro escuro, 1 = luar (azulado), 2 = luz quente acesa
@export var luz := 1
@export var moldura := 0.12


func _ready() -> void:
	var glass_mat: String = ["vidro_escuro", "vidro_lua", "vidro_quente"][clampi(luz, 0, 2)]
	DecoUtil.box(self, Vector3(largura, altura, 0.04), Vector3.ZERO, glass_mat, Vector3.ZERO, false)
	var f := moldura
	var d := 0.12
	DecoUtil.box(self, Vector3(largura + f * 2.0, f, d), Vector3(0, altura * 0.5 + f * 0.5, 0.03), "madeira_escura")
	DecoUtil.box(self, Vector3(largura + f * 2.0, f * 1.4, d + 0.08), Vector3(0, -altura * 0.5 - f * 0.7, 0.06), "madeira_escura")
	DecoUtil.box(self, Vector3(f, altura, d), Vector3(-largura * 0.5 - f * 0.5, 0, 0.03), "madeira_escura")
	DecoUtil.box(self, Vector3(f, altura, d), Vector3(largura * 0.5 + f * 0.5, 0, 0.03), "madeira_escura")
	for i in range(1, colunas):
		DecoUtil.box(self, Vector3(0.05, altura, 0.07), Vector3(-largura * 0.5 + largura * i / colunas, 0, 0.04), "madeira_escura")
	for j in range(1, linhas):
		DecoUtil.box(self, Vector3(largura, 0.05, 0.07), Vector3(0, -altura * 0.5 + altura * j / linhas, 0.04), "madeira_escura")
	DecoUtil.merge(self)

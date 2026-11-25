#!/usr/bin/env python3
"""Versão 5.4 — móveis com os modelos 3D enviados (assets/models/*.glb).

Gera/reescreve as cenas de móveis em scenes/props/ usando
scripts/world/modelo_prop.gd (encaixa o GLB na caixa do móvel). Medidas em
metros "reais" (sem a escala 3x da sala; tools/layout_moveis.py aplica a escala).
Uso: python3 tools/props_modelos.py
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = os.path.join(ROOT, "scenes", "props")


def v(t):
    return "Vector3(%g, %g, %g)" % tuple(t)


def modelo_node(name, parent, glb_id, rot=(0, 0, 0), caixa=(1, 1, 1), ajuste=0, base=(0, 0, 0)):
    return ('[node name="%s" type="Node3D" parent="%s"]\nscript = ExtResource("ms")\nmodelo = ExtResource("%s")\n'
            'rotacao = %s\ncaixa = %s\najuste = %d\nbase = %s\n\n') % (name, parent, glb_id, v(rot), v(caixa), ajuste, v(base))


def colisao(parent, size, center):
    p = "Colisao" if parent == "." else parent + "/Colisao"
    return ('[node name="Colisao" type="StaticBody3D" parent="%s" groups=["prop_body", "camera_fade"]]\ncollision_mask = 0\n\n'
            '[node name="Caixa" type="CollisionShape3D" parent="%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)\n'
            'shape = SubResource("caixa")\n\n') % (parent, p, center[0], center[1], center[2])


def scene(path, header_ext, subres, body):
    txt = "[gd_scene format=3]\n\n" + header_ext + "\n" + subres + "\n" + body
    open(os.path.join(PROPS, path), "w", encoding="utf-8").write(txt)


def ext(glbs, extra=""):
    s = '[ext_resource type="Script" path="res://scripts/world/modelo_prop.gd" id="ms"]\n'
    for gid, f in glbs.items():
        s += '[ext_resource type="PackedScene" path="res://assets/models/%s.glb" id="%s"]\n' % (f, gid)
    return s + extra


def box(size):
    return '[sub_resource type="BoxShape3D" id="caixa"]\nsize = %s\n' % v(size)


def simples(fname, kind, glb, caixa, rot=(0, 0, 0), ajuste=0, base=(0, 0, 0), col=True, extra_nodes="", extra_glbs=None):
    """Móvel = só o modelo (+ colisão do tamanho da caixa)."""
    glbs = {"g": glb}
    glbs.update(extra_glbs or {})
    body = '[node name="%s" type="Node3D" groups=["camera_fade"]]\n\n' % kind
    body += modelo_node("Modelo", ".", "g", rot, caixa, ajuste, base)
    body += extra_nodes
    sub = ""
    if col:
        sub = box(caixa)
        body += colisao(".", caixa, (base[0], base[1] + caixa[1] / 2, base[2]))
    scene(fname, ext(glbs), sub, body)


# ------------------------------------------------------------------ trocados
# Piano (Música): o piano empoeirado. Versão 5.8: sem o banquinho (tirado do
# modelo) — o Maestro toca em pé, colado no teclado.
body = '[node name="Piano" type="Node3D" groups=["camera_fade"]]\n\n'
body += modelo_node("Modelo", ".", "g", caixa=(1.6, 1.25, 0.6), base=(0, 0, -0.05))
body += colisao(".", None, (0, 0.625, -0.05))
scene("piano.tscn", ext({"g": "piano"}), box((1.6, 1.25, 0.6)), body)

# Globo (Geografia): o globo terrestre do museu, com o pé dele, direto no chão.
# Versão 5.8: sem a mesinha de baixo (com a escala 3x ela tinha 2,25 m — mais
# alta que a Yuko — e o pé do globo parecia flutuar quando ela passava atrás).
body = '[node name="Globo" type="Node3D" groups=["camera_fade"]]\n\n'
body += modelo_node("Modelo", ".", "g", caixa=(0.7, 0.9, 0.7), base=(0, 0, 0))
body += colisao(".", None, (0, 0.45, 0))
scene("globo.tscn", ext({"g": "globo"}), box((0.6, 0.9, 0.6)), body)

# Armário alto: o armário antigo (só móvel; esconderijo agora é só a mesa).
body = '[node name="ArmarioAlto" type="Node3D"]\n\n[node name="Body" type="Node3D" parent="." groups=["camera_fade"]]\n\n'
body += modelo_node("Modelo", "Body", "g", caixa=(1.1, 2.3, 0.77), ajuste=1, base=(0, 0, 0.005))
body += colisao("Body", None, (0, 1.15, 0.005))
scene("armarioalto.tscn", ext({"g": "armario_antigo"}), box((1.1, 2.3, 0.77)), body)

# ------------------------------------------------------------------ novos
simples("calculadora.tscn", "Calculadora", "calculadora", (0.26, 0.2, 0.26), col=False)
simples("livrosantigos.tscn", "LivrosAntigos", "livros_antigos", (0.5, 0.06, 0.45), col=False)
simples("relogio.tscn", "Relogio", "relogio", (0.42, 0.42, 0.06), col=False,
        extra_nodes='[node name="Ponteiros" type="Node" parent="."]\nscript = ExtResource("rel")\n\n',
        )
# o relógio precisa do script dos ponteiros: reescreve com o ext_resource
p = os.path.join(PROPS, "relogio.tscn")
s = open(p, encoding="utf-8").read().replace(
    '[ext_resource type="Script" path="res://scripts/world/modelo_prop.gd" id="ms"]\n',
    '[ext_resource type="Script" path="res://scripts/world/modelo_prop.gd" id="ms"]\n'
    '[ext_resource type="Script" path="res://scripts/world/relogio.gd" id="rel"]\n')
open(p, "w", encoding="utf-8").write(s)
simples("portalaboratorio.tscn", "PortaLaboratorio", "porta_laboratorio", (1.07, 2.1, 0.12), col=False)
simples("bancadapesquisa.tscn", "BancadaPesquisa", "bancada_pesquisa", (1.72, 0.97, 0.64))
simples("frascociencia.tscn", "FrascoCiencia", "frasco_ciencia", (0.3, 0.35, 0.3), col=False)
simples("vidrarias.tscn", "Vidrarias", "vidrarias", (1.4, 0.25, 0.25), col=False)
simples("cranio.tscn", "Cranio", "tigre", (0.32, 0.3, 0.45), col=False)
simples("cantigas.tscn", "Cantigas", "cantigas", (0.34, 0.14, 0.45), rot=(0, 0, 90), col=False)
simples("escrivaninha.tscn", "Escrivaninha", "escrivaninha", (1.6, 0.8, 1.45))
# estante antiga com livros em cima
simples("estanteantiga.tscn", "EstanteAntiga", "estante_antiga", (1.0, 1.8, 0.45),
        extra_nodes=modelo_node("Livros", ".", "lv", caixa=(0.6, 0.4, 0.4), base=(0.1, 1.8, 0)),
        extra_glbs={"lv": "livros_velhos"})

# ------------------------------------------------------------------ estante (CSG) com livros em cima
p = os.path.join(PROPS, "estante.tscn")
s = open(p, encoding="utf-8").read()
if "modelo_prop.gd" not in s:
    s = s.replace("[gd_scene format=3]\n", "[gd_scene format=3]\n\n" + ext({"lv": "livros_velhos", "lc": "livros_coloridos"}).rstrip("\n") + "\n", 1)
    s = s.rstrip("\n") + "\n\n" + modelo_node("LivrosTopo", ".", "lv", caixa=(0.7, 0.42, 0.45), base=(-0.62, 2.3, 0)) \
        + modelo_node("LivrosTopo2", ".", "lc", caixa=(0.55, 0.1, 0.4), base=(0.55, 2.3, 0))
    open(p, "w", encoding="utf-8").write(s)
print("ok: móveis com modelos gerados")

#!/usr/bin/env python3
"""Versão 5.4 — coloca na cena principal os modelos que não são móveis do
layout: gabinetes dos monitores (sala de saída) e a aranha de Ciências.
Reexecutável (remove o que criou antes). Uso: python3 tools/modelos_cena_v54.py"""
import os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scenes", "main.tscn")
s = open(P, encoding="utf-8").read()


def blocks(t):
    return re.split(r'(?m)^(?=\[)', t)


# remove o que esta ferramenta criou antes
out = []
for b in blocks(s):
    if re.match(r'\[node name="(Gabinete\d|Aranha|AmbienteV54)"', b) or 'parent="School/AmbienteV54' in b or re.search(r'parent="School/SalaMonitores/Gabinete\d', b):
        continue
    out.append(b)
s = "".join(out)
# ext_resources
need = {"v54_modelo_prop": ('Script', 'res://scripts/world/modelo_prop.gd'),
        "v54_monitor": ('PackedScene', 'res://assets/models/monitor.glb'),
        "v54_aranha_glb": ('PackedScene', 'res://assets/models/aranha.glb'),
        "v54_aranha": ('Script', 'res://scripts/world/aranha.gd')}
last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', s)][-1]
add = ""
for i, (t, p) in need.items():
    if 'id="%s"' % i not in s:
        add += '[ext_resource type="%s" path="%s" id="%s"]\n' % (t, p, i)
s = s[:last] + add + s[last:]

new = []
# monitores: gabinete de TV antiga atrás de cada tela que brilha (estática)
ZS = (-196.2, -194.0, -191.8)
ROWS = (2.25, 3.47)
i = 0
for r, by in enumerate(ROWS):
    for z in ZS:
        new.append('[node name="Gabinete%d" type="Node3D" parent="School/SalaMonitores"]\n'
                   'transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, -5.31, %.2f, %.2f)\n'
                   'script = ExtResource("v54_modelo_prop")\nmodelo = ExtResource("v54_monitor")\n'
                   'caixa = Vector3(2.05, 1.18, 1.14)\n\n' % (i, by, z))
        # a tela (estática) encaixada no vidro do gabinete
        s, n = re.subn(r'(\[node name="Monitor%d" type="MeshInstance3D" parent="School/SalaMonitores"\]\n)transform = [^\n]*\n' % i,
                       lambda m: m.group(1) + "transform = Transform3D(1, 0, 0, 0, 0.76, 0, 0, 0, 0.66, -4.73, %.2f, %.2f)\n" % (by + 0.6, z + 0.33), s)
        assert n == 1
        i += 1
# aranha no Laboratório de Ciências (só ambientação)
new.append('[node name="AmbienteV54" type="Node3D" parent="School"]\n\n')
new.append('[node name="Aranha" type="Node3D" parent="School/AmbienteV54"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -6.2, 0, -108.5)\n'
           'script = ExtResource("v54_aranha")\nponto_a = Vector3(-6.2, 0, -108.5)\nponto_b = Vector3(-6.2, 0, -99.0)\nvelocidade = 0.8\n\n')
new.append('[node name="Modelo" type="Node3D" parent="School/AmbienteV54/Aranha"]\nscript = ExtResource("v54_modelo_prop")\n'
           'modelo = ExtResource("v54_aranha_glb")\ncaixa = Vector3(1.5, 0.6, 1.5)\n\n')
conn = s.find("\n[connection ")
ins = conn + 1 if conn >= 0 else len(s)
s = s[:ins] + "".join(new) + s[ins:]
open(P, "w", encoding="utf-8").write(s)
print("ok: monitores e aranha")

#!/usr/bin/env python3
"""Prompt 2 — gera a biblioteca de móveis provisórios em scenes/props/ e os
materiais novos em assets/materials/. Convenção: chão em y = 0, frente do
móvel para +Z local, centrado em x/z."""
import os, math
ROOT = "/home/claude/p4"
os.makedirs(f"{ROOT}/scenes/props", exist_ok=True)

MATS = {
 "prop_wood_dark": ('[gd_resource type="StandardMaterial3D" format=3]\n\n[ext_resource type="Texture2D" path="res://assets/textures/walls/lower_wood/weathered_planks_diff_2k.jpg" id="1"]\n\n[resource]\nalbedo_color = Color(0.42, 0.33, 0.25, 1)\nalbedo_texture = ExtResource("1")\nroughness = 0.8\nuv1_triplanar = true\nuv1_scale = Vector3(0.6, 0.6, 0.6)\n'),
 "prop_metal": ('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color(0.33, 0.37, 0.4, 1)\nmetallic = 0.6\nroughness = 0.55\n'),
 "prop_board": ('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color(0.07, 0.15, 0.11, 1)\nroughness = 0.95\n'),
 "prop_paper": ('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color(0.72, 0.68, 0.58, 1)\nroughness = 0.95\n'),
 "prop_fabric": ('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color(0.25, 0.12, 0.12, 1)\nroughness = 1.0\n'),
 "prop_map": ('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color(0.32, 0.45, 0.5, 1)\nroughness = 0.9\n'),
}
for n, t in MATS.items():
    open(f"{ROOT}/assets/materials/{n}.tres", "w").write(t)
MATID = {"wood": "prop_wood_dark", "metal": "prop_metal", "board": "prop_board", "paper": "prop_paper", "fabric": "prop_fabric", "map": "prop_map"}

def tf(x, y, z, yaw=0.0, roll=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    # yaw em torno de Y; roll opcional em torno de Z (entulho tombado)
    if roll:
        cr, sr = math.cos(roll), math.sin(roll)
        b = [[c*cr, -c*sr, s], [sr, cr, 0], [-s*cr, s*sr, c]]
        return f"Transform3D({b[0][0]:.5f}, {b[1][0]:.5f}, {b[2][0]:.5f}, {b[0][1]:.5f}, {b[1][1]:.5f}, {b[2][1]:.5f}, {b[0][2]:.5f}, {b[1][2]:.5f}, {b[2][2]:.5f}, {x:.4f}, {y:.4f}, {z:.4f})"
    return f"Transform3D({c:.5f}, 0, {-s:.5f}, 0, 1, 0, {s:.5f}, 0, {c:.5f}, {x:.4f}, {y:.4f}, {z:.4f})"

def scene(name, parts, script=None, desc=""):
    """parts: (tipo, nome, material, (x0,x1,y0,y1,z0,z1)) para caixas;
    ("cyl", nome, mat, (x, y0, y1, z, raio)); ("sph", nome, mat, (x, y, z, raio))."""
    used = sorted({p[2] for p in parts})
    lines = ['[gd_scene format=3]\n']
    for i, m in enumerate(used):
        lines.append(f'[ext_resource type="Material" path="res://assets/materials/{MATID.get(m, m)}.tres" id="m{i}"]')
    if script:
        lines.append(f'[ext_resource type="Script" path="{script}" id="s1"]')
    lines.append("")
    body_parent = "."
    if script:
        lines.append(f'[node name="{name}" type="Node3D"]\nscript = ExtResource("s1")\n')
        lines.append(f'[node name="Body" type="CSGCombiner3D" parent="."]\nuse_collision = true\n')
        body_parent = "Body"
    else:
        lines.append(f'[node name="{name}" type="CSGCombiner3D"]\nuse_collision = true\n')
    for p in parts:
        mid = used.index(p[2])
        if p[0] == "box":
            x0, x1, y0, y1, z0, z1 = p[3]
            lines.append(f'[node name="{p[1]}" type="CSGBox3D" parent="{body_parent}"]\ntransform = {tf((x0+x1)/2, (y0+y1)/2, (z0+z1)/2)}\nmaterial = ExtResource("m{mid}")\nsize = Vector3({x1-x0:.3f}, {y1-y0:.3f}, {z1-z0:.3f})\n')
        elif p[0] == "cyl":
            x, y0, y1, z, r = p[3]
            lines.append(f'[node name="{p[1]}" type="CSGCylinder3D" parent="{body_parent}"]\ntransform = {tf(x, (y0+y1)/2, z)}\nmaterial = ExtResource("m{mid}")\nradius = {r}\nheight = {y1-y0:.3f}\nsides = 14\n')
        elif p[0] == "sph":
            x, y, z, r = p[3]
            lines.append(f'[node name="{p[1]}" type="CSGSphere3D" parent="{body_parent}"]\ntransform = {tf(x, y, z)}\nmaterial = ExtResource("m{mid}")\nradius = {r}\nradial_segments = 16\nrings = 10\n')
    # Colisão (ajuste pós-Prompt 3): UMA caixa sólida no volume do móvel, em
    # vez da colisão peça por peça do CSG (pernas, assento, encosto deixavam
    # vãos onde a cápsula da protagonista entrava). A caixa é filha do CSG raiz,
    # no grupo "prop_body" (a câmera não colide com ela; o fade usa o pai).
    lo = [1e9, 1e9, 1e9]; hi = [-1e9, -1e9, -1e9]
    for pt in parts:
        if pt[0] == "box":
            x0, x1, y0, y1, z0, z1 = pt[3]
        elif pt[0] == "cyl":
            x, y0, y1, z, r = pt[3]; x0, x1, z0, z1 = x - r, x + r, z - r, z + r
        else:
            x, y, z, r = pt[3]; x0, x1, y0, y1, z0, z1 = x - r, x + r, y - r, y + r, z - r, z + r
        lo = [min(lo[0], x0), min(lo[1], y0), min(lo[2], z0)]; hi = [max(hi[0], x1), max(hi[1], y1), max(hi[2], z1)]
    size = [hi[i] - lo[i] for i in range(3)]; cen = [(hi[i] + lo[i]) / 2 for i in range(3)]
    lines.append(f'[node name="Colisao" type="StaticBody3D" parent="{body_parent}" groups=["prop_body", "camera_fade"]]\ncollision_mask = 0\n')
    lines.append(f'[node name="Caixa" type="CollisionShape3D" parent="{body_parent}/Colisao" if body_parent != "." else "Colisao"]\n')
    lines[-1] = f'[node name="Caixa" type="CollisionShape3D" parent="{"Colisao" if body_parent == "." else body_parent + "/Colisao"}"]\ntransform = {tf(cen[0], cen[1], cen[2])}\nshape = SubResource("caixa")\n'
    lines.insert(len([l for l in lines if l.startswith('[ext_resource')]) + 1, f'[sub_resource type="BoxShape3D" id="caixa"]\nsize = Vector3({size[0]:.3f}, {size[1]:.3f}, {size[2]:.3f})\n')
    text = "\n".join(lines) + "\n"
    text = text.replace("use_collision = true\n", "")
    # móveis entre a câmera e a protagonista ficam translúcidos (camera_controller)
    text = text.replace('type="CSGCombiner3D"]', 'type="CSGCombiner3D" groups=["camera_fade"]]').replace('type="CSGCombiner3D" parent="."]', 'type="CSGCombiner3D" parent="." groups=["camera_fade"]]')
    open(f"{ROOT}/scenes/props/{name.lower()}.tscn", "w").write(text)

B = lambda n, m, *a: ("box", n, m, a)
# carteira com cadeira (frente = +Z: o aluno senta do lado +Z, olhando para −Z)
scene("Carteira", [B("Tampo","wood",-0.5,0.5,0.70,0.75,-0.3,0.3), B("Pe1","metal",-0.47,-0.43,0,0.7,-0.27,-0.23), B("Pe2","metal",0.43,0.47,0,0.7,-0.27,-0.23),
  B("Pe3","metal",-0.47,-0.43,0,0.7,0.23,0.27), B("Pe4","metal",0.43,0.47,0,0.7,0.23,0.27),
  B("Assento","wood",-0.22,0.22,0.42,0.46,0.42,0.86), B("Encosto","wood",-0.22,0.22,0.46,0.9,0.84,0.88), B("PernaCadeira","metal",-0.2,0.2,0,0.42,0.6,0.7)])
scene("Cadeira", [B("Assento","wood",-0.22,0.22,0.42,0.46,-0.22,0.22), B("Encosto","wood",-0.22,0.22,0.46,0.9,0.2,0.24), B("Base","metal",-0.2,0.2,0,0.42,-0.05,0.05)])
# mesa do professor: tampo + painéis laterais + painel de fundo; vão livre embaixo (esconderijo)
scene("MesaProfessor", [B("Tampo","wood",-1.0,1.0,0.76,0.82,-0.45,0.45), B("LadoE","wood",-1.0,-0.94,0,0.76,-0.45,0.45), B("LadoD","wood",0.94,1.0,0,0.76,-0.45,0.45),
  B("Fundo","wood",-0.94,0.94,0.25,0.76,-0.45,-0.39), B("Gaveta","wood",0.45,0.94,0.5,0.76,-0.39,0.42)], script="res://scripts/world/hiding_spot.gd")
scene("QuadroNegro", [B("Moldura","wood",-2.05,2.05,0.95,2.45,-0.04,0.0), B("Quadro","board",-2.0,2.0,1.0,2.4,0.0,0.03), B("Calha","wood",-2.0,2.0,0.95,1.0,0.0,0.1)])
# armário alto (esconderijo): oco por dentro — paredes, teto, fundo e portas frontais
scene("ArmarioAlto", [B("Fundo","metal",-0.55,0.55,0,2.3,-0.38,-0.34), B("LadoE","metal",-0.55,-0.51,0,2.3,-0.38,0.38), B("LadoD","metal",0.51,0.55,0,2.3,-0.38,0.38),
  B("Teto","metal",-0.55,0.55,2.26,2.3,-0.38,0.38), B("Base","metal",-0.55,0.55,0,0.06,-0.38,0.38), B("PortaE","metal",-0.55,-0.01,0.06,2.26,0.34,0.38),
  B("PortaD","metal",0.01,0.55,0.06,2.26,0.34,0.38), B("Fresta1","board",-0.4,-0.1,1.6,1.62,0.38,0.39), B("Fresta2","board",0.1,0.4,1.6,1.62,0.38,0.39)], script="res://scripts/world/hiding_spot.gd")
scene("Estante", [B("LadoE","wood",-1.2,-1.15,0,2.3,-0.25,0.25), B("LadoD","wood",1.15,1.2,0,2.3,-0.25,0.25), B("Fundo","wood",-1.15,1.15,0,2.3,-0.25,-0.22)]
  + [B(f"Prateleira{i}","wood",-1.15,1.15,h,h+0.04,-0.22,0.25) for i, h in enumerate([0.05, 0.6, 1.15, 1.7, 2.26])]
  + [B(f"Livros{i}","paper",-1.1+0.75*i,-0.5+0.75*i,0.64+0.55*(i%3),0.98+0.55*(i%3),-0.2,0.18) for i in range(3)]
  + [B(f"LivrosB{i}","fabric",-0.3+0.6*i,0.25+0.6*i,0.09+1.1*(i%2),0.42+1.1*(i%2),-0.2,0.18) for i in range(2)])
scene("Cavalete", [B("PernaE","wood",-0.36,-0.3,0,1.7,-0.05,0.05), B("PernaD","wood",0.3,0.36,0,1.7,-0.05,0.05), B("PernaT","wood",-0.03,0.03,0,1.6,-0.5,-0.42),
  B("Apoio","wood",-0.4,0.4,0.8,0.85,-0.02,0.12), B("Tela","paper",-0.38,0.38,0.85,1.65,0.0,0.03)])
scene("MapaMundi", [B("Moldura","wood",-1.55,1.55,0.95,2.65,-0.04,0.0), B("Mapa","map",-1.5,1.5,1.0,2.6,0.0,0.02), B("Continente1","paper",-1.1,-0.4,1.6,2.3,0.02,0.03), B("Continente2","paper",0.1,0.9,1.3,2.2,0.02,0.03)])
scene("Globo", [("cyl","Mesa","wood",(0,0,0.75,0,0.35)), ("cyl","Haste","metal",(0,0.75,1.0,0,0.03)), ("sph","Esfera","map",(0,1.25,0,0.28))])
scene("Piano", [B("Corpo","wood",-0.8,0.8,0,1.25,-0.35,0.2), B("Teclado","paper",-0.75,0.75,0.72,0.78,0.2,0.45), B("Tampa","wood",-0.8,0.8,0.78,0.82,0.2,0.45), B("Banco","wood",-0.4,0.4,0,0.48,0.75,1.1)])
scene("EstantePartitura", [("cyl","Haste","metal",(0,0,1.15,0,0.03)), ("cyl","Base","metal",(0,0,0.04,0,0.25)), B("Apoio","metal",-0.25,0.25,1.1,1.4,-0.02,0.02)])
scene("BancadaLab", [B("Tampo","board",-1.5,1.5,0.9,0.96,-0.45,0.45), B("Gabinete","wood",-1.45,1.45,0,0.9,-0.42,0.38), B("Pia","metal",0.8,1.3,0.96,1.0,-0.3,0.2), B("Torneira","metal",1.0,1.06,0.96,1.3,-0.38,-0.32)])
scene("QuadroAvisos", [B("Moldura","wood",-1.05,1.05,1.0,2.25,-0.04,0.0), B("Cortica","fabric",-1.0,1.0,1.05,2.2,0.0,0.02)] + [B(f"Papel{i}","paper",-0.85+0.42*i,-0.55+0.42*i,1.3+0.35*(i%2),1.75+0.35*(i%2),0.02,0.03) for i in range(4)])
scene("Lixeira", [("cyl","Balde","metal",(0,0,0.6,0,0.2))])
scene("ArmariosAlunos", [B(f"Armario{i}","metal",-0.75+0.5*i,-0.27+0.5*i,0,2.0,-0.25,0.25) for i in range(3)] + [B(f"Grade{i}","board",-0.65+0.5*i,-0.37+0.5*i,1.6,1.75,0.25,0.26) for i in range(3)])
scene("MesaCartas", [B("Tampo","wood",-1.2,1.2,0.82,0.88,-0.7,0.7), B("Base","wood",-1.0,1.0,0,0.82,-0.5,0.5), B("Carta","map",-0.8,0.4,0.88,0.89,-0.5,0.4)])
scene("Entulho", [B("Caixa1","wood",-0.3,0.3,0,0.45,-0.25,0.25), B("Caixa2","paper",0.2,0.6,0,0.3,0.2,0.55), B("Placa","wood",-0.6,0.3,0.0,0.08,0.3,0.7)])
print("props ok")

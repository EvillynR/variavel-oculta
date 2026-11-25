#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Versão 5 da escola (pedido da equipe) — roda UMA vez sobre scenes/main.tscn.

- A salinha onde ela acordava sai do começo do corredor: vira a SALA DOS
  MONITORES (a saída), construída no fim do corredor (z -190..-198).
- O começo do corredor (z -4) ganha uma parede.
- A antiga 3ª sala (Artes, fechada) vira o PÁTIO a céu aberto onde ela acorda:
  piso de pedra, fachadas de dois andares com janelas, beirais de telha,
  cerejeira, lanternas de pedra, banco, entulho, poças, névoa e luar.
- Os monitores saem da sala de Música (que volta a ser sala de aula).
- Monstros: só o Leitor (Português) e o Maestro (Música); os outros saem.
- Visual de escola japonesa: janelas altas de caixilho no corredor e no
  fundo das salas, luminárias pendentes no corredor.

Faz backup em ../main_before_v5.tscn. Os móveis são do tools/layout_moveis.py
e os objetos da história do tools/build_story.py (rodar depois).
"""
import math, os, re, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCENE = os.path.join(ROOT, "scenes", "main.tscn")

s = open(SCENE, encoding="utf-8").read()
if "School/Patio" in s or 'name="Patio"' in s:
    raise SystemExit("main.tscn já está na versão 5")
shutil.copy(SCENE, os.path.join(ROOT, "..", "main_before_v5.tscn"))


def blocks(text):
    return [b for b in re.split(r'(?m)^(?=\[)', text) if b]


def node_path(b):
    m = re.match(r'\[node name="([^"]+)"([^\]]*)\]', b)
    if not m:
        return None
    pm = re.search(r'parent="([^"]*)"', m.group(2))
    if not pm:
        return "."
    return m.group(1) if pm.group(1) == "." else pm.group(1) + "/" + m.group(1)


def drop(text, pred):
    out = []
    n = 0
    for b in blocks(text):
        p = node_path(b)
        if p is not None and pred(p):
            n += 1
            continue
        out.append(b)
    return "".join(out), n


def edit_node(text, path, fn):
    out = []
    hit = 0
    for b in blocks(text):
        if node_path(b) == path:
            b = fn(b)
            hit += 1
        out.append(b)
    assert hit == 1, (path, hit)
    return "".join(out)


def set_prop(b, key, value):
    """Troca/insere 'key = value' logo depois do cabeçalho do nó."""
    lines = b.split("\n")
    for i, l in enumerate(lines):
        if l.startswith(key + " = "):
            lines[i] = "%s = %s" % (key, value)
            return "\n".join(lines)
    lines.insert(1, "%s = %s" % (key, value))
    return "\n".join(lines)


def look(pos, target):
    """Transform3D com o -Z local apontando de pos para target (luz/câmera)."""
    f = [target[i] - pos[i] for i in range(3)]
    n = math.sqrt(sum(v * v for v in f))
    f = [v / n for v in f]
    z = [-v for v in f]                       # +Z local = -frente
    up = [0, 1, 0]
    x = [up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0]]
    nx = math.sqrt(sum(v * v for v in x))
    x = [v / nx for v in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    # texto do Transform3D: linhas da matriz (colunas = eixos x, y, z)
    rows = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2]]
    return "Transform3D(%s, %.4f, %.4f, %.4f)" % (", ".join("%.6f" % v for v in rows), pos[0], pos[1], pos[2])


def ident(x, y, z, yaw=0.0):
    c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return "Transform3D(%.6g, 0, %.6g, 0, 1, 0, %.6g, 0, %.6g, %.4f, %.4f, %.4f)" % (c, sn, -sn, c, x, y, z)


# ------------------------------------------------------------------ remoções
s, n = drop(s, lambda p: p == "School/InitialRoom" or p.startswith("School/InitialRoom/"))
print("salinha removida:", n)
s, n = drop(s, lambda p: p.split("/")[-1].startswith("EndWall_") and p.startswith("School/Corridor5/"))
print("fim do corredor aberto:", n)
s, n = drop(s, lambda p: p.startswith("School/Exit/PortaFechada_"))
print("porta do pátio aberta:", n)
MON = {"Desk", "Console", "Chair", "MonitorGlow"} | {"Monitor%02d" % i for i in (0, 1, 2, 10, 11, 12)}
s, n = drop(s, lambda p: p.startswith("School/MusicRoom/") and p.split("/")[-1] in MON)
print("monitores saíram da Música:", n)
s, n = drop(s, lambda p: p in ("MonsterRoster/Polvo", "MonsterRoster/Cartografo") or p.startswith("MonsterRoster/Polvo/") or p.startswith("MonsterRoster/Cartografo/"))
print("monstros removidos:", n)

# ------------------------------------------------------------------ edições
s = edit_node(s, "School/Doors/PortaInicial", lambda b: set_prop(set_prop(b, "transform", ident(0, 0, -190)), "door_id", '&"sala_saida.porta"'))
s = edit_node(s, "School/Doors/PortaMusica", lambda b: set_prop(b, "door_id", '&"room_5.porta"'))
s = edit_node(s, "InitialRoomCamera", lambda b: set_prop(set_prop(set_prop(b, "transform", ident(0, 0, -194)), "minimum_camera_z", "-197.4"), "maximum_camera_z", "-190.6"))
s = edit_node(s, "RoomVolumes/InitialVolume", lambda b: set_prop(set_prop(b, "transform", ident(0, 0, -194)), "room_id", '&"sala_saida"'))
s = edit_node(s, "RoomVolumes/MusicRoomVolume", lambda b: set_prop(b, "room_id", '&"room_5"'))
s = s.replace('[node name="Angulo" parent="MonsterRoster" instance=ExtResource("33_monster")]',
              '[node name="Maestro" parent="MonsterRoster" instance=ExtResource("33_monster")]')
s = s.replace('parent="MonsterRoster/Angulo"', 'parent="MonsterRoster/Maestro"')
s = edit_node(s, "MonsterRoster/Maestro", lambda b: set_prop(b, "config_id", '&"maestro"'))
s = s.replace('mesh = SubResource("AnguloMesh")\nsurface_material_override/0 = SubResource("AnguloMat")',
              'mesh = SubResource("MaestroMesh")\nsurface_material_override/0 = SubResource("MaestroMat")')
# professores em escala Little Nightmares (cápsula provisória mais alta)
for mid in ("LeitorMesh", "MaestroMesh"):
    s = re.sub(r'(\[sub_resource type="CapsuleMesh" id="%s"\]\n)radius = [^\n]*\nheight = [^\n]*\n' % mid,
               r'\1radius = 0.75\nheight = 4.2\n', s)
for name in ("Leitor", "Maestro"):
    s = edit_node(s, "MonsterRoster/%s/TemporaryVisual" % name, lambda b: set_prop(b, "position", "Vector3(0, 2.1, 0)"))
# ela começa no pátio
s = edit_node(s, "Player", lambda b: set_prop(b, "transform", ident(-12.5, 0.05, -69.5)))
# névoa volumétrica (só onde houver FogVolume: o pátio)
s = re.sub(r'(\[sub_resource type="Environment" id="Environment_7gohe"\]\n)', r'\1volumetric_fog_enabled = true\nvolumetric_fog_density = 0.0\nvolumetric_fog_albedo = Color(0.55, 0.62, 0.75, 1)\nvolumetric_fog_length = 40.0\n', s)

# ------------------------------------------------------------------ recursos novos
ext = []
sub = []
ext.append('[ext_resource type="Material" path="res://assets/materials/patio_stone.tres" id="v5_stone"]\n')
for nm in ("janela", "luminaria", "toro", "cerejeira", "banco_patio", "entulho_patio", "lua", "telhado"):
    ext.append('[ext_resource type="Script" path="res://scripts/world/deco/%s.gd" id="v5_%s"]\n' % (nm, nm))
sub.append('[sub_resource type="BoxShape3D" id="BoxShape3D_patiocamera"]\nsize = Vector3(19.8, 4.5, 24.6)\n\n')
sub.append('[sub_resource type="BoxShape3D" id="BoxShape3D_patiovolume"]\nsize = Vector3(19.8, 4.5, 24.6)\n\n')
sub.append('[sub_resource type="FogMaterial" id="FogMat_patio"]\ndensity = 0.05\nalbedo = Color(0.62, 0.68, 0.8, 1)\nheight_falloff = 0.6\nedge_fade = 0.4\n\n')

nodes = []


def node(name, typ, parent, props=None, script=None):
    t = '[node name="%s" type="%s" parent="%s"]\n' % (name, typ, parent)
    # o script vem antes: senão as propriedades @export dele são ignoradas
    if script:
        t += 'script = ExtResource("%s")\n' % script
    for k, v in (props or {}).items():
        t += "%s = %s\n" % (k, v)
    nodes.append(t + "\n")


def csg(name, parent, pos, size, mat=None, collision=True, visible=True, matsub=None):
    p = {"transform": ident(*pos)}
    if not visible:
        p["visible"] = "false"
    if mat:
        p["material_override"] = 'ExtResource("%s")' % mat
    if matsub:
        p["material"] = 'SubResource("%s")' % matsub
    if collision:
        p["use_collision"] = "true"
    p["size"] = "Vector3(%.3f, %.3f, %.3f)" % size
    node(name, "CSGBox3D", parent, p)


def wall(prefix, parent, center, length, along_x, height_top=7.0):
    """Parede padrão da escola: madeira (0..2,4), friso e reboco (2,4..topo)."""
    cx, cz = center
    def sz(t, h):
        return (length, h, t) if along_x else (t, h, length)
    up_h = height_top - 2.4
    csg(prefix + "_Lower", parent, (cx, 1.2, cz), sz(0.2, 2.4), "5_85g3d")
    csg(prefix + "_Trim", parent, (cx, 2.4, cz), sz(0.3, 0.12), "5_85g3d")
    csg(prefix + "_Upper", parent, (cx, 2.4 + up_h / 2, cz), sz(0.2, up_h), "4_tipki")


# ---------------------------------------------- começo do corredor fechado
node("Fechamentos", "Node3D", "School")
wall("InicioCorredor", "School/Fechamentos", (0.0, -4.0), 7.2, True)

# ---------------------------------------------- sala dos monitores (saída)
P = "School/SalaMonitores"
node("SalaMonitores", "Node3D", "School")
csg("Floor", P, (0, -0.1, -194), (12, 0.2, 8), "1_o6xl0", matsub="StandardMaterial3D_tefeu")
csg("Ceiling", P, (0, 7.0, -194), (12, 0.2, 8), "2_tipki")
wall("WallWest", P, (-6.0, -194), 8.0, False)
csg("WallEast", P, (6.0, 2.25, -194), (0.2, 4.5, 8), visible=False)
wall("WallSouth", P, (0.0, -198.05), 12.2, True)
wall("WallDoorLeft", P, (-3.8, -190.0), 4.6, True)
wall("WallDoorRight", P, (3.8, -190.0), 4.6, True)
csg("WallDoorTop", P, (0, 6.0, -190.0), (3.0, 2.0, 0.2), "4_tipki", collision=False)
node("SalaLight", "SpotLight3D", P, {"transform": "Transform3D(1, 0, 0, 0, -4.371139e-08, 1, 0, -1, -4.371139e-08, 0.5, 6.6, -194)",
     "light_color": "Color(0.62, 0.72, 0.9, 1)", "light_energy": "4.0", "light_cull_mask": "4294966273",
     "shadow_enabled": "true", "shadow_blur": "1.5", "spot_range": "10.0", "spot_attenuation": "1.3", "spot_angle": "60.0"})
# mesa dos monitores na parede do fundo (oeste), em escala dos móveis 3x
csg("Desk", P, (-4.7, 1.1, -194.0), (2.2, 2.2, 6.4), matsub="StandardMaterial3D_tefeu")
csg("Console", P, (-5.5, 2.5, -194.0), (0.6, 0.6, 5.4), matsub="Mat_console")
csg("Chair", P, (-2.4, 0.9, -194.0), (1.4, 1.8, 1.6), matsub="StandardMaterial3D_tefeu")
for i, (y, z) in enumerate([(3.6, -196.2), (3.6, -194.0), (3.6, -191.8), (5.5, -196.2), (5.5, -194.0), (5.5, -191.8)]):
    nodes.append('[node name="Monitor%d" type="MeshInstance3D" parent="%s"]\ntransform = Transform3D(2, 0, 0, 0, 2, 0, 0, 0, 2, -5.82, %.2f, %.2f)\nmesh = SubResource("Mesh_monitor")\nsurface_material_override/0 = SubResource("Mat_monitor%d")\n\n' % (i, P, y, z, i % 2))
node("MonitorGlow", "OmniLight3D", P, {"transform": ident(-3.6, 4.4, -194.0), "light_color": "Color(0.45, 0.7, 1, 1)",
     "light_energy": "1.6", "light_cull_mask": "4294966273", "shadow_enabled": "true", "omni_range": "8.0"})

# ---------------------------------------------- pátio a céu aberto (antiga Artes)
P = "School/Patio"
node("Patio", "Node3D", "School")
csg("Piso", P, (-13.5, -0.1, -71.0), (20.0, 0.2, 25.0), "v5_stone")
wall("ParedeOeste", P, (-23.5, -71.0), 25.2, False, 11.2)
wall("ParedeSul", P, (-13.5, -83.5), 20.2, True, 11.2)
# fachadas do 2º andar acima das paredes que já existem (7..11,2 m)
csg("FachadaNorte", P, (-13.5, 9.1, -58.5), (20.2, 4.2, 0.2), "4_tipki")
csg("FachadaLeste", P, (-3.5, 9.1, -71.0), (0.2, 4.2, 25.2), "4_tipki", collision=False)
csg("FaixaAndar", P, (-13.5, 7.1, -58.65), (20.2, 0.35, 0.35), "5_85g3d", collision=False)
csg("FaixaAndarOeste", P, (-23.35, 7.1, -71.0), (0.35, 0.35, 25.2), "5_85g3d", collision=False)
csg("FaixaAndarSul", P, (-13.5, 7.1, -83.35), (20.2, 0.35, 0.35), "5_85g3d", collision=False)
# janelas: térreo (salas que dão para o pátio) e 2º andar (algumas acesas)
WIN = []
for i, z in enumerate([-62.0, -66.5, -75.5, -80.0]):
    WIN.append(("JanelaOesteT%d" % i, (-23.38, 3.6, z), 90, 3.0, 2.2, 3, 2, 1))
    WIN.append(("JanelaOesteA%d" % i, (-23.38, 9.1, z), 90, 3.0, 2.0, 3, 2, 2 if i in (1,) else 0))
for i, x in enumerate([-20.0, -15.5, -11.0, -6.5]):
    WIN.append(("JanelaNorteT%d" % i, (x, 3.6, -58.62), 180, 3.0, 2.2, 3, 2, 0))
    WIN.append(("JanelaNorteA%d" % i, (x, 9.1, -58.62), 180, 3.0, 2.0, 3, 2, 2 if i == 2 else 0))
    WIN.append(("JanelaSulT%d" % i, (x, 3.6, -83.38), 0, 3.0, 2.2, 3, 2, 1 if i == 1 else 0))
    WIN.append(("JanelaSulA%d" % i, (x, 9.1, -83.38), 0, 3.0, 2.0, 3, 2, 2 if i == 3 else 0))
for (nm, pos, yaw, w, h, c, r, luz) in WIN:
    node(nm, "Node3D", P, {"transform": ident(*pos, yaw=yaw), "largura": w, "altura": h, "colunas": c, "linhas": r, "luz": luz}, "v5_janela")
# beirais de telha (2º andar)
node("TelhadoOeste", "Node3D", P, {"transform": ident(-23.4, 11.3, -71.0, yaw=90), "comprimento": "25.6"}, "v5_telhado")
node("TelhadoNorte", "Node3D", P, {"transform": ident(-13.5, 11.3, -58.6, yaw=180), "comprimento": "20.6"}, "v5_telhado")
node("TelhadoSul", "Node3D", P, {"transform": ident(-13.5, 11.3, -83.4, yaw=0), "comprimento": "20.6"}, "v5_telhado")
# cenário
node("Cerejeira", "Node3D", P, {"transform": ident(-18.0, 0, -65.5)}, "v5_cerejeira")
node("ToroNorte", "Node3D", P, {"transform": ident(-7.2, 0, -61.2, yaw=-90)}, "v5_toro")
node("ToroSul", "Node3D", P, {"transform": ident(-7.2, 0, -80.8, yaw=-90), "acesa": "false"}, "v5_toro")
node("Banco", "Node3D", P, {"transform": ident(-11.0, 0, -77.6)}, "v5_banco_patio")
node("Entulho", "Node3D", P, {"transform": ident(-18.5, 0, -77.0)}, "v5_entulho_patio")
node("Lua", "Node3D", P, {"transform": ident(-95.0, 46.0, -60.0)}, "v5_lua")
node("Luar", "SpotLight3D", P, {"transform": look((4.0, 30.0, -62.0), (-15.0, 0.0, -73.0)),
     "light_color": "Color(0.55, 0.66, 0.92, 1)", "light_energy": "7.0", "light_cull_mask": "4294966273",
     "shadow_enabled": "true", "shadow_blur": "2.0", "spot_range": "48.0", "spot_attenuation": "0.6", "spot_angle": "34.0"})
node("LuzAmbientePatio", "OmniLight3D", P, {"transform": ident(-13.5, 6.0, -71.0), "light_color": "Color(0.35, 0.42, 0.6, 1)",
     "light_energy": "0.8", "omni_range": "16.0", "shadow_enabled": "false"})
node("Nevoa", "FogVolume", P, {"transform": ident(-13.5, 1.0, -71.0), "size": "Vector3(20, 2.4, 25)", "material": 'SubResource("FogMat_patio")'})

# porta do pátio para o corredor (abre depois do mapa)
nodes.append('[node name="PortaPatio" parent="School/Doors" instance=ExtResource("60_door")]\n'
             'transform = Transform3D(-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08, -3.5000, 0.0000, -71.0000)\n'
             'door_id = &"patio.porta"\nopening_width = 3.0\nswing_sign = -1.0\nlink_layers = 64\n\n')
# câmera e volume do pátio
nodes.append('[node name="PatioCamera" parent="." instance=ExtResource("3_sugp2")]\n'
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -13.5, 0, -71.0)\n'
             'camera_priority = 5\ncamera_offset = Vector3(9, 6.2, 0)\ncamera_fov = 40.0\nblend_speed = 0.8\n'
             'use_z_limits = true\nminimum_camera_z = -82.9\nmaximum_camera_z = -59.1\n'
             'occluder_paths = Array[NodePath]([NodePath("../School/Exit/WallEastA_Upper"), NodePath("../School/Exit/WallEastA_Trim"), NodePath("../School/Exit/WallEastA_Lower"), NodePath("../School/Exit/WallEastB_Upper"), NodePath("../School/Exit/WallEastB_Trim"), NodePath("../School/Exit/WallEastB_Lower"), NodePath("../School/Exit/WallEastDoorTop"), NodePath("../School/Patio/FachadaLeste")])\n\n'
             '[node name="CollisionShape3D" parent="PatioCamera" index="0"]\nshape = SubResource("BoxShape3D_patiocamera")\n\n'
             '[node name="CameraPoint" parent="PatioCamera" index="1"]\nvisible = false\n\n')
nodes.append('[node name="PatioVolume" type="Area3D" parent="RoomVolumes"]\ntransform = %s\ncollision_layer = 0\nmonitorable = false\n'
             'script = ExtResource("42_roomvol")\nroom_id = &"patio"\n\n'
             '[node name="Shape" type="CollisionShape3D" parent="RoomVolumes/PatioVolume"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.25, 0)\n'
             'shape = SubResource("BoxShape3D_patiovolume")\n\n' % ident(-13.5, 0, -71.0))

# ---------------------------------------------- escola japonesa: corredor e salas
# posições (mundo) das luzes do corredor -> luminárias pendentes
def world_positions(text, parent_prefix, name_prefix):
    origin = {}
    out = []
    for b in blocks(text):
        p = node_path(b)
        if p is None:
            continue
        tr = re.search(r'transform = Transform3D\(([^)]*)\)', b)
        po = re.search(r'position = Vector3\(([^)]*)\)', b)
        loc = [float(v) for v in tr.group(1).split(",")[-3:]] if tr else ([float(v) for v in po.group(1).split(",")] if po else [0, 0, 0])
        parent = p.rsplit("/", 1)[0] if "/" in p else "."
        base = origin.get(parent, [0, 0, 0])
        w = [base[i] + loc[i] for i in range(3)]
        origin[p] = w
        if p.startswith(parent_prefix) and p.split("/")[-1].startswith(name_prefix):
            out.append((p, w))
    return out


lights = world_positions(s, "School/", "CorridorLight")
node("EscolaJaponesa", "Node3D", "School")
J = "School/EscolaJaponesa"
for i, (p, w) in enumerate(sorted(lights, key=lambda t: -t[1][2])):
    node("Luminaria%d" % i, "Node3D", J, {"transform": ident(w[0], 6.9, w[2])}, "v5_luminaria")
# janelas altas (bandeiras) na parede do corredor que dá para as salas, entre as portas
doors_z = [-10.5, -40.5, -71.0, -95.5, -119.9, -175.0]
k = 0
z = -6.5
while z > -188.0:
    if all(abs(z - d) > 3.4 for d in doors_z):
        node("JanelaCorredor%d" % k, "Node3D", J, {"transform": ident(-3.38, 5.6, z, yaw=90), "largura": "2.6", "altura": "1.3",
             "colunas": "4", "linhas": "1", "luz": "1" if k % 3 else "0"}, "v5_janela")
        k += 1
    z -= 4.2
# janelas altas no fundo de cada sala (luar entrando)
for rid, zc in (("Portugues", -18.75), ("Matematica", -47.95), ("Ciencias", -104.25), ("Geografia", -127.45), ("Musica", -175.0)):
    for j, dz in enumerate((-7.5, -2.5, 2.5, 7.5)):
        node("Janela%s%d" % (rid, j), "Node3D", J, {"transform": ident(-23.38, 5.75, zc + dz, yaw=90), "largura": "3.6", "altura": "1.4",
             "colunas": "4", "linhas": "1", "luz": "1"}, "v5_janela")

# ------------------------------------------------------------------ gravar
last_ext = [m.end() for m in re.finditer(r'(?m)^\[ext_resource[^\n]*\n', s)][-1]
s = s[:last_ext] + "".join(ext) + s[last_ext:]
first_node = s.index("[node ")
s = s[:first_node] + "".join(sub) + s[first_node:]
conn = s.find("\n[connection ")
ins = conn + 1 if conn >= 0 else len(s)
if not s[:ins].endswith("\n\n"):
    s = s[:ins] + "\n" + s[ins:]
    ins += 1
s = s[:ins] + "".join(nodes) + s[ins:]
open(SCENE, "w", encoding="utf-8").write(s)
print("ok: versão 5 aplicada (%d nós novos)" % len(nodes))

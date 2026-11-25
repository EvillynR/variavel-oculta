#!/usr/bin/env python3
"""Prompt 1 — gera scenes/main.tscn a partir da cena original (main_orig.tscn).
Reexecutável: sempre parte do original guardado no backup."""
import re, math

SRC = "/home/claude/main_orig.tscn"
DST = "/home/claude/vo/scenes/main.tscn"
s = open(SRC, encoding="utf-8").read()

MAT_FLOOR, MAT_CEIL, MAT_UP, MAT_LOW = '1_o6xl0', '2_tipki', '4_tipki', '5_85g3d'

# ---------------------------------------------------------------- utilitários
def blocks(text):
    """Divide em blocos que começam com '[' no início da linha."""
    parts = re.split(r'(?m)^(?=\[)', text)
    return parts

def remove_nodes(text, names_parents):
    out = []
    removed = set()
    for b in blocks(text):
        m = re.match(r'\[node name="([^"]+)"[^\]]*?parent="([^"]+)"', b)
        if m:
            name, parent = m.group(1), m.group(2)
            full = parent + "/" + name if parent != "." else name
            if (name, parent) in names_parents or any(parent == r or parent.startswith(r + "/") for r in removed):
                removed.add(full)
                continue
        out.append(b)
    missing = {f"{p}/{n}" for n, p in names_parents} - removed
    assert not missing, f"nós não encontrados: {missing}"
    return "".join(out)

def replace_in_node(text, name, parent, old, new):
    out = []
    hit = False
    for b in blocks(text):
        if re.match(r'\[node name="%s"[^\]]*parent="%s"' % (re.escape(name), re.escape(parent)), b):
            assert old in b, (name, old)
            b = b.replace(old, new); hit = True
        out.append(b)
    assert hit, (name, parent)
    return "".join(out)

def tf(x, y, z, basis="1, 0, 0, 0, 1, 0, 0, 0, 1"):
    return f"Transform3D({basis}, {x:.4f}, {y:.4f}, {z:.4f})"

ROT_Y90 = "-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08"
DOWN = "1, 0, 0, 0, -4.371139e-08, 1, 0, -1, -4.371139e-08"

nodes = []   # texto de nós novos (anexado ao fim)
subres = []  # sub_resources novos
extres = []  # ext_resources novos

def box(parent, name, x0, x1, y0, y1, z0, z1, mat=None, col=True, visible=True, basis=None):
    cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    lines = [f'[node name="{name}" type="CSGBox3D" parent="{parent}"]',
             f'transform = {tf(cx, cy, cz, basis) if basis else tf(cx, cy, cz)}']
    if not visible:
        lines.append("visible = false")
    if mat:
        lines.append(f'material_override = ExtResource("{mat}")')
    if col:
        lines.append("use_collision = true")
    lines.append(f"size = Vector3({abs(x1-x0):.4f}, {abs(y1-y0):.4f}, {abs(z1-z0):.4f})")
    nodes.append("\n".join(lines) + "\n\n")

def wall(parent, name, x0, x1, z0, z1, yf=0.0, top=7.0):
    """Parede no padrão da escola: rodapé de madeira, friso, reboco em cima."""
    along_x = abs(x1 - x0) > abs(z1 - z0)
    box(parent, name + "_Lower", x0, x1, yf, yf + 2.4, z0, z1, MAT_LOW)
    if along_x:
        box(parent, name + "_Trim", x0, x1, yf + 2.34, yf + 2.46, z0 - 0.05, z1 + 0.05, MAT_LOW)
    else:
        box(parent, name + "_Trim", x0 - 0.05, x1 + 0.05, yf + 2.34, yf + 2.46, z0, z1, MAT_LOW)
    box(parent, name + "_Upper", x0, x1, yf + 2.4, top, z0, z1, MAT_UP)

def node(name, parent, typ="Node3D", extra=""):
    nodes.append(f'[node name="{name}" type="{typ}" parent="{parent}"]\n{extra}\n')

def spot(parent, name, x, y, z, energy=5.0, rng=10.0, angle=70.0, color="0.78039217, 0.8509804, 0.9372549"):
    nodes.append(f'''[node name="{name}" type="SpotLight3D" parent="{parent}"]
transform = {tf(x, y, z, DOWN)}
light_color = Color({color}, 1)
light_energy = {energy}
light_cull_mask = 4294966273
shadow_enabled = true
shadow_blur = 1.5
spot_range = {rng}
spot_attenuation = 0.9
spot_angle = {angle}

''')

# ================================================================ 1. Sala 3 (nó Room 3)
# As 5 peças da "parede leste" eram redundantes (o Corridor3 já tem a parede
# oeste com o vão em z −94…−97) e fechavam o vão. Removidas.
s = remove_nodes(s, {(n, "School/Room 3") for n in [
    "WallEastLeft_Upper", "WallEastLeft_Lower", "WallEastRight_Upper", "WallEastRight_Lower", "WallEastDoorLintel"]})

# ================================================================ 2. Artes (nó Exit)
# Fecha os dois vãos oeste (davam para o vazio) e cria a parede leste com porta.
s = remove_nodes(s, {("WallDoorTop", "School/Exit"), ("WallDoorTop2", "School/Exit")})
wall("School/Exit", "WallWestFill1", -23.6, -23.4, -70.5, -63.5)
wall("School/Exit", "WallWestFill2", -23.6, -23.4, -78.5, -71.5)
wall("School/Exit", "WallEastA", -3.6, -3.4, -69.5, -58.4)
wall("School/Exit", "WallEastB", -3.6, -3.4, -83.6, -72.5)
box("School/Exit", "WallEastDoorTop", -3.6, -3.4, 5.0, 7.0, -72.5, -69.5, MAT_UP, col=False)
# Corredor do Exit: faltava a barreira leste invisível (x = 3), como nos outros.
box("School/Exit", "WallEastCorridor", 2.9, 3.1, 0.0, 4.5, -90.0, -52.5, col=True, visible=False)

# ================================================================ 3. Fim do Corredor 4 → passagem
s = remove_nodes(s, {(n, "School/Corridor4") for n in ["WallDoor_Upper", "WallDoor_Trim", "WallDoor_Lower"]})

# ================================================================ 4. Corredor 5 e Música
node("Corridor5", "School")
C5 = "School/Corridor5"
wall(C5, "JunctionLeft", -3.5, -2.0, -138.1, -137.9)
wall(C5, "JunctionRight", 2.0, 3.1, -138.1, -137.9)
box(C5, "JunctionTop", -2.0, 2.0, 5.0, 7.0, -138.1, -137.9, MAT_UP, col=False)
box(C5, "Floor", -3.5, 3.5, -0.2, 0.0, -190.0, -138.28, MAT_FLOOR)
box(C5, "Ceiling", -3.5, 3.5, 6.9, 7.1, -190.0, -138.07, MAT_CEIL)
box(C5, "WallEast", 2.9, 3.1, 0.0, 4.5, -190.0, -138.0, visible=False)
wall(C5, "WallWestA", -3.6, -3.4, -165.0, -138.0)
wall(C5, "WallWestB", -3.6, -3.4, -190.0, -185.0)
# Porta do subsolo (fim do corredor, z = −190).
wall(C5, "SubsoloDoorLeft", -3.5, -1.5, -190.1, -189.9)
wall(C5, "SubsoloDoorRight", 1.5, 3.5, -190.1, -189.9)
box(C5, "SubsoloDoorTop", -1.5, 1.5, 5.0, 7.0, -190.1, -189.9, MAT_UP, col=False)
for i, z in enumerate([-146.0, -160.0, -174.0, -186.0]):
    spot(C5, f"CorridorLight{i+1}", 0.0, 6.6, z)

# Música (filhos em coordenadas locais do nó MusicRoom, origem z = −175):
# paredes refeitas no padrão da escola, vão sul fechado e porta no lado leste.
s = remove_nodes(s, {(n, "School/MusicRoom") for n in [
    "MusicWallWest", "MusicWallEast", "MusicWallNorth", "MusicWallSouthLeft", "MusicWallSouthRight"]})
M = "School/MusicRoom"
wall(M, "WallWest", -23.6, -23.4, -10.0, 10.0)
wall(M, "WallNorth", -23.5, -3.5, -10.1, -9.9)
wall(M, "WallSouth", -23.5, -3.5, 9.9, 10.1)
wall(M, "WallEastA", -3.6, -3.4, 1.5, 10.0)       # z mundo −173,5 … −165
wall(M, "WallEastB", -3.6, -3.4, -10.0, -1.5)     # z mundo −185 … −176,5
box(M, "WallEastDoorTop", -3.6, -3.4, 5.0, 7.0, -1.5, 1.5, MAT_UP, col=False)
spot(M, "MusicLight1", -9.5, 6.6, 4.0, energy=8.0, rng=14.0, angle=72.0, color="0.76862746, 0.81960785, 0.8745098")
spot(M, "MusicLight2", -17.5, 6.6, -4.0, energy=8.0, rng=14.0, angle=72.0, color="0.76862746, 0.81960785, 0.8745098")

# ================================================================ 5. Subsolo e Sala de Monitoramento
node("Subsolo", "School")
SB = "School/Subsolo"
box(SB, "Landing", -3.5, 3.5, -0.2, 0.0, -192.0, -190.0, MAT_FLOOR)
# Rampa: de (z −192, y 0) a (z −210, y −6), inclinação 18,4°.
a = math.atan2(6.0, 18.0)
L = math.hypot(18.0, 6.0)
up = (0.0, math.cos(a), -math.sin(a))
ox, oy, oz = 0.0, -3.0 - 0.1 * up[1], -201.0 - 0.1 * up[2]
c, sn = math.cos(a), math.sin(a)
basis = f"1, 0, 0, 0, {c:.7f}, {sn:.7f}, 0, {-sn:.7f}, {c:.7f}"
nodes.append(f'''[node name="Ramp" type="CSGBox3D" parent="{SB}"]
transform = Transform3D({basis}, {ox:.4f}, {oy:.4f}, {oz:.4f})
material_override = ExtResource("{MAT_FLOOR}")
use_collision = true
size = Vector3(7, 0.2, {L:.4f})

''')
box(SB, "RampCeiling", -3.5, 3.5, 6.9, 7.1, -210.0, -190.0, MAT_CEIL)
box(SB, "RampWallWest", -3.6, -3.4, -6.0, 7.0, -210.0, -190.0, MAT_UP)
box(SB, "RampWallEast", 2.9, 3.1, -6.0, 4.5, -210.0, -190.0, visible=False)
box(SB, "RampHeader", -3.5, 3.5, 1.0, 7.0, -210.1, -209.9, MAT_UP)
# Corredor subterrâneo (piso y = −6, teto y = +1).
box(SB, "Floor", -3.5, 3.5, -6.2, -6.0, -228.0, -210.0, MAT_FLOOR)
box(SB, "Ceiling", -3.5, 3.5, 0.9, 1.1, -228.0, -210.0, MAT_CEIL)
box(SB, "WallEast", 2.9, 3.1, -6.0, -1.5, -228.0, -210.0, visible=False)
wall(SB, "WallWestA", -3.6, -3.4, -212.0, -210.0, -6.0, 1.0)
wall(SB, "WallWestB", -3.6, -3.4, -228.0, -226.0, -6.0, 1.0)
wall(SB, "WallEnd", -3.5, 3.5, -228.1, -227.9, -6.0, 1.0)
spot(SB, "RampLight", 0.0, 6.6, -199.0, energy=6.0, rng=15.0, angle=70.0)
spot(SB, "CorridorLight1", 0.0, 0.6, -215.0, energy=3.5, rng=8.0, angle=75.0, color="0.62, 0.78, 0.74")
spot(SB, "CorridorLight2", 0.0, 0.6, -224.0, energy=3.5, rng=8.0, angle=75.0, color="0.62, 0.78, 0.74")

node("SalaMonitoramento", "School")
SM = "School/SalaMonitoramento"
box(SM, "Floor", -17.5, -3.5, -6.2, -6.0, -226.0, -212.0, MAT_FLOOR)
box(SM, "Ceiling", -17.5, -3.5, 0.9, 1.1, -226.0, -212.0, MAT_CEIL)
wall(SM, "WallWest", -17.6, -17.4, -226.0, -212.0, -6.0, 1.0)
wall(SM, "WallSouth", -17.5, -3.5, -212.1, -211.9, -6.0, 1.0)
wall(SM, "WallNorth", -17.5, -3.5, -226.1, -225.9, -6.0, 1.0)
wall(SM, "WallEastA", -3.6, -3.4, -217.5, -212.0, -6.0, 1.0)
wall(SM, "WallEastB", -3.6, -3.4, -226.0, -220.5, -6.0, 1.0)
box(SM, "WallEastDoorTop", -3.6, -3.4, -1.0, 1.0, -220.5, -217.5, MAT_UP, col=False)
# Mobília da sala: mesa, console e cadeira (provisórios, com colisão).
box(SM, "Desk", -16.6, -15.2, -6.0, -5.1, -223.0, -215.0, "StandardMaterial3D_tefeu")
box(SM, "Console", -16.5, -15.9, -5.1, -4.8, -222.0, -216.0, "Mat_console")
box(SM, "Chair", -14.6, -13.9, -6.0, -5.4, -219.6, -218.4, "StandardMaterial3D_tefeu")
# Monitores: placas emissivas na parede oeste (2 fileiras × 3).
for row, y in enumerate([-4.4, -3.2]):
    for col, z in enumerate([-216.2, -219.0, -221.8]):
        nodes.append(f'''[node name="Monitor{row}{col}" type="MeshInstance3D" parent="{SM}"]
transform = {tf(-17.33, y, z)}
mesh = SubResource("Mesh_monitor")
surface_material_override/0 = SubResource("Mat_monitor{(row + col) % 2}")

''')
nodes.append(f'''[node name="MonitorGlow" type="OmniLight3D" parent="{SM}"]
transform = {tf(-15.5, -3.6, -219.0)}
light_color = Color(0.45, 0.7, 1, 1)
light_energy = 1.6
light_cull_mask = 4294966273
shadow_enabled = true
omni_range = 9.0

''')
spot(SM, "RoomLight", -10.5, 0.6, -219.0, energy=2.5, rng=8.0, angle=80.0, color="0.6, 0.72, 0.8")

subres.append('''[sub_resource type="BoxMesh" id="Mesh_monitor"]
size = Vector3(0.06, 0.95, 1.5)

[sub_resource type="StandardMaterial3D" id="Mat_monitor0"]
albedo_color = Color(0.05, 0.08, 0.1, 1)
emission_enabled = true
emission = Color(0.35, 0.62, 0.9, 1)
emission_energy_multiplier = 1.8

[sub_resource type="StandardMaterial3D" id="Mat_monitor1"]
albedo_color = Color(0.05, 0.08, 0.1, 1)
emission_enabled = true
emission = Color(0.42, 0.75, 0.66, 1)
emission_energy_multiplier = 1.4

[sub_resource type="StandardMaterial3D" id="Mat_console"]
albedo_color = Color(0.12, 0.13, 0.14, 1)
emission_enabled = true
emission = Color(0.9, 0.3, 0.25, 1)
emission_energy_multiplier = 0.4

''')

# Os ids "StandardMaterial3D_tefeu"/"Mat_console" são sub_resources, não ext.
for nm in ["StandardMaterial3D_tefeu", "Mat_console"]:
    nodes[:] = [n.replace(f'ExtResource("{nm}")', f'SubResource("{nm}")') for n in nodes]

# ================================================================ 6. Portas
extres.append('[ext_resource type="PackedScene" path="res://scenes/world/door.tscn" id="60_door"]\n')
node("Doors", "School")
NAV_CORR, NAV_SUB = 64, 128   # camadas 7 e 8
doors = [
    # nome, id, x, y, z, gira (parede ao longo de Z), swing, largura, link
    ("PortaInicial", "sala_inicial.porta", 0.0, 0.0, -4.0, False, 1.0, 3.0, NAV_CORR),
    ("PortaRoom1", "room_1.porta", -3.5, 0.0, -10.5, True, -1.0, 3.0, 1 | NAV_CORR),
    ("PortaRoom2", "room_2.porta", -3.5, 0.0, -40.5, True, -1.0, 3.0, 2 | NAV_CORR),
    ("PortaArtes", "room_3.porta", -3.5, 0.0, -71.0, True, -1.0, 3.0, 4 | NAV_CORR),
    ("PortaRoom3", "room_4.porta", -3.5, 0.0, -95.5, True, -1.0, 3.0, 8 | NAV_CORR),
    ("PortaRoom4", "room_5.porta", -3.5, 0.0, -119.9, True, -1.0, 3.0, 16 | NAV_CORR),
    ("PortaMusica", "room_6.porta", -3.5, 0.0, -175.0, True, -1.0, 3.0, 32 | NAV_CORR),
    ("PortaSubsolo", "sala_monitoramento.porta_subsolo", 0.0, 0.0, -190.0, False, -1.0, 3.0, NAV_CORR | NAV_SUB),
    ("PortaMonitoramento", "sala_monitoramento.porta", -3.5, -6.0, -219.0, True, -1.0, 3.0, NAV_SUB),
]
for name, did, x, y, z, rot, swing, w, link in doors:
    nodes.append(f'''[node name="{name}" parent="School/Doors" instance=ExtResource("60_door")]
transform = {tf(x, y, z, ROT_Y90) if rot else tf(x, y, z)}
door_id = &"{did}"
opening_width = {w}
swing_sign = {swing}
link_layers = {link}

''')

# ================================================================ 7. Volumes de sala
# Encolhe os volumes para x ≤ −4,1: a protagonista no corredor, encostada na
# soleira (cápsula de raio 0,25), não pode mais tocar o volume da sala.
for sid in ["room1volume", "room2volume", "exitvolume", "room3volume", "room4volume"]:
    s = re.sub(r'(\[sub_resource type="BoxShape3D" id="BoxShape3D_%s"\]\nsize = Vector3\()19\.8' % sid, r'\g<1>19.2', s)
for vol in ["Room1Volume", "Room2Volume", "ExitVolume", "Room3Volume", "Room4Volume"]:
    s = replace_in_node(s, "CollisionShape3D", "RoomVolumes/" + vol,
                        "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.25, 0)",
                        "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.2, 2.25, 0)")
s = replace_in_node(s, "CollisionShape3D", "RoomVolumes/MusicRoomVolume", "position = Vector3(0, 2.25, 0)", "position = Vector3(-0.2, 2.25, 0)")
s = re.sub(r'(\[sub_resource type="BoxShape3D" id="BoxShape3D_musicvolume"\]\nsize = Vector3\()[0-9.]+', r'\g<1>19.2', s)

subres.append('''[sub_resource type="BoxShape3D" id="BoxShape3D_monitorvolume"]
size = Vector3(13.2, 5.0, 13.6)

''')
nodes.append('''[node name="MonitoramentoVolume" type="Area3D" parent="RoomVolumes"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10.7, -6, -219)
collision_layer = 0
monitorable = false
script = ExtResource("42_roomvol")
room_id = &"sala_monitoramento"

[node name="CollisionShape3D" type="CollisionShape3D" parent="RoomVolumes/MonitoramentoVolume"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 2.5, 0)
shape = SubResource("BoxShape3D_monitorvolume")

''')

# ================================================================ 8. Navegação
s = replace_in_node(s, "MusicNavigation", "Navigation", "navigation_layers = 32", "navigation_layers = 32")
extres.append('[ext_resource type="NavigationMesh" path="res://data/navigation/corridors_navmesh.tres" id="61_corrnav"]\n')
extres.append('[ext_resource type="NavigationMesh" path="res://data/navigation/subsolo_navmesh.tres" id="62_subnav"]\n')
extres.append('[ext_resource type="NavigationMesh" path="res://data/navigation/initial_navmesh.tres" id="63_initnav"]\n')
nodes.append('''[node name="CorridorsNavigation" type="NavigationRegion3D" parent="Navigation"]
navigation_layers = 64
navigation_mesh = ExtResource("61_corrnav")

[node name="InitialNavigation" type="NavigationRegion3D" parent="Navigation"]
navigation_layers = 64
navigation_mesh = ExtResource("63_initnav")

[node name="SubsoloNavigation" type="NavigationRegion3D" parent="Navigation"]
navigation_layers = 128
navigation_mesh = ExtResource("62_subnav")

''')

# ================================================================ 9. Zonas de câmera
def zone(name, x0, x1, y0, y1, z0, z1, prio, blend, occl, offset="Vector3(9, 5.6, 0)", zmargin=0.4):
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    sid = "BoxShape3D_" + name.lower()
    subres.append(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({x1-x0:.2f}, {y1-y0:.2f}, {z1-z0:.2f})\n\n')
    occ = ", ".join(f'NodePath("../{p}")' for p in occl)
    nodes.append(f'''[node name="{name}" parent="." instance=ExtResource("3_sugp2")]
transform = {tf(cx, y0, cz)}
camera_priority = {prio}
camera_offset = {offset}
camera_fov = 38.0
blend_speed = {blend}
minimum_camera_z = {z0 + zmargin:.2f}
maximum_camera_z = {z1 - zmargin:.2f}
occluder_paths = Array[NodePath]([{occ}])

[node name="CollisionShape3D" parent="{name}" index="0"]
transform = {tf(0, (y1 - y0) / 2, 0)}
shape = SubResource("{sid}")

[node name="CameraPoint" parent="{name}" index="1"]
visible = false

''')

def w3(prefix):
    return [prefix + "_Upper", prefix + "_Trim", prefix + "_Lower"]

zone("Corridor5Camera", -3.5, 2.9, 0.0, 4.5, -190.0, -138.0, 3, 2.0,
     [f"{C5}/{p}" for p in w3("JunctionLeft") + w3("JunctionRight") + ["JunctionTop"] + w3("SubsoloDoorLeft") + w3("SubsoloDoorRight") + ["SubsoloDoorTop"]])
zone("MusicCamera", -23.4, -4.1, 0.0, 4.5, -184.8, -165.2, 5, 0.8,
     [f"{C5}/{p}" for p in w3("WallWestA") + w3("WallWestB")] + [f"{M}/{p}" for p in w3("WallEastA") + w3("WallEastB") + ["WallEastDoorTop"]])
zone("SubsoloRampCamera", -3.5, 2.9, -6.5, 4.5, -210.0, -190.2, 3, 2.0, [f"{C5}/{p}" for p in w3("SubsoloDoorLeft") + w3("SubsoloDoorRight") + ["SubsoloDoorTop"]] + [f"{SB}/RampHeader"])
zone("SubsoloCorridorCamera", -3.5, 2.9, -6.0, -1.5, -228.0, -210.1, 3, 2.0, [f"{SB}/RampHeader"] + [f"{SB}/{p}" for p in w3("WallEnd")])
zone("MonitoramentoCamera", -17.4, -4.1, -6.0, -1.5, -225.9, -212.1, 5, 0.8,
     [f"{SB}/{p}" for p in w3("WallWestA") + w3("WallWestB")] + [f"{SM}/{p}" for p in w3("WallEastA") + w3("WallEastB") + ["WallEastDoorTop"]])
# A ExitCamera (Artes) não tinha oclusores porque não havia parede leste.
exit_occl = ", ".join(f'NodePath("../School/Exit/{p}")' for p in w3("WallEastA") + w3("WallEastB") + ["WallEastDoorTop"])
s = replace_in_node(s, "ExitCamera", ".", "maximum_camera_z = -59.0\n", f"maximum_camera_z = -59.0\noccluder_paths = Array[NodePath]([{exit_occl}])\n")
# Corridor4Camera apontava para a parede do fim do corredor, agora removida.
s = re.sub(r'(\[node name="Corridor4Camera"[^\n]*\n(?:[^\[][^\n]*\n)*?)occluder_paths = [^\n]*\n',
           lambda m: m.group(1) + 'occluder_paths = Array[NodePath]([NodePath("../School/Corridor4/WallDoorLeft_Upper"), NodePath("../School/Corridor4/WallDoorLeft_Trim"), NodePath("../School/Corridor4/WallDoorLeft_Lower"), ' + ", ".join(f'NodePath("../{C5}/{p}")' for p in w3("JunctionLeft") + w3("JunctionRight") + ["JunctionTop"]) + '])\n', s, count=1)
# Os corredores Exit/3 passam a ver a nova parede leste da Artes como parede de sala.
# (ExitCorridorCamera: sem alteração — a parede nova fica do lado oposto à câmera.)

# ================================================================ 10. Piso de segurança
s = s.replace('[sub_resource type="BoxShape3D" id="BoxShape3D_fall_safety"]\nsize = Vector3(300, 1, 300)',
              '[sub_resource type="BoxShape3D" id="BoxShape3D_fall_safety"]\nsize = Vector3(300, 1, 400)')
s = replace_in_node(s, "FallSafety", ".", "position = Vector3(-10, -5, -40)", "position = Vector3(-10, -20, -100)")

# ================================================================ montagem
first_sub = s.index("[sub_resource")
s = s[:first_sub] + "".join(extres) + "\n" + s[first_sub:]
first_node = s.index("[node ")
s = s[:first_node] + "".join(subres) + s[first_node:]
s = s.rstrip("\n") + "\n\n" + "".join(nodes)
open(DST, "w", encoding="utf-8").write(s)
print("ok:", len(nodes), "blocos novos")

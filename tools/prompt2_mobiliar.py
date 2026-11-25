#!/usr/bin/env python3
"""Prompt 2 — instala os móveis na cena (a partir da cena do Prompt 1) e
cadastra os esconderijos no JSON. Reexecutável."""
import math, json, re
SRC = "/home/claude/p2b/main_p1.tscn"; DST = "/home/claude/p2/scenes/main.tscn"
JSRC = "/home/claude/p2b/game_data_p1.json"; JDST = "/home/claude/p2/data/game_data.json"
s = open(SRC, encoding="utf-8").read()

PROPS = ["Carteira", "Cadeira", "MesaProfessor", "QuadroNegro", "ArmarioAlto", "Estante", "Cavalete", "MapaMundi", "Globo",
         "Piano", "EstantePartitura", "BancadaLab", "QuadroAvisos", "Lixeira", "ArmariosAlunos", "MesaCartas", "Entulho"]
ext = "".join(f'[ext_resource type="PackedScene" path="res://scenes/props/{p.lower()}.tscn" id="p2_{p}"]\n' for p in PROPS)

def tf(x, y, z, yaw_deg=0.0, roll_deg=0.0):
    a = math.radians(yaw_deg); c, s_ = math.cos(a), math.sin(a)
    if roll_deg:
        r = math.radians(roll_deg); cr, sr = math.cos(r), math.sin(r)
        # Ry(a) * Rz(r)
        m = [[c*cr, -c*sr, s_], [sr, cr, 0], [-s_*cr, s_*sr, c]]
    else:
        m = [[c, 0, s_], [0, 1, 0], [-s_, 0, c]]
    # .tscn: linhas da base
    v = [m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]]
    return "Transform3D(" + ", ".join(f"{x_:.5f}" for x_ in v) + f", {x:.4f}, {y:.4f}, {z:.4f})"

nodes = ['[node name="Props" type="Node3D" parent="School"]\n\n']
counter = {}
hides = []   # (id, room, node path, tipo)
def area(name):
    nodes.append(f'[node name="{name}" type="Node3D" parent="School/Props"]\n\n')
def put(area_, prop, x, z, yaw=0.0, y=0.0, roll=0.0, spot=None, room=None):
    counter[prop] = counter.get(prop, 0) + 1
    name = f"{prop}{counter[prop]}"
    extra = ""
    if spot:
        extra = f'spot_id = &"{spot}"\n'
        if prop == "MesaProfessor":
            extra += 'hide_offset = Vector3(0, 0.05, 0.05)\nfront_offset = Vector3(0, 0.05, 1.25)\nlabel_text = "embaixo da mesa"\n'
        else:
            extra += 'label_text = "no armário"\n'
        hides.append((spot, room, f"School/Props/{area_}/{name}/Interactable", prop))
    nodes.append(f'[node name="{name}" parent="School/Props/{area_}" instance=ExtResource("p2_{prop}")]\ntransform = {tf(x, y, z, yaw, roll)}\n{extra}\n')

# ------------------------------------------------ sala inicial
area("SalaInicial")
put("SalaInicial", "Carteira", 0.0, 2.9, 180)        # a carteira onde ela acorda
for x, z in [(-3.5, -1.5), (-3.5, 1.8), (3.0, 1.8), (3.0, -1.2)]:
    put("SalaInicial", "Carteira", x, z, 180)
put("SalaInicial", "QuadroNegro", 0.0, 3.99, 180)
put("SalaInicial", "Lixeira", -5.4, 3.4)

# ------------------------------------------------ Room 1 — Ciências
area("Room1")
put("Room1", "QuadroNegro", -23.39, -18.7, 90)
# bancadas em ilha (a parede sul fica livre: tabela periódica e deslizar na parede)
# (as ilhas no meio da sala bloqueavam a rota de fuga do Polvo usada nos testes)
put("Room1", "BancadaLab", -18.0, -29.4, 0); put("Room1", "BancadaLab", -13.0, -29.4, 0)
put("Room1", "ArmarioAlto", -22.9, -26.5, 90, spot="room_1.esconderijo_armario", room="room_1")
put("Room1", "MesaProfessor", -22.4, -12.0, 90, spot="room_1.esconderijo_mesa", room="room_1")
put("Room1", "Lixeira", -5.0, -28.0)

# ------------------------------------------------ Room 2 — Matemática (fileiras)
area("Room2")
for x in [-9.0, -12.0, -17.0, -20.0]:
    for z in [-43.5, -44.5, -51.5, -52.5, -55.5, -56.5]:
        put("Room2", "Carteira", x, z, 90)
put("Room2", "QuadroNegro", -23.39, -48.0, 90)
put("Room2", "MesaProfessor", -22.4, -48.0, 90, spot="room_2.esconderijo_mesa", room="room_2")
put("Room2", "ArmarioAlto", -22.9, -39.5, 90, spot="room_2.esconderijo_armario", room="room_2")
put("Room2", "Lixeira", -5.0, -57.5)

# ------------------------------------------------ Artes (nó Exit) — parede oeste livre para as pinturas
area("Artes")
for x, z in [(-9.5, -63.5), (-17.0, -63.5), (-9.5, -78.5), (-17.0, -78.5), (-21.0, -66.5), (-21.0, -75.5)]:
    put("Artes", "Cavalete", x, z, 90)
put("Artes", "MesaCartas", -15.5, -75.5, 90)
put("Artes", "MesaProfessor", -13.0, -59.5, 180, spot="room_3.esconderijo_mesa", room="room_3")
put("Artes", "ArmarioAlto", -21.5, -82.9, 0, spot="room_3.esconderijo_armario", room="room_3")
put("Artes", "Lixeira", -5.0, -82.0)

# ------------------------------------------------ Room 3 — Português (estantes formando corredores)
area("Room3")
# fileiras com corredor livre a oeste (x < −18,4) e a leste (x > −13,4)
for z, yaw in [(-99.0, 0), (-109.0, 180)]:
    for x in [-17.2, -14.6]:
        put("Room3", "Estante", x, z, yaw)
for x in [-20.4, -17.8]:
    put("Room3", "Estante", x, -93.1, 180)
    put("Room3", "Estante", x, -115.5, 0)
put("Room3", "ArmarioAlto", -22.9, -104.0, 90, spot="room_4.esconderijo_armario", room="room_4")
put("Room3", "MesaProfessor", -17.5, -104.0, 90, spot="room_4.esconderijo_mesa", room="room_4")
put("Room3", "Lixeira", -5.0, -114.0)

# ------------------------------------------------ Room 4 — Geografia
area("Room4")
put("Room4", "MapaMundi", -23.39, -127.0, 90)
put("Room4", "MesaProfessor", -22.4, -127.0, 90, spot="room_5.esconderijo_mesa", room="room_5")
put("Room4", "Globo", -17.0, -122.0)
put("Room4", "MesaCartas", -17.5, -128.5, 90)
put("Room4", "Estante", -19.0, -137.3, 0)
put("Room4", "MapaMundi", -17.0, -117.02, 180)
put("Room4", "ArmarioAlto", -22.9, -135.3, 90, spot="room_5.esconderijo_armario", room="room_5")
put("Room4", "Lixeira", -5.0, -137.0)

# ------------------------------------------------ Música — piano e cadeiras em semicírculo
area("Musica")
put("Musica", "Piano", -21.8, -175.0, 90)
cx, cz = -19.8, -175.0
for a in [-70, -35, 0, 35, 70]:
    r = math.radians(a)
    x, z = cx + 3.2 * math.cos(r), cz + 3.2 * math.sin(r)
    # cadeira: encosto em +Z local; a pessoa olha para −Z local → vira para o centro
    yaw = math.degrees(math.atan2(x - cx, z - cz))
    put("Musica", "Cadeira", x, z, yaw)
    xs, zs = cx + 2.4 * math.cos(r), cz + 2.4 * math.sin(r)
    put("Musica", "EstantePartitura", xs, zs, yaw)
put("Musica", "Estante", -17.0, -184.6, 0)
put("Musica", "ArmarioAlto", -22.9, -168.0, 90, spot="room_6.esconderijo_armario", room="room_6")
put("Musica", "MesaProfessor", -12.0, -165.6, 180, spot="room_6.esconderijo_mesa", room="room_6")
put("Musica", "Lixeira", -5.0, -184.0)

# ------------------------------------------------ corredores: armários de alunos, avisos e entulho
area("Corredores")
for z in [-17.5, -22.5, -33.5, -47.0, -60.5, -80.0, -103.0, -108.5, -127.0, -132.5, -146.0, -152.0, -158.0, -168.5, -181.5]:
    put("Corredores", "ArmariosAlunos", -3.15, z, 90)
for z in [-14.8, -36.2, -99.8, -124.2, -149.0]:
    put("Corredores", "QuadroAvisos", -3.39, z, 90)
for (x, z, yaw) in [(2.2, -44.0, -35), (2.2, -62.0, 60), (2.0, -105.0, 10), (2.2, -155.0, -50)]:
    put("Corredores", "Entulho", x, z, yaw)
put("Corredores", "Cadeira", 1.8, -130.0, 30, y=0.22, roll=90)   # cadeira tombada
put("Corredores", "Lixeira", -2.7, -50.5)

# ------------------------------------------------ montagem da cena
first_sub = s.index("[sub_resource")
s = s[:first_sub] + ext + "\n" + s[first_sub:]
s = s.rstrip("\n") + "\n\n" + "".join(nodes)
open(DST, "w", encoding="utf-8").write(s)

# ------------------------------------------------ JSON: esconderijos + ruído
d = json.load(open(JSRC, encoding="utf-8"))
for sid, room, path, prop in hides:
    kind = "embaixo da mesa do professor" if prop == "MesaProfessor" else "dentro do armário alto"
    d["objects"].append({"id": sid, "room_id": room, "implementation": "FUNCTIONAL", "scene_node": path,
        "action": "esconder", "prompt": "E  Esconder-se", "effects": [],
        "notes": f"Prompt 2: esconderijo ({kind}). E entra; E de novo sai pela frente do móvel. Monstros só a enxergam escondida se a viram entrar."})
d["player_noise"] = {
    "walk": {"loudness": 0.55, "interval": 0.5},
    "run": {"loudness": 1.0, "interval": 0.35},
    "crouch": {"loudness": 0.15, "interval": 0.7},
    "notes": "[PROVISÓRIO] Prompt 2: passos da protagonista como SoundStimulus. Com a audição do Polvo (raio 8 m, limiar 0,25): correr é investigado até ~6 m, andar até ~3,3 m e agachada até ~0,9 m. Intervalo em segundos de jogo."
}
for r in d["rooms"]:
    r["pending_items"] = [p for p in r.get("pending_items", []) if not p.startswith("Móveis/objetos")]
    if not r["pending_items"]:
        r.pop("pending_items")
json.dump(d, open(JDST, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(JDST, "a").write("\n")
print("ok", sum(counter.values()), "móveis,", len(hides), "esconderijos")

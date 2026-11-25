#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera os dados da história a partir de tools/story_content.py.

Uso (na pasta do projeto):  python3 tools/build_story.py

Escreve:
  * data/game_data.json — salas, enigmas, pistas, eventos, objetos e monstros
    (mantém hearing_profiles, player_noise e o conteúdo de room_test usado
    pelos testes automáticos);
  * data/story.json     — roteiro das cenas, documentos e mapa;
  * scenes/main.tscn    — refaz o nó "Gameplay" (objetos interativos) e as
    posições/poses dos monstros. Pode ser rodado quantas vezes quiser.
"""
import json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import story_content as C  # noqa: E402

DATA = os.path.join(ROOT, "data", "game_data.json")
STORY = os.path.join(ROOT, "data", "story.json")
SCENE = os.path.join(ROOT, "scenes", "main.tscn")


TIER_NAMES = {1: "INITIAL", 2: "INTERMEDIATE", 3: "FINAL"}
ROOM_TIER = {r["id"]: r.get("tier", r.get("narrative_tier", 2)) for r in C.ROOMS}


_LAYOUT = json.load(open(os.path.join(HERE, "layout_anchors.json"), encoding="utf-8"))
ANCHORS = _LAYOUT["rooms"]
MARKER_SCALE = float(_LAYOUT.get("marker_scale", 1.0))   # objetos pequenos acompanham a escala dos móveis
ROOM_GROUP = {v["room_id"]: k for k, v in ANCHORS.items()}
CLASSROOMS = [r for r in C.ROOMS if r.get("kind", "CLASSROOM") == "CLASSROOM"]


def anchor(key):
    group, point = key.split(".")
    return group, ANCHORS[group]["anchors"][point]


def node_name(oid):
    return "".join(p.capitalize() for p in oid.split(".")[1].split("_"))


def obj_effects(o):
    eff = []
    if o.get("clue"):
        eff.append({"type": "reveal_clue", "clue_id": o["clue"]})
    if o.get("puzzle"):
        eff.append({"type": "open_puzzle", "puzzle_id": o["puzzle"]})
    if o.get("noisy"):
        room = next(r for r in CLASSROOMS if r["id"] == o["id"].split(".")[0])
        eff.append({"type": "activate_monster", "monster_id": room["monster_id"]})
    if o.get("music"):
        # versão 5.7: o piano pede a melodia ao professor (StoryDirector)
        eff.append({"type": "music_sequence", "room_id": o["music"]})
    return eff


def build_game_data():
    old = json.load(open(DATA, encoding="utf-8"))
    out = {
        "format_version": 1,
        "description": "Jogo de Yuko (escola japonesa) — pátio, 5 salas (Português e Música com professor; Matemática, Ciências e Geografia sem) e a saída no fim do corredor. Gerado por tools/build_story.py a partir de tools/story_content.py.",
        "final_destination_id": "sala_saida",
        "hearing_profiles": old["hearing_profiles"],
        "player_noise": old["player_noise"],
    }
    # ---------------- monstros
    monsters = []
    for mid, m in C.MONSTERS.items():
        entry = {"monster_id": mid}
        entry.update(m)
        awake = next((c["id"] for c in C.CUTSCENES if c.get("trigger") == "MONSTER_STATE" and c.get("trigger_id") == mid and c.get("trigger_state") == "AWAKENING"), None)
        if awake:
            entry["state_events"] = {"AWAKENING": awake}
        monsters.append(entry)
    out["monsters"] = monsters
    # ---------------- enigmas e pistas (+ conteúdo de teste)
    puzzles = [dict(p) for p in C.PUZZLES]
    puzzles += [p for p in old["puzzles"] if p.get("room_id") == "room_test"]
    out["puzzles"] = puzzles
    clues = []
    for c in C.CLUES:
        e = dict(c)
        if not e.get("puzzle_id"):
            e.pop("puzzle_id", None)
            e["narrative_tags"] = ["lore"]
        clues.append(e)
    clues += [c for c in old["clues"] if c.get("room_id") == "room_test"]
    out["clues"] = clues
    # ---------------- salas
    rooms = []
    for r in C.ROOMS:
        e = {"id": r["id"], "kind": r.get("kind", "CLASSROOM"), "display_name": r["display_name"],
             "content_status": r.get("content_status", "FINAL"), "geometry_status": "PHYSICAL",
             "scene_anchor": r["scene_anchor"]}
        if e["kind"] == "CLASSROOM":
            e.update({"order": r["order"], "subject": r["subject"], "puzzle_ids": [r["puzzle"]],
                      "clue_ids": [c["id"] for c in C.CLUES if c["room_id"] == r["id"]],
                      "required_puzzle_ids": [r["puzzle"]],
                      "exit_id": "%s_exit" % r["id"], "theme": r["theme"],
                      "connected_area_paths": ["School/Corridor"],
                      "connection_notes": "Porta %s na parede leste, para o corredor. Fecha atrás da Yuko ao entrar e ao sair." % r["door"],
                      "narrative_tier": r.get("tier", 2),
                      "exit_event_id": "nota_%s_fim" % r["id"]})
            if r.get("monster_id"):
                e["monster_id"] = r["monster_id"]
        else:
            e["narrative_tier"] = r.get("narrative_tier", 1)
            e["connected_area_paths"] = r.get("connected_area_paths", [])
            e["connection_notes"] = r.get("connection_notes", "")
        if r.get("nav_mesh"):
            e["navigation_layer"] = r["narrative_layer"]
            e["navigation_mesh"] = "res://data/navigation/%s.tres" % r["nav_mesh"]
            e["navigation_region_path"] = r["nav_region"]
        rooms.append(e)
    out["rooms"] = rooms
    # ---------------- eventos
    events = []
    for cs in C.CUTSCENES:
        if cs.get("director"):
            continue   # tocada pelo StoryDirector (pode repetir), não é evento
        e = {"id": cs["id"], "type": "CUTSCENE", "room_id": cs["room_id"], "content_status": "FINAL",
             "title": cs["title"], "trigger": cs["trigger"]}
        if cs.get("trigger_id"):
            e["trigger_id"] = cs["trigger_id"]
        if cs.get("trigger_state"):
            e["trigger_state"] = cs["trigger_state"]
        e["tier"] = TIER_NAMES[ROOM_TIER.get(cs["room_id"], 1)]
        if cs["id"] == "cena_final":
            e["required_rooms_completed"] = ["room_4"]
            e["reveals"] = ["voz_telefone", "vigilancia"]
        events.append(e)
    for d in C.DOCUMENTS:
        events.append({"id": d["id"], "type": "DOCUMENT", "room_id": d["room_id"], "content_status": "FINAL",
                       "title": d["title"], "lines": d["lines"], "trigger": "INTERACTION", "trigger_id": d["trigger_id"],
                       "tier": TIER_NAMES[ROOM_TIER[d["room_id"]]], "reveals": d.get("reveals", []), "once": False})
    # escritos do mapa ao sair de cada sala (evento de saída da sala)
    for r in CLASSROOMS:
        events.append({"id": "nota_%s_fim" % r["id"], "type": "NOTE", "room_id": r["id"], "content_status": "FINAL",
                       "speaker": C.MAPA, "title": "Escrito no mapa", "lines": C.MAP_NOTES_FLOW[r["id"]]["done"].split("\n"),
                       "trigger": "ROOM_COMPLETED", "trigger_id": r["id"], "tier": TIER_NAMES[ROOM_TIER[r["id"]]]})
    for e in events:
        if e.get("tier") == "FINAL" and not e.get("required_rooms_completed"):
            e["required_rooms_completed"] = ["room_4"]
    out["events"] = events
    # ---------------- objetos
    objects = []
    for o in C.OBJECTS:
        group, _ = anchor(o["anchor"])
        e = {"id": o["id"], "room_id": o["id"].split(".")[0], "implementation": "FUNCTIONAL",
             "scene_node": "Gameplay/%s/%s" % (group, node_name(o["id"])), "action": o["action"], "prompt": o["prompt"],
             "effects": obj_effects(o)}
        if o.get("noisy"):
            e["notes"] = "Pista barulhenta: acorda o professor da sala."
        if o.get("one_shot"):
            e["one_shot"] = True
        objects.append(e)
    for oid, (node, door, notes) in C.DOORS.items():
        objects.append({"id": oid, "room_id": oid.split(".")[0], "implementation": "FUNCTIONAL", "scene_node": node,
                        "action": "abrir", "prompt": "E  Abrir", "door": door, "effects": [], "notes": notes})
    # esconderijos (móveis gerados por tools/layout_moveis.py)
    for group, a in ANCHORS.items():
        for node, sid in zip(a["hiding"], a["hiding_ids"]):
            objects.append({"id": sid, "room_id": a["room_id"], "implementation": "FUNCTIONAL",
                            "scene_node": node, "action": "esconder", "prompt": "E  Esconder-se", "effects": [],
                            "notes": "Esconderijo. E entra; E de novo sai pela frente do móvel."})
    objects += [o for o in old["objects"] if o.get("room_id") == "room_test"]
    out["objects"] = objects
    json.dump(out, open(DATA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def build_room_flow():
    flow = {}
    nxt = {"room_1": "Vá para a Sala de Matemática (2ª porta).", "room_2": "Vá para o Laboratório de Ciências (passe pela porta do pátio).",
           "room_3": "Vá para a Sala de Geografia.", "room_4": "Vá para a Sala de Música (a última sala do corredor).",
           "room_5": "A saída: a porta no fim do corredor."}
    # Versão 5.4: o objetivo diz ONDE está a pergunta (a senha) de cada sala.
    pergunta = {"room_1": "o cadeado da gaveta da mesa da professora",
                "room_2": "o cofre de provas, embaixo da estante",
                "room_3": "o armário de reagentes lacrado",
                "room_4": "o mapa da cidade na parede",
                "room_5": "o teclado numérico ao lado da porta"}
    for r in CLASSROOMS:
        rid = r["id"]
        has_teacher = bool(r.get("monster_id"))
        cfg = {"door_id": "%s.porta" % rid, "monster_id": r.get("monster_id", ""), "puzzle_id": r["puzzle"],
               "noisy_object": r.get("noisy", ""), "notes": C.MAP_NOTES_FLOW[rid],
               "objective_search": "Procure as pistas (paredes, estantes e armários). A pergunta é %s." % pergunta[rid],
               "objective_hide": "Ele acordou! Esconda-se embaixo da mesa do professor e espere ele se acalmar.",
               "objective_answer": "Ele se acalmou. Agora abra %s (aperte E perto dele) e digite a resposta." % pergunta[rid],
               "objective_run": "A porta abriu sozinha. Corra!" if has_teacher else "A porta abriu. Pode sair.",
               "next_objective": nxt[rid]}
        if rid == "room_1":
            # versão 6.2: a Leitora (professora de Literatura que virou aranha)
            cfg["objective_hide"] = "Ela acordou! Esconda-se embaixo da mesa da professora e espere ela se acalmar."
            cfg["objective_answer"] = "Ela se acalmou. Agora abra %s (aperte E perto dele) e digite a resposta." % pergunta[rid]
        if rid in C.MUSIC_SEQUENCES:
            # versão 5.7: a pergunta é a melodia que o professor toca no piano
            cfg["objective_search"] = "Leia as pistas (lousa, partitura e bilhete) e depois peça para ele tocar o piano. A senha vai no teclado ao lado da porta."
            cfg["objective_hide"] = "Ele terminou de tocar e acordou! Esconda-se embaixo da mesa do professor e guarde a melodia na cabeça."
            cfg["objective_answer"] = "Ele se acalmou. Digite a melodia (o número de cada nota, na ordem) no teclado ao lado da porta."
            cfg["objective_wrong"] = "Desafinou! Ele ouviu o erro. Esconda-se e espere ele se acalmar para tentar de novo."
        if rid == "room_5":
            cfg["on_done"] = [{"type": "open_door", "door_id": "sala_saida.porta"}, {"type": "map_reveal", "area": "saida"}]
        flow[rid] = cfg
    return flow


def build_music():
    out = {}
    for rid, m in C.MUSIC_SEQUENCES.items():
        e = dict(m)
        e["notas"] = [dict(n, som="res://assets/audio/notas/%s.wav" % n["som"]) for n in m["notas"]]
        e["resposta_tamanho"] = len(C.music_answer(rid))
        out[rid] = e
    return out


def build_story_json():
    story = {
        "description": "Roteiro das cenas de filme, documentos, escritos do mapa e fluxo das salas. Gerado por tools/build_story.py.",
        "protagonist": C.PROTAGONISTA,
        "map_speaker": C.MAPA,
        # O checkpoint é sempre o último efeito: grava já com objetivo novo,
        # porta destrancada e monstro acordado.
        "cutscenes": {c["id"]: {"title": c["title"], "room_id": c["room_id"], "steps": c["steps"], "luz": c.get("luz", 1.0),
                                "effects": sorted(c.get("effects", []), key=lambda e: e["type"] in ("checkpoint", "end_game"))} for c in C.CUTSCENES},
        "documents": {d["id"]: {"after": [list(x) for x in d.get("after", [])]} for d in C.DOCUMENTS},
        "room_flow": build_room_flow(),
        "music_sequences": build_music(),
        "map": {"areas": C.MAP_AREAS, "targets": C.MAP_TARGETS},
    }
    json.dump(story, open(STORY, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


# ------------------------------------------------------------------ cena
# Marcadores pequenos, presos aos móveis (sem caixas brancas soltas):
# cor do material (albedo, emissão, energia) e forma por tipo.
VIS_COLORS = {
    # brilho bem fraco: com brilho forte o papel aparecia "flutuando" no
    # escuro quando o móvel em volta não estava iluminado
    "papel": ("0.66, 0.62, 0.52", "1, 0.93, 0.75", 0.06),
    "papel_parede": ("0.66, 0.62, 0.52", "1, 0.93, 0.75", 0.06),
    "livro": ("0.42, 0.14, 0.1", "0.9, 0.45, 0.3", 0.06),
    "cadeado": ("0.62, 0.5, 0.22", "1, 0.8, 0.35", 0.18),
    "mapa": ("0.7, 0.62, 0.45", "1, 0.85, 0.55", 0.1),
    "transferidor": ("0.45, 0.35, 0.22", "0.9, 0.75, 0.45", 0.0),
    "frascos": ("0.4, 0.75, 0.7", "0.5, 1, 0.9", 0.15),
    "rosa": ("0.55, 0.5, 0.42", "0.85, 0.8, 0.6", 0.05),
    "foto": ("0.6, 0.58, 0.52", "1, 1, 0.9", 0.06),
}
# monstros: posto (x, z, yaw) livre dos móveis 2x (entre a mesa do professor e as carteiras)
# versão 6.2.1: a Leitora fica na lousa, escrevendo (de costas para a sala)
MONSTER_HOMES = {"Leitor": (-22.3, -20.6, 90), "Maestro": (-15.0, -170.5, -90)}


def facing_basis(dx, dz):
    """Base com o +Z local virado para (dx, dz) no plano."""
    yaw = math.atan2(dx, dz)
    c, s_ = math.cos(yaw), math.sin(yaw)
    return (c, 0, s_, 0, 1, 0, -s_, 0, c)


def axis_to_face(b):
    """Gira o eixo Y da malha (cilindro/toro) para a direção da protagonista."""
    return (b[0], b[2], 0, 0, 0, -1, b[6], b[8], 0)


def marker_meshes(kind, size, face):
    """Lista (mesh_tscn, transform_local) para o marcador. face = (dx, dz) do móvel para a protagonista."""
    b = facing_basis(*face)
    out = []
    def box(w, h, d, x=0.0, y=0.0, z=0.0, basis=None):
        bb = basis or b
        return ('type="BoxMesh"', "size = Vector3(%.3f, %.3f, %.3f)" % (w, h, d), bb, (x, y, z))
    if kind == "papel":
        out.append(box(0.42, 0.012, 0.3, y=0.006))
    elif kind == "papel_parede":
        out.append(box(0.42, 0.56, 0.012))
    elif kind == "livro":
        out.append(box(0.36, 0.1, 0.5, y=0.05))
        out.append(box(0.34, 0.08, 0.46, y=0.13))
    elif kind == "cadeado":
        out.append(box(0.26, 0.3, 0.12))
        out.append(('type="TorusMesh"', "inner_radius = 0.07\nouter_radius = 0.1", axis_to_face(b), (0, 0.2, 0)))
    elif kind == "mapa":
        w, h, d = size
        out.append(box(w, h, d, y=h * 0.5))
    elif kind == "transferidor":
        # versão 5.6: transferidor de verdade (semicírculo com graus e o bilhete
        # preso com fita) — textura assets/textures/transferidor.png
        r = size[2] * 0.42
        out.append(('type="QuadMesh"', "size = Vector2(%.2f, %.2f)" % (2 * r, r), b, (0, 0, 0)))
    elif kind == "frascos":
        w = size[0]
        for i in range(4):
            x = -w * 0.38 + i * w * 0.25
            out.append(('type="CylinderMesh"', "top_radius = 0.07\nbottom_radius = 0.13\nheight = 0.42\nradial_segments = 12", b, (b[0] * x, 0.21, b[6] * x)))
    elif kind == "rosa":
        r = size[0] * 0.5
        out.append(('type="CylinderMesh"', "top_radius = %.2f\nbottom_radius = %.2f\nheight = 0.02\nradial_segments = 32" % (r, r), (1, 0, 0, 0, 1, 0, 0, 0, 1), (0, 0.01, 0)))
    elif kind == "foto":
        out.append(box(0.6, 0.45, 0.03))
    return out


def build_scene():
    s = open(SCENE, encoding="utf-8").read()
    def blocks(text):
        return re.split(r'(?m)^(?=\[)', text)
    def node_path(b):
        m = re.match(r'\[node name="([^"]+)"([^\]]*)\]', b)
        if not m:
            return None
        pm = re.search(r'parent="([^"]*)"', m.group(2))
        if not pm:
            return "."
        return m.group(1) if pm.group(1) == "." else pm.group(1) + "/" + m.group(1)
    def remove(text, roots):
        out = []
        for b in blocks(text):
            p = node_path(b)
            if p and any(p == r or p.startswith(r + "/") for r in roots):
                continue
            if re.match(r'\[sub_resource [^\]]*id="(StoryVis_|StoryMat_)', b):
                continue
            out.append(b)
        return "".join(out)
    s = remove(s, ["Gameplay"])

    subres = []
    nodes = []
    mats = {}
    for name, (albedo, emis, energy) in VIS_COLORS.items():
        mid = "StoryMat_" + name
        mats[name] = mid
        if name == "transferidor":
            subres.append('[sub_resource type="StandardMaterial3D" id="%s"]\ntransparency = 2\nalpha_scissor_threshold = 0.5\ncull_mode = 2\nalbedo_texture = ExtResource("tex_transferidor")\nalbedo_color = Color(0.85, 0.8, 0.7, 1)\nroughness = 0.6\nemission_enabled = true\nemission = Color(0.35, 0.3, 0.2, 1)\nemission_energy_multiplier = 0.25\nemission_texture = ExtResource("tex_transferidor")\n\n' % mid)
            continue
        subres.append('[sub_resource type="StandardMaterial3D" id="%s"]\nalbedo_color = Color(%s, 1)\nroughness = 0.8\nemission_enabled = true\nemission = Color(%s, 1)\nemission_energy_multiplier = %.2f\n\n' % (mid, albedo, emis, energy))
    nodes.append('[node name="Gameplay" type="Node3D" parent="."]\n\n')
    groups = []
    for o in C.OBJECTS:
        g = o["anchor"].split(".")[0]
        if g not in groups:
            groups.append(g)
    for g in groups:
        nodes.append('[node name="%s" type="Node3D" parent="Gameplay"]\n\n' % g)
    vis_i = 0
    for o in C.OBJECTS:
        group, a = anchor(o["anchor"])
        sx, _, sz = a["stand"]
        mx, my, mz = a["marker"]
        dx, dz = mx - sx, mz - sz
        d = math.hypot(dx, dz) or 1.0
        # Ponto de interação: um passo à frente de onde ela fica, no chão livre
        # (a linha de visão da interação nunca atravessa o móvel).
        ox, oz = sx + dx / d * 0.25, sz + dz / d * 0.25
        name = node_name(o["id"])
        parent = "Gameplay/%s" % group
        nodes.append('[node name="%s" type="Area3D" parent="%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.3f, 0.000, %.3f)\nscript = ExtResource("30_interact")\ninteraction_id = &"%s"\nprompt_height = 2.1\nmetadata/stand = Vector3(%.3f, 0, %.3f)\n\n' % (name, parent, ox, oz, o["id"], sx, sz))
        nodes.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="%s/%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)\nshape = SubResource("SphereShape3D_interact")\n\n' % (parent, name))
        kind = a.get("kind")
        if kind:
            follow = ""
            if a.get("item"):
                follow = 'script = ExtResource("fade_follow")\nfollow = NodePath("../../../../School/Props/%s/%s")\n' % (group, a["item"])
            for j, (mtype, mprops, basis, off) in enumerate(marker_meshes(kind, a.get("size"), (-dx, -dz))):
                k = MARKER_SCALE
                basis = tuple(v * k for v in basis)
                off = tuple(v * k for v in off)
                mid = "StoryVis_%d" % vis_i
                vis_i += 1
                subres.append('[sub_resource %s id="%s"]\n%s\n\n' % (mtype, mid, mprops))
                lx, ly, lz = mx - ox + off[0], my + off[1], mz - oz + off[2]
                nodes.append('[node name="Marcador%d" type="MeshInstance3D" parent="%s/%s"]\ntransform = Transform3D(%s, %.3f, %.3f, %.3f)\ncast_shadow = 0\nmesh = SubResource("%s")\nsurface_material_override/0 = SubResource("%s")\n%s\n'
                             % (j, parent, name, ", ".join("%.5f" % v for v in basis), lx, ly, lz, mid, mats[kind], follow))
    # versão 5.7: lousa que mostra as notas e o teclado numérico da porta
    for rid, m in C.MUSIC_SEQUENCES.items():
        group = ROOM_GROUP[rid]
        cx, cy, cz = m["lousa"]["centro"]
        nodes.append('[node name="LousaNotas" type="Node3D" parent="Gameplay/%s"]\ntransform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, %.3f, %.3f, %.3f)\nscript = ExtResource("lousa_notas")\nroom_id = "%s"\nlargura = %.2f\n\n' % (group, cx, cy, cz, rid, m["lousa"]["largura"]))
        tx, ty, tz = m["teclado"]["pos"]
        yaw = math.radians(m["teclado"]["yaw"])
        c, s_ = math.cos(yaw), math.sin(yaw)
        nodes.append('[node name="TecladoPorta" type="StaticBody3D" parent="Gameplay/%s" groups=["camera_fade"]]\ntransform = Transform3D(%.5f, 0, %.5f, 0, 1, 0, %.5f, 0, %.5f, %.3f, %.3f, %.3f)\ncollision_mask = 0\nscript = ExtResource("teclado_porta")\npuzzle_id = &"%s"\n\n' % (group, c, s_, -s_, c, tx, ty, tz, m["puzzle_id"]))
    for rid_, sid_ in (("lousa_notas", "res://scripts/world/lousa_notas.gd"), ("teclado_porta", "res://scripts/world/teclado_porta.gd")):
        if 'id="%s"' % rid_ not in s:
            last_ext = [mm.end() for mm in re.finditer(r'(?m)^\[ext_resource[^\n]*\n', s)][-1]
            s = s[:last_ext] + '[ext_resource type="Script" path="%s" id="%s"]\n' % (sid_, rid_) + s[last_ext:]
    if 'id="tex_transferidor"' not in s:
        last_ext = [m.end() for m in re.finditer(r'(?m)^\[ext_resource[^\n]*\n', s)][-1]
        s = s[:last_ext] + '[ext_resource type="Texture2D" path="res://assets/textures/transferidor.png" id="tex_transferidor"]\n' + s[last_ext:]
    if 'id="fade_follow"' not in s:
        last_ext = [m.end() for m in re.finditer(r'(?m)^\[ext_resource[^\n]*\n', s)][-1]
        s = s[:last_ext] + '[ext_resource type="Script" path="res://scripts/world/follow_fade.gd" id="fade_follow"]\n' + s[last_ext:]
    first_node = s.index("[node ")
    s = s[:first_node] + "".join(subres) + s[first_node:]
    conn = s.find("\n[connection ")
    insert_at = conn + 1 if conn >= 0 else len(s)
    if not s[:insert_at].endswith("\n\n"):
        s = s[:insert_at] + "\n" + s[insert_at:]
        insert_at += 1
    s = s[:insert_at] + "".join(nodes) + s[insert_at:]
    # monstros: posição de "casa" e para onde olham (cena de entrada)
    for name, (x, z, yaw) in MONSTER_HOMES.items():
        s, n = re.subn(r'(\[node name="%s" parent="MonsterRoster" instance=ExtResource\("33_monster"\)\]\n)(?:transform|position) = [^\n]*\n(rotation = [^\n]*\n)?' % name,
                       lambda m: m.group(1) + "position = Vector3(%.2f, 0, %.2f)\nrotation = Vector3(0, %.5f, 0)\n" % (x, z, math.radians(yaw)), s)
        assert n == 1, name
    open(SCENE, "w", encoding="utf-8").write(s)


if __name__ == "__main__":
    build_game_data()
    build_story_json()
    build_scene()
    print("ok: data/game_data.json, data/story.json, scenes/main.tscn")

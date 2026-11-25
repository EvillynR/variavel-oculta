#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Móveis em escala Little Nightmares (3x) + pontos de pista presos a eles.

Uso (na pasta do projeto):  python3 tools/layout_moveis.py

- Refaz os filhos de School/Props/<sala> em scenes/main.tscn (sala inicial,
  Português, Matemática, Ciências, Geografia, Saída e corredores).
- Confere que nenhum móvel invade outro, a parede ou a passagem da porta
  (o script PARA com erro se invadir).
- Grava tools/layout_anchors.json: para cada ponto de pista, onde a Yuko fica
  (stand) e onde o objeto aparece no móvel (marker). tools/build_story.py usa
  esses pontos para criar os objetos interativos.

Convenção: yaw em graus; a frente do móvel (+Z local) aponta para
(sin yaw, 0, cos yaw). yaw 90 = encostado na parede do fundo (oeste) olhando
para a câmera; 0 = encostado na parede sul (z menor); 180 = parede norte.
"""
import json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCENE = os.path.join(ROOT, "scenes", "main.tscn")
ANCHORS = os.path.join(HERE, "layout_anchors.json")

S = 3.0  # escala dos móveis (a Yuko tem ~1,70 m)
WALL_S = 2.0  # quadros e mapas de parede (em 3x passariam do teto de 7 m)
SMALL_S = 2.0  # corredor (entulho e armários de alunos): em 3x fecham o corredor de 7 m


def scale_of(kind):
    if kind in ("Relogio", "Escrivaninha"):
        return {"Relogio": S, "Escrivaninha": SMALL_S}[kind]
    return WALL_S if kind in WALL_ITEMS else (SMALL_S if kind in ("Entulho", "ArmariosAlunos") else S)

# Medidas reais dos móveis (Godot, sem escala): x0, x1, z0, z1, altura
FOOT = {
    "ArmarioAlto": (-0.55, 0.55, -0.38, 0.39, 2.30),
    "ArmariosAlunos": (-0.75, 0.73, -0.25, 0.26, 2.00),
    "BancadaLab": (-1.50, 1.50, -0.45, 0.45, 1.30),
    "Cadeira": (-0.22, 0.22, -0.22, 0.24, 0.90),
    "Carteira": (-0.50, 0.50, -0.30, 0.88, 0.90),
    "Entulho": (-0.60, 0.60, -0.25, 0.70, 0.45),
    "Estante": (-1.20, 1.20, -0.25, 0.25, 2.30),
    "EstantePartitura": (-0.25, 0.25, -0.20, 0.20, 1.40),
    "Piano": (-0.80, 0.80, -0.35, 0.25, 1.25),   # versão 5.8: sem o banquinho
    "Globo": (-0.35, 0.35, -0.34, 0.34, 0.9),    # versão 5.8: no chão, sem a mesinha
    "Lixeira": (-0.20, 0.20, -0.19, 0.19, 0.60),
    "MapaMundi": (-1.55, 1.55, -0.04, 0.03, 0.0),     # na parede (sem área no chão)
    "MapaCidade": (-1.55, 1.55, -0.04, 0.03, 0.0),    # versão 5.8: o mapa da cidade (quadriculado A–F × 1–6)
    "MesaCartas": (-1.20, 1.20, -0.70, 0.70, 0.89),
    "MesaProfessor": (-1.00, 1.00, -0.45, 0.45, 0.82),
    "QuadroAvisos": (-1.05, 1.05, -0.04, 0.03, 0.0),
    "QuadroNegro": (-2.05, 2.05, -0.04, 0.10, 0.0),
    # versão 5.4: modelos 3D enviados (scenes/props/*, tools/props_modelos.py)
    "BancadaPesquisa": (-0.86, 0.86, -0.32, 0.32, 0.97),
    "Escrivaninha": (-0.8, 0.8, -0.725, 0.725, 0.8),
    "EstanteAntiga": (-0.5, 0.5, -0.225, 0.225, 1.8),
    "Relogio": (-0.21, 0.21, -0.03, 0.03, 0.0),
    "PortaLaboratorio": (-0.54, 0.54, -0.06, 0.06, 0.0),
}
# Em cima de outro móvel (sem área no chão): calculadora, livros, frascos...
ON_TOP = {"Calculadora", "LivrosAntigos", "FrascoCiencia", "Vidrarias", "Cranio", "Cantigas"}
WALL_ITEMS = {"MapaMundi", "MapaCidade", "QuadroAvisos", "QuadroNegro", "Relogio", "PortaLaboratorio"}
# Versão 5.4: ela só se esconde embaixo da mesa do professor (os armários são só móveis).
HIDING = {"MesaProfessor": ("mesa", "embaixo da mesa", ((0, 0.05, 0.05), (0, 0.05, 0.75)))}

# Cômodos: faces internas das paredes e a porta (parede leste x = -3.5)
ROOMS = {
    "Portugues": dict(room="room_1", x0=-23.4, x1=-3.6, z0=-30.0, z1=-7.5, door_z=-10.5),
    "Matematica": dict(room="room_2", x0=-23.4, x1=-3.6, z0=-58.4, z1=-37.5, door_z=-40.5),
    "Ciencias": dict(room="room_3", x0=-23.4, x1=-3.6, z0=-116.1, z1=-92.4, door_z=-95.5),
    "Geografia": dict(room="room_4", x0=-23.4, x1=-3.6, z0=-137.9, z1=-117.0, door_z=-119.9),
    "Musica": dict(room="room_5", x0=-23.4, x1=-3.6, z0=-184.9, z1=-165.1, door_z=-175.0),
    # pátio a céu aberto (antiga 3ª sala); porta para o corredor em z -71
    "Patio": dict(room="patio", x0=-23.4, x1=-3.6, z0=-83.4, z1=-58.6, door_z=-71.0),
    # sala dos monitores no fim do corredor (porta na parede norte, z -190)
    "Saida": dict(room="sala_saida", x0=-5.9, x1=5.9, z0=-197.9, z1=-190.1, door_z=None),
}


def footprint(kind, x, z, yaw):
    x0, x1, z0, z1, _ = FOOT[kind]
    k = scale_of(kind)
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    pts = []
    for lx in (x0 * k, x1 * k):
        for lz in (z0 * k, z1 * k):
            pts.append((x + c * lx + s * lz, z - s * lx + c * lz))
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    return (min(xs), max(xs), min(zs), max(zs))


def world(x, y, z, yaw, lx, ly, lz, k=None):
    """Ponto local do móvel (medidas sem escala) -> mundo."""
    k = S if k is None else k
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return (x + (c * lx + s * lz) * k, y + ly * k, z + (-s * lx + c * lz) * k)


class Room:
    def __init__(self, name):
        self.name = name
        self.r = ROOMS[name]
        self.items = []
        self.anchors = {}
        self.counter = {}

    def add(self, kind, x, z, yaw, name=None, y=0.0):
        self.counter[kind] = self.counter.get(kind, 0) + 1
        name = name or "%s%d" % (kind, self.counter[kind])
        self.items.append(dict(kind=kind, name=name, x=x, y=y, z=z, yaw=yaw))
        return self.items[-1]

    def anchor(self, key, stand, marker, kind="papel", size=None, item=None):
        """stand = (x, z) onde ela fica; marker = (x, y, z) do objeto no móvel."""
        self.anchors[key] = dict(stand=[round(stand[0], 3), 0.0, round(stand[1], 3)],
                                 marker=[round(v, 3) for v in marker], kind=kind, size=size,
                                 item=item["name"] if item else None)

    def pin(self, key, item, local, kind="papel", size=None, side="front", gap=0.6):
        """Pista presa a um móvel: `local` = ponto no móvel (medidas sem escala).
        A Yuko fica `gap` metros fora da face `side` (front/back/left/right)."""
        k = scale_of(item["kind"])
        x0, x1, z0, z1, _ = FOOT[item["kind"]]
        lx, ly, lz = local
        face = {"front": (lx, z1, (0, 1)), "back": (lx, z0, (0, -1)), "left": (x0, lz, (-1, 0)), "right": (x1, lz, (1, 0))}[side]
        if side in ("front", "back"):
            px, pz = face[0], face[1]
        else:
            px, pz = face[0], face[1]
        wx, _, wz = world(item["x"], 0, item["z"], item["yaw"], px, 0, pz, k)
        dx, _, dz = world(0, 0, 0, item["yaw"], face[2][0], 0, face[2][1], 1.0)
        marker = world(item["x"], item.get("y", 0.0), item["z"], item["yaw"], lx, ly, lz, k)
        self.anchor(key, (wx + dx * gap, wz + dz * gap), marker, kind, size, item)

    def check(self):
        r = self.r
        rects = []
        for it in self.items:
            if it["kind"] in WALL_ITEMS or it["kind"] in ON_TOP:
                continue
            fx0, fx1, fz0, fz1 = footprint(it["kind"], it["x"], it["z"], it["yaw"])
            if fx0 < r["x0"] - 0.01 or fx1 > r["x1"] + 0.01 or fz0 < r["z0"] - 0.01 or fz1 > r["z1"] + 0.01:
                raise SystemExit("ERRO %s/%s fora da sala: x %.2f..%.2f z %.2f..%.2f" % (self.name, it["name"], fx0, fx1, fz0, fz1))
            if r["door_z"] is not None and fx1 > r["x1"] - 4.2 and fz1 > r["door_z"] - 3.0 and fz0 < r["door_z"] + 3.0:
                raise SystemExit("ERRO %s/%s bloqueia a porta" % (self.name, it["name"]))
            for other, orect in rects:
                if fx0 < orect[1] + 0.25 and fx1 > orect[0] - 0.25 and fz0 < orect[3] + 0.25 and fz1 > orect[2] - 0.25:
                    raise SystemExit("ERRO %s: %s invade %s" % (self.name, it["name"], other))
            rects.append((it["name"], (fx0, fx1, fz0, fz1)))
        # versão 5.4: enfeite (calculadora, livros, frascos...) não pode cobrir o marcador de uma pista
        for it in self.items:
            if it["kind"] not in ON_TOP:
                continue
            for key, a in self.anchors.items():
                mx, my, mz = a["marker"]
                if abs(mx - it["x"]) < 1.3 and abs(mz - it["z"]) < 1.3 and abs(my - it.get("y", 0.0)) < 1.0:
                    raise SystemExit("ERRO %s: %s cobre a pista %s" % (self.name, it["name"], key))
        # pontos onde a Yuko fica não podem cair dentro de móvel
        for key, a in self.anchors.items():
            sx, _, sz = a["stand"]
            for other, (fx0, fx1, fz0, fz1) in rects:
                if fx0 - 0.3 < sx < fx1 + 0.3 and fz0 - 0.3 < sz < fz1 + 0.3:
                    raise SystemExit("ERRO %s: ponto %s dentro de %s" % (self.name, key, other))
        return len(rects)


def on_top(room, kind, item, local, yaw_extra=0, name=None):
    """Objeto em cima de um móvel: `local` = ponto do tampo (medidas sem escala)."""
    k = scale_of(item["kind"])
    x, y, z = world(item["x"], item.get("y", 0.0), item["z"], item["yaw"], local[0], local[1], local[2], k)
    return room.add(kind, x, z, item["yaw"] + yaw_extra, name=name, y=y)


def back(room, kind, z, yaw=90, gap=0.05, name=None):
    """Encostado na parede do fundo (oeste)."""
    x0 = FOOT[kind][2] * scale_of(kind)   # -z local vira -x mundo (yaw 90)
    return room.add(kind, room.r["x0"] - x0 + gap, z, yaw, name=name)


def south(room, kind, x, gap=0.05, name=None):
    return room.add(kind, x, room.r["z0"] - FOOT[kind][2] * scale_of(kind) + gap, 0, name=name)


def north(room, kind, x, gap=0.05, name=None):
    return room.add(kind, x, room.r["z1"] + FOOT[kind][2] * scale_of(kind) - gap, 180, name=name)


# Alturas úteis dos móveis (medidas sem escala): prateleiras da estante
# 0,09 / 0,64 / 1,19 / 1,74; tampo da carteira 0,745 (z -0,3..0,3); tampo da
# mesa do professor 0,82; mesa de cartas 0,88; bancada 0,96.
SHELF = (0.09, 0.64, 1.19, 1.74)


def build_rooms():
    rooms = {}
    # ------------------------------------------------ Pátio (onde ela acorda)
    # Cenário do pátio (cerejeira, lanternas, banco, entulho) é montado por
    # tools/restructure_v5.py; aqui só o quadro de avisos e os pontos de pista.
    R = Room("Patio")
    R.add("QuadroAvisos", -9.0, -58.62, 180, name="QuadroAvisos")
    # mapa em cima do banco (assento a 1,42 m; o encosto fica no -z)
    R.anchor("mapa", (-11.0, -76.3), (-11.0, 1.43, -77.55), "mapa", (0.7, 0.03, 0.55))
    R.anchor("bilhete", (-9.0, -60.7), (-9.0, 2.9, -58.75), "papel_parede")
    rooms[R.name] = R
    # ------------------------------------------------ Português
    R = Room("Portugues")
    zm = -18.75
    R.add("QuadroNegro", -23.38, zm, 90, name="QuadroNegro")
    # versão 6.2.1: a mesa saiu da frente do quadro e foi para o canto (perto do
    # armário), para a Leitora ficar escrevendo na lousa
    mesa = R.add("MesaProfessor", -19.4, -25.3, 90)
    back(R, "ArmarioAlto", -27.6)
    est_fundo = back(R, "Estante", -11.5, name="EstanteFundo")
    est_sul = south(R, "Estante", -14.0, name="EstanteSul")
    est_norte = north(R, "Estante", -17.0, name="EstanteNorte")
    for x in (-15.5, -10.0):
        for z in (-24.5, -18.0):
            R.add("Carteira", x, z, 90)
    R.anchor("quadro", (-18.0, -14.6), (-23.2, 3.4, zm), None)
    R.pin("caderno", est_norte, (-1.5, SHELF[1], 0.05), "livro")
    R.pin("livro_preso", est_sul, (1.0, SHELF[2], 0.1), "livro")
    R.pin("gaveta", mesa, (1.0, 0.63, 0.2), "cadeado", side="right")
    R.pin("chamada", est_fundo, (0.8, 1.0, 0.27), "papel_parede")
    on_top(R, "LivrosAntigos", mesa, (-0.55, 0.82, 0.0))
    rooms[R.name] = R
    # ------------------------------------------------ Matemática
    R = Room("Matematica")
    zm = -47.95
    R.add("QuadroNegro", -23.38, zm, 90, name="QuadroNegro")
    mesa = back(R, "MesaProfessor", zm, gap=1.5)
    back(R, "ArmarioAlto", -56.3)
    est_sul = south(R, "Estante", -13.0, name="EstanteSul")
    est_norte = north(R, "Estante", -17.4, name="EstanteNorte")
    carteiras = {}
    for x in (-15.5, -10.0):
        for z in (-53.0, -46.5):
            carteiras[(x, z)] = R.add("Carteira", x, z, 90)
    R.anchor("quadro", (-18.0, -43.8), (-23.2, 3.4, zm), None)
    R.pin("prova", carteiras[(-15.5, -46.5)], (0.0, 0.745, -0.05), "papel", side="back")
    R.pin("comanda", est_norte, (-0.8, 1.4, 0.27), "papel_parede")
    R.anchor("transferidor", (-21.0, -41.5), (-23.3, 3.6, -41.5), "transferidor", (0.1, 2.4, 4.0))
    R.pin("cofre", est_sul, (-1.0, 0.35, 0.27), "cadeado")
    on_top(R, "Calculadora", mesa, (-0.6, 0.82, 0.05), yaw_extra=-20)
    R.add("Relogio", -23.36, zm, 90, name="Relogio", y=5.2)
    R.pin("diario", mesa, (0.5, 0.82, 0.1), "livro")
    rooms[R.name] = R
    # ------------------------------------------------ Ciências
    R = Room("Ciencias")
    zm = -104.25
    R.add("QuadroNegro", -23.38, zm, 90, name="QuadroNegro")
    mesa = back(R, "MesaProfessor", zm, gap=1.5)
    back(R, "ArmarioAlto", -113.8)
    banc1 = R.add("BancadaLab", -14.5, -108.0, 90)
    banc2 = R.add("BancadaLab", -9.5, -101.0, 90)
    est_norte = north(R, "Estante", -18.0, name="EstanteNorte")
    pesquisa = R.add("BancadaPesquisa", -6.2, -112.3, 90)
    R.add("PortaLaboratorio", -23.34, -96.6, 90, name="PortaLaboratorio")
    on_top(R, "FrascoCiencia", banc1, (-1.0, 0.96, 0.15))
    on_top(R, "Vidrarias", banc2, (0.0, 0.96, -0.1))
    on_top(R, "Cranio", pesquisa, (0.35, 0.97, 0.0), yaw_extra=-60)
    est_sul = south(R, "Estante", -12.0, name="EstanteSul")
    R.add("QuadroAvisos", -19.0, -116.06, 0, name="CartazPH")
    R.anchor("cartaz_ph", (-19.0, -113.8), (-19.0, 3.2, -115.9), None)
    R.pin("caderno", banc1, (1.0, 0.96, 0.0), "livro")
    R.pin("frascos", est_norte, (0.0, SHELF[1], 0.0), "frascos", (1.6, 0.5, 0.5))
    R.pin("armario_reagentes", est_sul, (0.8, 0.35, 0.27), "cadeado")
    R.pin("relatorio", mesa, (-0.5, 0.82, 0.1), "papel")
    rooms[R.name] = R
    # ------------------------------------------------ Geografia
    R = Room("Geografia")
    zm = -127.45
    R.add("MapaMundi", -23.2, zm, 90, name="MapaMundi")   # versão 5.8: na frente do friso da parede
    back(R, "MesaProfessor", zm, gap=1.5)
    back(R, "ArmarioAlto", -135.4)
    cartas = R.add("MesaCartas", -13.5, -128.0, 90)
    globo = R.add("Globo", -8.5, -133.5, 90)
    south(R, "Estante", -17.0, name="EstanteSul")
    est_norte = north(R, "Estante", -17.6, name="EstanteNorte")
    north(R, "EstanteAntiga", -10.0, name="EstanteAntiga")
    # Versão 5.8: o mapa da cidade vai para a parede do fundo (oeste), de frente
    # para a câmera — na parede sul ele ficava de lado e atrás do globo.
    R.add("MapaCidade", -23.2, -121.0, 90, name="MapaCidade", y=-0.8)
    R.anchor("rosa", (-9.0, -124.0), (-9.0, 0.01, -125.5), "rosa", (2.4, 0.02, 2.4))
    R.pin("plano", cartas, (0.5, 0.88, 0.0), "papel")
    R.anchor("globo", (-6.85, -133.5), (-8.5, 2.0, -133.5), None, item=globo)
    R.anchor("mapa_cidade", (-20.6, -121.0), (-23.3, 2.8, -121.0), None)
    R.pin("foto", est_norte, (0.5, 1.3, 0.27), "foto")
    rooms[R.name] = R
    # ------------------------------------------------ Música (2ª sala com professor: o Maestro)
    R = Room("Musica")
    zm = -175.0
    R.add("QuadroNegro", -23.38, zm, 90, name="QuadroNegro")
    mesa = back(R, "MesaProfessor", zm, gap=1.5)
    # o armário de partituras (só móvel desde a versão 5.7)
    arm_part = back(R, "ArmarioAlto", -168.5, name="ArmarioPartituras")
    piano_it = R.add("Piano", -15.5, -183.8, 0, name="Piano")
    on_top(R, "Cantigas", piano_it, (0.35, 1.25, -0.12))
    R.add("Escrivaninha", -20.7, -181.5, 90, name="Escrivaninha")
    est_norte = north(R, "Estante", -15.5, name="EstanteNorte")
    pautas = [R.add("EstantePartitura", x, z, 90) for x, z in ((-13.0, -177.5), (-13.0, -172.0), (-9.0, -177.5), (-9.0, -181.5))]
    for x, z in ((-10.0, -169.5), (-6.5, -181.5)):
        R.add("Cadeira", x, z, 90)
    piano = next(it for it in R.items if it["name"] == "Piano")
    R.anchor("quadro", (-18.0, -170.4), (-23.2, 3.4, zm), None)
    R.pin("partitura", pautas[0], (0.0, 1.25, 0.05), "papel_parede")
    R.pin("piano", piano, (0.0, 0.8, 0.33), None)
    R.pin("bilhete", est_norte, (-1.0, 1.0, 0.27), "papel_parede")
    # Versão 5.7: a pergunta é o teclado numérico ao lado da porta (o pedestal
    # é montado por scripts/world/teclado_porta.gd; ela fica do lado leste, de
    # frente para ele e com a câmera atrás dela).
    R.anchor("teclado", (-6.25, -178.4), (-7.6, 1.3, -178.4), None)
    R.pin("programa", mesa, (0.5, 0.82, 0.1), "papel")
    rooms[R.name] = R
    # ------------------------------------------------ Saída: sala dos monitores (fim do corredor)
    # A mesa dos monitores é CSG (tools/restructure_v5.py): x -5,8..-3,6, tampo a 2,2 m.
    R = Room("Saida")
    south(R, "ArmarioAlto", 3.5)
    R.anchor("ficha", (-2.9, -191.9), (-4.2, 2.21, -192.4), "papel")
    rooms[R.name] = R
    return rooms


def corridor_items():
    """Corredor: armários de alunos e quadros de aviso na parede das salas
    (oeste), entre as portas; escala 2x."""
    items = []
    # versão 5.8: o 2º saía de -28 (atravessava a pilastra da porta, z -28,5..-28,3)
    lock_z = [-17.5, -25.6, -33.5, -50.0, -64.0, -79.5, -87.0, -106.0, -111.5, -130.0, -145.0, -155.0, -186.0]
    for i, z in enumerate(lock_z):
        items.append(dict(kind="ArmariosAlunos", name="ArmariosAlunos%d" % (i + 1), x=-3.4 + 0.26 * scale_of("ArmariosAlunos") + 0.05, y=0.0, z=z, yaw=90))
    for i, z in enumerate([-21.0, -46.5, -101.0, -160.0]):
        items.append(dict(kind="QuadroAvisos", name="QuadroAvisos%d" % (i + 1), x=-3.39, y=0.0, z=z, yaw=90))
    for i, (x, z) in enumerate([(2.2, -60.0), (2.3, -140.0), (1.8, -172.0)]):
        items.append(dict(kind="Entulho", name="Entulho%d" % (i + 1), x=x, y=0.0, z=z, yaw=-90))
    return items


def xform(it):
    k = scale_of(it["kind"])
    c, s = math.cos(math.radians(it["yaw"])), math.sin(math.radians(it["yaw"]))
    return "Transform3D(%.5f, 0, %.5f, 0, %.5f, 0, %.5f, 0, %.5f, %.4f, %.4f, %.4f)" % (
        c * k, s * k, k, -s * k, c * k, it["x"], it.get("y", 0.0), it["z"])


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


def main():
    rooms = build_rooms()
    total = 0
    for R in rooms.values():
        total += R.check()
    s = open(SCENE, encoding="utf-8").read()
    containers = list(rooms.keys()) + ["Corredores"]
    # remove os filhos atuais dos contêineres (e o contêiner Saida, se já existir)
    out = []
    for b in blocks(s):
        p = node_path(b)
        if p and any(p == "School/Props/%s" % c or p.startswith("School/Props/%s/" % c) for c in containers):
            continue
        # salas que deixaram de existir (versão 5: a salinha inicial)
        if p and (p == "School/Props/SalaInicial" or p.startswith("School/Props/SalaInicial/")):
            continue
        out.append(b)
    s = "".join(out)
    new = ['[node name="%s" type="Node3D" parent="School/Props"]\n\n' % c for c in containers]
    hiding_report = {}
    for R in rooms.values():
        for it in R.items:
            new.append('[node name="%s" parent="School/Props/%s" instance=ExtResource("p2_%s")]\ntransform = %s\n' % (it["name"], R.name, it["kind"], xform(it)))
            if it["kind"] in HIDING:
                kind, label, offs = HIDING[it["kind"]]
                sid = "%s.esconderijo_%s" % (R.r["room"], kind)
                n = hiding_report.setdefault(sid, 0) + 1
                hiding_report[sid] = n
                if n > 1:
                    sid += str(n)
                new.append('spot_id = &"%s"\n' % sid)
                if offs:
                    new.append("hide_offset = Vector3(%g, %g, %g)\nfront_offset = Vector3(%g, %g, %g)\n" % (offs[0] + offs[1]))
                new.append('label_text = "%s"\n' % label)
                it["spot_id"] = sid
            new.append("\n")
    for it in corridor_items():
        new.append('[node name="%s" parent="School/Props/Corredores" instance=ExtResource("p2_%s")]\ntransform = %s\n\n' % (it["name"], it["kind"], xform(it)))
    # ext_resource de cada tipo de móvel usado (versão 5.4: tipos novos)
    kinds = sorted({it["kind"] for R in rooms.values() for it in R.items} | {it["kind"] for it in corridor_items()})
    last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', s)][-1]
    add = ""
    for kd in kinds:
        if 'id="p2_%s"' % kd not in s:
            add += '[ext_resource type="PackedScene" path="res://scenes/props/%s.tscn" id="p2_%s"]\n' % (kd.lower(), kd)
    s = s[:last] + add + s[last:]
    conn = s.find("\n[connection ")
    ins = conn + 1 if conn >= 0 else len(s)
    s = s[:ins] + "".join(new) + s[ins:]
    open(SCENE, "w", encoding="utf-8").write(s)
    data = {"scale": S, "marker_scale": S / 2.0, "rooms": {}}
    for R in rooms.values():
        data["rooms"][R.name] = {"room_id": R.r["room"], "anchors": R.anchors,
                                 "hiding": ["School/Props/%s/%s/Interactable" % (R.name, it["name"]) for it in R.items if it.get("spot_id")],
                                 "hiding_ids": [it["spot_id"] for it in R.items if it.get("spot_id")]}
    json.dump(data, open(ANCHORS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ok: %d móveis no chão sem sobreposição; %d pontos de pista" % (total, sum(len(R.anchors) for R in rooms.values())))


if __name__ == "__main__":
    main()

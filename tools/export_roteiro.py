#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera docs/ROTEIRO.md (leitura da equipe) a partir de tools/story_content.py.
Uso: python3 tools/export_roteiro.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import story_content as C  # noqa: E402

out = []
w = out.append
w("# Roteiro — a história de Yuko\n")
w("Gerado de `tools/story_content.py` (edite lá e rode `python3 tools/build_story.py` e `python3 tools/export_roteiro.py`).\n")
w("**Ordem do jogo:** acorda no pátio (escola japonesa, à noite, debaixo da cerejeira) → mapa (o que estava escrito nele começa a mudar) → Português → Matemática → Ciências → Geografia → Música → a saída (salinha no fim do corredor) → final.\n")
w("**Não há voz.** Tudo o que \"alguém\" diz aparece **escrito no mapa** (em letra que não é da Yuko), marcado abaixo como **Mapa**. Com o mapa fechado, a frase surge num pedaço de pergaminho no alto da tela.\n")
w("**Só duas salas têm professor: Português (a primeira) e Música (a última).** Nelas: entra → a porta fecha e tranca atrás dela → procura pistas → **uma pista faz barulho** e acorda o professor → ele caça a Yuko por **pelo menos 30 segundos** → ela se esconde → aparece escrito *ele se acalmou* → responde a pergunta da última pista → a porta abre sozinha e o professor acorda de novo → ela foge → ao sair, a porta fecha.\n")
w("**Matemática, Ciências e Geografia** não têm professor nem perseguição: entra → a porta fecha atrás dela → pistas → pergunta → a porta abre → ao sair, a porta fecha.\n")

cs = {c["id"]: c for c in C.CUTSCENES}
puz = {p["id"]: p for p in C.PUZZLES}
clues = {c["id"]: c for c in C.CLUES}
docs = {d["id"]: d for d in C.DOCUMENTS}
objs = {o["id"]: o for o in C.OBJECTS}


def scene(cid):
    c = cs[cid]
    if c.get("director"):
        w("\n**Cena: %s** _(tocada pelo diretor; pode repetir)_\n" % c["title"])
    else:
        w("\n**Cena: %s** _(gatilho: %s%s)_\n" % (c["title"], c["trigger"], " " + c.get("trigger_id", "") if c.get("trigger_id") else ""))
    for st in c["steps"]:
        if "title" in st:
            w("> **[CARTELA]** %s" % st["title"])
        if "pose" in st:
            w("> _(Yuko %s)_" % {"lying": "deitada no chão", "standing": "se levanta"}.get(st["pose"], st["pose"]))
        if st.get("map_open"):
            w("> _(o mapa abre na tela)_")
        if st.get("sequencia"):
            w("> _(as notas aparecem uma a uma na lousa, cada uma com o seu número e o seu som, e somem)_")
        for who, text in st.get("lines", []):
            if who == C.MAPA:
                w("> **Mapa** _(escreve-se sozinho)_: %s" % text.replace("\n", " / "))
            else:
                w("> **%s:** %s" % (who, text))
        if st.get("fade") == "out":
            w("> _(a tela escurece)_")
    eff = [e for e in c.get("effects", []) if e["type"] == "set_objective"]
    if eff:
        w("\nObjetivo na tela: _%s_" % eff[0]["text"])


def puzzle(pid):
    p = puz[pid]
    tipo = {"MULTIPLE_CHOICE": "múltipla escolha", "DOOR_CODE": "senha de 4 dígitos", "NUMERIC": "resposta numérica"}.get(p["question_type"], p["question_type"])
    w("\n**Enigma — %s** (%s)\n" % (p["title"], tipo))
    w(p["description"].replace("\n", "  \n"))
    if p.get("options"):
        w("")
        for i, o in enumerate(p["options"]):
            w("- %s%s" % (o, "  ← **correta**" if i == p["correct_option"] else ""))
    else:
        w("\nResposta: **%s**" % p["correct_answer"])
    w("\nPistas: " + ", ".join("_%s_" % clues[c]["title"] for c in p.get("required_clue_ids", [])))
    w("\nExplicação mostrada ao acertar: %s" % p["solution_explanation"])


def flow(room):
    n = C.MAP_NOTES_FLOW[room]
    labels = [("enter", "ao entrar (a porta fecha atrás dela)"), ("awake", "quando o professor acorda"),
              ("calm", "quando ele se acalma"), ("open", "resposta certa: a porta abre"), ("done", "ao sair (a porta fecha)")]
    w("\n**Escritos no mapa nesta sala**\n")
    for k, label in labels:
        if k in n:
            w("- _%s:_ %s" % (label, n[k].replace("\n", " / ")))


def doc(did):
    d = docs[did]
    w("\n**Documento — %s**\n" % d["title"])
    for line in d["lines"]:
        w("> " + line)
    for who, text in d.get("after", []):
        w("\n_%s comenta:_ \"%s\"" % (who, text))


w("\n## 1. O pátio onde Yuko acorda\n")
scene("cena_abertura")
w("\nAviso no quadro do pátio (opcional): " + clues["ini_bilhete"]["content"].replace("\n", " "))
scene("cena_mapa")

rooms = [("room_1", "Português", "O Leitor", "cena_portugues", "cena_leitor_desperta", "doc_chamada"),
         ("room_2", "Matemática", None, "cena_matematica", None, "doc_diario"),
         ("room_3", "Ciências", None, "cena_ciencias", None, "doc_relatorio"),
         ("room_4", "Geografia", None, "cena_geografia", None, "doc_foto"),
         ("room_5", "Música", "O Maestro", "cena_musica", "cena_maestro_toca", "doc_programa")]
for i, (rid, name, monster, enter, awake, d) in enumerate(rooms, start=2):
    room = next(r for r in C.ROOMS if r["id"] == rid)
    w("\n## %d. Sala de %s — %s\n" % (i, name, monster or "sem professor"))
    scene(enter)
    w("\n**Pistas** (na ordem que o jogador costuma achar):\n")
    for c in C.CLUES:
        if c["room_id"] == rid:
            o = next((o for o in C.OBJECTS if o.get("clue") == c["id"]), None)
            if o is None:
                w("- %s — _aparece sozinha quando o Maestro termina de tocar (sem números)_" % c["title"])
                continue
            w("- %s%s — _%s_" % ("**[PISTA BARULHENTA]** " if o.get("noisy") else "", c["title"], o["prompt"].replace("E  ", "")))
    if rid in C.MUSIC_SEQUENCES:
        m = C.MUSIC_SEQUENCES[rid]
        w("\n**O enigma da melodia** (configurável em `MUSIC_SEQUENCES`): com as pistas lidas, ela aperta E no piano. "
          "O Maestro se senta e toca %d notas, uma de cada vez; cada nota aparece na lousa com o número dela e some. "
          "Depois ele para, observa e acorda: ela se esconde, guarda a melodia na cabeça e, com ele calmo, digita no teclado ao lado da porta. "
          "Sequência: %s → senha **%s**. Errou: som desafinado, o Maestro grita e caça de novo (captura = volta ao checkpoint); "
          "dá para pedir a melodia de novo no piano (ele acorda outra vez).\n"
          % (len(m["notas"]), ", ".join("%s = %d" % (n["nome"], n["numero"]) for n in m["notas"]), C.music_answer(rid)))
        scene(m["cena"])
        scene(m["cena_erro"])
    elif awake:
        scene(awake)
    puzzle(room["puzzle"])
    doc(d)
    flow(rid)

w("\n## 7. A saída (salinha dos monitores, no fim do corredor)\n")
w("Aparece no mapa e destranca só quando Música termina.")
scene("cena_monitores")
scene("cena_final")
w("\nTela final: **FIM DO CAPÍTULO 1** → menu principal.\n")

open(os.path.join(os.path.dirname(HERE), "docs", "ROTEIRO.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("ok: docs/ROTEIRO.md")

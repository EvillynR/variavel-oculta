# -*- coding: utf-8 -*-
"""Conteúdo da história de Yuko — fonte única dos textos, enigmas e cenas.

Editado por pessoas. tools/build_story.py lê este arquivo (e os pontos de
pista de tools/layout_anchors.json, gerados por tools/layout_moveis.py) e gera:
  * data/game_data.json  (salas, enigmas, pistas, eventos, objetos, monstros)
  * data/story.json      (cenas de filme, escritos do mapa, efeitos, mapa)
  * os objetos interativos na cena (nó Gameplay de scenes/main.tscn)

Versão 3 (pedido da equipe):
  * NÃO há voz no telefone. Tudo o que a voz diria aparece ESCRITO NO MAPA,
    numa letra que não é da Yuko — ninguém sabe quem escreve (fala "Mapa").
  * Fluxo de cada sala: entra (a porta fecha atrás) → procura pistas nas
    paredes, estantes e armários → UMA pista faz barulho e acorda o professor
    → ela se esconde → aviso "ele se acalmou" → a ÚLTIMA pista tem a pergunta
    → resposta certa abre a porta sozinha e o professor acorda de novo → ela
    foge → ao sair, a porta fecha → próxima sala.
  * Uma pergunta por sala. A saída é uma 5ª sala no corredor, escondida no
    mapa até Geografia acabar.

Versão 5 (pedido da equipe):
  * Escola japonesa. Ela acorda num PÁTIO a céu aberto (a antiga 3ª sala).
  * Só duas salas têm professor: a primeira (Português, a Leitora) e a última
    (Música, o Maestro). Matemática, Ciências e Geografia mantêm pistas e
    pergunta (a porta fecha atrás dela e abre com a resposta), sem monstro.
  * Perseguição de no mínimo 30 s quando o professor acorda.
  * A saída (sala dos monitores) fica no fim do corredor, depois de Música,
    escondida no mapa até Música acabar.
"""

PROTAGONISTA = "Yuko"
MAPA = "Mapa"          # "quem fala" nos escritos que aparecem no mapa

# ------------------------------------------------------------------ salas
ROOMS = [
    dict(id="patio", kind="STORY_AREA", display_name="Pátio (onde Yuko acorda)",
         scene_anchor="School/Patio", narrative_tier=1, connected_area_paths=["School/Exit"],
         connection_notes="Pátio a céu aberto no lugar da antiga 3ª sala. Porta para o corredor (z −71): tranca manual, abre depois da cena do mapa."),
    dict(id="room_1", order=1, subject="Português", display_name="Sala de Português", props="Portugues",
         monster_id="reader", scene_anchor="School/Room 1", door="PortaRoom1", tier=1,
         noisy="room_1.livro_preso", puzzle="port_gaveta",
         narrative_layer=1, nav_mesh="room_1_navmesh", nav_region="Navigation/Room1Navigation",
         theme="A Leitora (professora de Literatura, virou uma aranha). Acorda quando o livro preso derruba a pilha da estante."),
    dict(id="room_2", order=2, subject="Matemática", display_name="Sala de Matemática", props="Matematica",
         monster_id="", scene_anchor="School/Room 2", door="PortaRoom2", tier=2, puzzle="mat_cofre",
         theme="Sem professor (só pistas e pergunta). O Prof. Bruno não está; só o diário dele."),
    dict(id="room_3", order=3, subject="Ciências", display_name="Laboratório de Ciências", props="Ciencias",
         monster_id="", scene_anchor="School/Room 3", door="PortaRoom3", tier=2, puzzle="cie_frasco",
         theme="Sem professor (só pistas e pergunta). O relatório conta o que houve com a Profª Marta."),
    dict(id="room_4", order=4, subject="Geografia", display_name="Sala de Geografia", props="Geografia",
         monster_id="", scene_anchor="School/Room 4", door="PortaRoom4", tier=2, puzzle="geo_ponto",
         theme="Sem professor (só pistas e pergunta). A foto da turma mostra a nº 07."),
    dict(id="room_5", order=5, subject="Música", display_name="Sala de Música", props="Musica",
         monster_id="maestro", scene_anchor="School/MusicRoom", door="PortaMusica", tier=3,
         puzzle="mus_teclado",
         narrative_layer=6, nav_mesh="music_room_navmesh", nav_region="Navigation/MusicNavigation",
         theme="O Maestro (professor de Música). Guiado só pelo som: toca a melodia no piano (cada nota com um número na lousa), depois caça quem estiver na sala. A senha é a melodia, na ordem."),
    dict(id="sala_saida", kind="STORY_AREA", display_name="A saída (Sala dos Monitores)",
         scene_anchor="School/SalaMonitores", narrative_tier=3, connected_area_paths=["School/Corridor5"],
         narrative_layer=7, nav_mesh="initial_navmesh", nav_region="Navigation/InitialNavigation",
         connection_notes="Porta no fim do corredor (z −190), depois de Música. Abre e aparece no mapa só quando Música termina."),
]

MONSTERS = {
    "reader": dict(display_name="A Leitora", room_id="room_1", navigation_layers=1, hearing_profile="leitor_audicao",
                   patrol_speed=1.1, investigate_speed=2.2, search_speed=2.2, chase_speed=3.0, sight_fov_degrees=110.0,
                   eye_height=3.8, sight_distance=14.0, search_duration=10.0,
                   placeholder_notes="Professora de Literatura que virou aranha. Modelo: assets/characters/leitora/LeitoraRig.glb (MonsterRoster/Leitor)."),
    "maestro": dict(display_name="O Maestro", room_id="room_5", navigation_layers=32, hearing_profile="maestro_audicao",
                    patrol_speed=1.2, investigate_speed=2.3, search_speed=2.3, chase_speed=2.5, eye_height=3.8,
                    search_duration=10.0,
                    placeholder_notes="Professor de Música (Prof. Hélio, regente). Não enxerga: caça pelo som. Anda devagar e, quando chega perto, faz a Yuko levitar."),
}

# ------------------------------------------------------------------ pistas
CLUES = [
    dict(id="ini_bilhete", room_id="patio", puzzle_id="", title="Aviso no quadro do pátio",
         content="\"Yuko, amanhã é a AVALIAÇÃO ESPECIAL. Não falte.\nQuem faltar perde a vaga no programa.\"\n— Coordenação"),
    # ----- Português
    dict(id="port_quadro", room_id="room_1", puzzle_id="port_gaveta", title="A última lição no quadro",
         content="A letra da professora, enorme, ocupa o quadro inteiro:\n\n"
                 "\"A SENHA DA GAVETA É A FRASE QUE EU REPITO.\n"
                 "CONTE AS CLASSES DE PALAVRAS, NESTA ORDEM:\n"
                 "SUBSTANTIVOS · ADJETIVOS · VERBOS · ARTIGOS.\""),
    dict(id="port_frase", room_id="room_1", puzzle_id="port_gaveta", title="Caderno da professora",
         content="O caderno da professora de Literatura. A mesma frase, escrita centenas de vezes, cada vez com a letra mais torta:\n\n"
                 "\"A menina assustada abriu a porta escura.\"\n\n"
                 "Na última página: \"Ela vai voltar. A nº 07 sempre volta.\""),
    dict(id="port_classes", room_id="room_1", puzzle_id="port_gaveta", title="Livro de gramática",
         content="Você puxa o livro preso — e a pilha inteira despenca da estante.\n\n"
                 "CLASSES DE PALAVRAS (página marcada)\n"
                 "• Substantivo: dá nome a seres e coisas (menina, escola, porta).\n"
                 "• Adjetivo: dá uma característica ao substantivo (escura, velha, assustada).\n"
                 "• Verbo: indica ação ou estado (abriu, correr, estar).\n"
                 "• Artigo: vem antes do substantivo (o, a, os, as, um, uma)."),
    # ----- Matemática
    dict(id="mat_suplementares", room_id="room_2", puzzle_id="mat_cofre", title="Quadro: ângulos",
         content="• Ângulos SUPLEMENTARES: a soma das medidas é 180°.\n"
                 "• Ângulos COMPLEMENTARES: a soma das medidas é 90°.\n"
                 "• Sistema de equações: isole uma incógnita em uma equação e substitua na outra."),
    dict(id="mat_prova", room_id="room_2", puzzle_id="mat_cofre", title="Prova esquecida",
         content="PROVA — 9º ANO — QUESTÃO 3\n"
                 "Dois ângulos são suplementares. O maior mede o dobro do menor, mais 30°.\n"
                 "Quanto mede o MENOR ângulo?\n\n(Ninguém respondeu. A folha está manchada.)"),
    dict(id="mat_cantina", room_id="room_2", puzzle_id="mat_cofre", title="Comanda da cantina",
         content="A comanda estava presa embaixo de uma régua de metal do tamanho de você. A régua despenca no chão.\n"
                 "O barulho ecoa... e nada acontece. A sala continua vazia.\n\n"
                 "3 sucos + 2 lanches = R$ 23,00\n"
                 "1 suco + 2 lanches = R$ 13,00\n\n"
                 "(Todos os sucos têm o mesmo preço. Todos os lanches também.)"),
    dict(id="mat_senha", room_id="room_2", puzzle_id="mat_cofre", title="Bilhete no transferidor",
         content="Preso no transferidor gigante da parede:\n\n"
                 "\"SENHA DO COFRE DE PROVAS =\npreço do suco | preço do lanche | MENOR ângulo da questão 3\"\n\n"
                 "(Os números ficam um ao lado do outro.)"),
    # ----- Ciências
    dict(id="cie_ph", room_id="room_3", puzzle_id="cie_frasco", title="Cartaz: escala de pH",
         content="ESCALA DE pH\n"
                 "• 0 a 6 — ÁCIDO (suco de limão ≈ 2, vinagre ≈ 3)\n"
                 "• 7 — NEUTRO (água pura)\n"
                 "• 8 a 14 — BÁSICO (leite de magnésia ≈ 10, sabão ≈ 10)\n\n"
                 "Ácido + base → sal + água. Isso se chama NEUTRALIZAÇÃO."),
    dict(id="cie_caderno", room_id="room_3", puzzle_id="cie_frasco", title="Caderno de laboratório",
         content="\"O armário de reagentes foi lacrado com um gel ÁCIDO (pH 2).\n"
                 "Para dissolver o lacre sem estragar a fechadura é preciso NEUTRALIZAR o ácido.\n"
                 "Não misture ácido com ácido!\""),
    dict(id="cie_frascos", room_id="room_3", puzzle_id="cie_frasco", title="Prateleira de frascos",
         content="Você puxa a caixa de frascos. Os vidros batem uns nos outros — e um se espatifa no chão.\n\n"
                 "Sobraram quatro, com etiquetas à mão:\n"
                 "• Suco de limão — pH 2\n• Vinagre — pH 3\n• Água destilada — pH 7\n• Leite de magnésia — pH 10"),
    # ----- Geografia
    dict(id="geo_rosa", room_id="room_4", puzzle_id="geo_ponto", title="Rosa dos ventos",
         content="Pintada no chão: N (Norte) para cima, S (Sul) para baixo, L (Leste) para a direita, O (Oeste) para a esquerda."),
    dict(id="geo_plano", room_id="room_4", puzzle_id="geo_ponto", title="Plano de evacuação",
         content="PLANO DE EVACUAÇÃO — DIA DO ACIDENTE\n"
                 "A escola fica no quadrado D2 do mapa da cidade.\n"
                 "Rota: andar 3 quadras para o SUL e depois 2 quadras para o OESTE.\nLá fica o ponto de encontro dos alunos."),
    dict(id="geo_legenda", room_id="room_4", puzzle_id="geo_ponto", title="Etiqueta embaixo do globo",
         content="Você gira o globo enferrujado. Ele range alto, um som que atravessa a sala.\n\n"
                 "Na base, uma etiqueta: \"MAPA DA CIDADE — as COLUNAS vão de A (oeste) até F (leste); "
                 "as LINHAS vão de 1 (norte) até 6 (sul).\""),
    # ----- Música
    dict(id="mus_lousa", room_id="room_5", puzzle_id="mus_teclado", title="A lousa de música",
         content="Uma pauta de cinco linhas, vazia. No canto, em giz:\n\n"
                 "\"NA MINHA AULA, CADA NOTA TEM UM NÚMERO.\nEu toco a nota no piano, escrevo a nota na pauta e o número dela ao lado.\n"
                 "UMA VEZ SÓ. Depois apago.\"\n\n"
                 "(Tem marcas de giz apagado por cima de marcas de giz apagado.)"),
    dict(id="mus_partitura", room_id="room_5", puzzle_id="mus_teclado", title="Partitura na estante",
         content="LIÇÃO 1 — as notas na pauta (clave de sol), de baixo para cima:\n\n"
                 "• DÓ — numa linha pequena só dela, embaixo da pauta\n"
                 "• RÉ — logo abaixo da 1ª linha\n"
                 "• MI — na 1ª linha\n• FÁ — no 1º espaço\n• SOL — na 2ª linha\n• LÁ — no 2º espaço\n"
                 "• SI — na 3ª linha (a do meio)\n\n"
                 "\"Quanto mais alta a nota na pauta, mais agudo o som.\""),
    dict(id="mus_bilhete", room_id="room_5", puzzle_id="mus_teclado", title="Bilhete na estante de partituras",
         content="\"A porta só abre pelo TECLADO ao lado dela.\n"
                 "A senha é a minha melodia: os NÚMEROS das notas, NA ORDEM em que eu toco.\n\n"
                 "Quer ouvir? Peça no piano. Eu toco UMA vez.\n"
                 "E se você errar... eu vou ouvir.\"\n\n— M."),
    # descoberta em silêncio quando o Maestro termina de tocar (sem números: a
    # sequência some da lousa e não pode ser consultada de novo)
    dict(id="mus_sequencia", room_id="room_5", puzzle_id="mus_teclado", title="A melodia do Maestro",
         content="Ele tocou as notas uma de cada vez e escreveu o número de cada uma na lousa. Depois apagou tudo.\n"
                 "A senha são esses números, na ORDEM em que ele tocou.\n"
                 "(Se esquecer, dá para pedir de novo no piano... mas ele acorda.)"),
]

# ------------------------------------------------------------------ versão 5.7: o enigma da melodia (Música)
# Configurável sem mexer na lógica: troque as notas/números/intervalo aqui e
# rode tools/build_story.py — a senha do teclado é montada destas notas, na ordem.
#   nome = como aparece na lousa · numero = o dígito da senha · som = arquivo
#   assets/audio/notas/<som>.wav · altura = posição na pauta em meios-espaços a
#   partir da 1ª linha (Mi): Dó -2, Ré -1, Mi 0, Fá 1, Sol 2, Lá 3, Si 4.
MUSIC_SEQUENCES = {
    "room_5": dict(
        puzzle_id="mus_teclado",
        monster_id="maestro",
        notas=[dict(nome="Dó", numero=3, som="do", altura=-2),
               dict(nome="Mi", numero=7, som="mi", altura=0),
               dict(nome="Si", numero=8, som="si", altura=4),
               dict(nome="Ré", numero=4, som="re", altura=-1)],
        intervalo=2.4,          # quanto tempo cada nota fica na lousa (s)
        pausa=0.5,              # lousa vazia entre uma nota e a próxima (s)
        piano="room_5.piano",
        pistas_antes=["mus_lousa", "mus_partitura", "mus_bilhete"],  # o piano só toca depois delas
        pista_final="mus_sequencia",
        cena="cena_maestro_toca",
        cena_erro="cena_maestro_erro",
        # onde o Maestro se senta (de frente para o piano) e onde a Yuko assiste
        maestro_piano=[-15.5, 0.0, -182.2, 0.0],
        yuko_assiste=[-7.0, 0.0, -179.5],
        lousa=dict(centro=[-23.30, 3.4, -175.0], largura=4.4),
        teclado=dict(pos=[-7.6, 0.0, -178.4], yaw=90.0),
        ambiente="musica_ambiente",
    ),
}


def music_answer(room_id):
    return "".join(str(n["numero"]) for n in MUSIC_SEQUENCES[room_id]["notas"])


# ------------------------------------------------------------------ a pergunta de cada sala (última pista)
PUZZLES = [
    dict(id="port_gaveta", room_id="room_1", subject="Português", title="A gaveta da professora",
         description="A gaveta da mesa tem um cadeado de 4 números.\n"
                     "Conte as classes de palavras da frase do caderno, na ordem do quadro\n"
                     "(SUBSTANTIVOS · ADJETIVOS · VERBOS · ARTIGOS), e digite os 4 números.",
         question_type="DOOR_CODE", correct_answer="2212",
         solution_explanation="\"A menina assustada abriu a porta escura\": substantivos menina e porta (2); adjetivos assustada e escura (2); verbo abriu (1); artigos A e a (2). Senha 2212.",
         hint_ids=["port_quadro", "port_frase", "port_classes"], required_clue_ids=["port_quadro", "port_frase", "port_classes"],
         monster_id="reader", unlocks_exit="room_1_exit"),
    dict(id="mat_cofre", room_id="room_2", subject="Matemática", title="O cofre de provas",
         description="O cofre de provas pede uma senha numérica.\nUse a prova, a comanda da cantina e o bilhete do transferidor.",
         question_type="DOOR_CODE", correct_answer="5450",
         solution_explanation="Ângulos: x + y = 180 e y = 2x + 30, então x = 50°. Cantina: 3s + 2l = 23 e s + 2l = 13; subtraindo, 2s = 10, s = 5 e l = 4. Senha 5 | 4 | 50 = 5450.",
         hint_ids=["mat_suplementares", "mat_prova", "mat_cantina", "mat_senha"],
         required_clue_ids=["mat_suplementares", "mat_prova", "mat_cantina", "mat_senha"],
         unlocks_exit="room_2_exit"),
    dict(id="cie_frasco", room_id="room_3", subject="Ciências", title="O lacre ácido",
         description="O armário de reagentes está lacrado com um gel ácido (pH 2).\nQual dos frascos que sobraram neutraliza o lacre?",
         question_type="MULTIPLE_CHOICE",
         options=["Suco de limão (pH 2)", "Vinagre (pH 3)", "Água destilada (pH 7)", "Leite de magnésia (pH 10)"], correct_option=3,
         solution_explanation="Para neutralizar um ácido é preciso uma BASE. O leite de magnésia (pH 10) é básico.",
         hint_ids=["cie_ph", "cie_caderno", "cie_frascos"], required_clue_ids=["cie_ph", "cie_caderno", "cie_frascos"],
         unlocks_exit="room_3_exit"),
    dict(id="geo_ponto", room_id="room_4", subject="Geografia", title="O ponto de encontro",
         description="O mapa da cidade ocupa a parede. Alguém riscou a rota de evacuação até a metade.\nEm qual quadrado fica o ponto de encontro dos alunos?",
         question_type="MULTIPLE_CHOICE", options=["F5", "B5", "D5", "B1"], correct_option=1,
         solution_explanation="De D2, 3 quadras para o sul chegam à linha 5 (D5); 2 quadras para o oeste chegam à coluna B. Ponto de encontro: B5.",
         hint_ids=["geo_rosa", "geo_plano", "geo_legenda"], required_clue_ids=["geo_rosa", "geo_plano", "geo_legenda"],
         unlocks_exit="room_4_exit"),
    dict(id="mus_teclado", room_id="room_5", subject="Música", title="O teclado da porta",
         description="Um teclado numérico ao lado da porta, coberto de pó de giz.\nDigite a melodia do Maestro: o NÚMERO de cada nota, na ORDEM em que ele tocou.",
         question_type="DOOR_CODE", correct_answer=music_answer("room_5"),
         solution_explanation="Ele tocou " + ", ".join("%s (%d)" % (n["nome"], n["numero"]) for n in MUSIC_SEQUENCES["room_5"]["notas"])
                              + ". Na ordem: " + music_answer("room_5") + ".",
         hint_ids=["mus_lousa", "mus_partitura", "mus_bilhete", "mus_sequencia"],
         required_clue_ids=["mus_lousa", "mus_partitura", "mus_bilhete", "mus_sequencia"],
         monster_id="maestro", unlocks_exit="room_5_exit"),
]

# ------------------------------------------------------------------ objetos (presos aos móveis)
# anchor = "<contêiner de móveis>.<ponto>" em tools/layout_anchors.json.
OBJECTS = [
    dict(id="patio.mapa", anchor="Patio.mapa", action="pegar", prompt="E  Pegar o mapa", one_shot=True),
    dict(id="patio.bilhete", anchor="Patio.bilhete", action="ler", prompt="E  Ler o aviso", clue="ini_bilhete"),
    # Português
    dict(id="room_1.quadro", anchor="Portugues.quadro", action="ler", prompt="E  Ler o quadro", clue="port_quadro"),
    dict(id="room_1.caderno", anchor="Portugues.caderno", action="ler", prompt="E  Pegar o caderno", clue="port_frase"),
    dict(id="room_1.livro_preso", anchor="Portugues.livro_preso", action="puxar", prompt="E  Puxar o livro", clue="port_classes", noisy=True),
    dict(id="room_1.gaveta", anchor="Portugues.gaveta", action="abrir", prompt="E  Cadeado da gaveta", puzzle="port_gaveta"),
    dict(id="room_1.chamada", anchor="Portugues.chamada", action="ler", prompt="E  Ler"),
    # Matemática
    dict(id="room_2.quadro", anchor="Matematica.quadro", action="ler", prompt="E  Ler o quadro", clue="mat_suplementares"),
    dict(id="room_2.prova", anchor="Matematica.prova", action="ler", prompt="E  Ler a prova", clue="mat_prova"),
    dict(id="room_2.comanda", anchor="Matematica.comanda", action="puxar", prompt="E  Puxar o papel", clue="mat_cantina"),
    dict(id="room_2.transferidor", anchor="Matematica.transferidor", action="ler", prompt="E  Ler o bilhete", clue="mat_senha"),
    dict(id="room_2.cofre", anchor="Matematica.cofre", action="abrir", prompt="E  Cofre de provas", puzzle="mat_cofre"),
    dict(id="room_2.diario", anchor="Matematica.diario", action="ler", prompt="E  Ler o diário"),
    # Ciências
    dict(id="room_3.cartaz_ph", anchor="Ciencias.cartaz_ph", action="ler", prompt="E  Ler o cartaz", clue="cie_ph"),
    dict(id="room_3.caderno", anchor="Ciencias.caderno", action="ler", prompt="E  Ler o caderno", clue="cie_caderno"),
    dict(id="room_3.frascos", anchor="Ciencias.frascos", action="puxar", prompt="E  Pegar os frascos", clue="cie_frascos"),
    dict(id="room_3.armario", anchor="Ciencias.armario_reagentes", action="abrir", prompt="E  Lacre do armário", puzzle="cie_frasco"),
    dict(id="room_3.relatorio", anchor="Ciencias.relatorio", action="ler", prompt="E  Ler o relatório"),
    # Geografia
    dict(id="room_4.rosa", anchor="Geografia.rosa", action="examinar", prompt="E  Examinar o chão", clue="geo_rosa"),
    dict(id="room_4.plano", anchor="Geografia.plano", action="ler", prompt="E  Ler o plano", clue="geo_plano"),
    dict(id="room_4.globo", anchor="Geografia.globo", action="girar", prompt="E  Girar o globo", clue="geo_legenda"),
    dict(id="room_4.mapa_cidade", anchor="Geografia.mapa_cidade", action="examinar", prompt="E  Mapa da cidade", puzzle="geo_ponto"),
    dict(id="room_4.foto", anchor="Geografia.foto", action="examinar", prompt="E  Ver a foto"),
    # Música
    dict(id="room_5.quadro", anchor="Musica.quadro", action="ler", prompt="E  Ler a lousa", clue="mus_lousa"),
    dict(id="room_5.partitura", anchor="Musica.partitura", action="ler", prompt="E  Ler a partitura", clue="mus_partitura"),
    dict(id="room_5.piano", anchor="Musica.piano", action="tocar", prompt="E  Pedir para ele tocar o piano", music="room_5"),
    dict(id="room_5.bilhete", anchor="Musica.bilhete", action="ler", prompt="E  Ler o bilhete", clue="mus_bilhete"),
    dict(id="room_5.teclado", anchor="Musica.teclado", action="abrir", prompt="E  Teclado da porta", puzzle="mus_teclado"),
    dict(id="room_5.programa", anchor="Musica.programa", action="ler", prompt="E  Ler o programa"),
    # Saída
    dict(id="sala_saida.ficha", anchor="Saida.ficha", action="ler", prompt="E  Ler a ficha", one_shot=True),
]

DOORS = {
    "patio.porta": ("School/Doors/PortaPatio/Interactable", dict(lock="manual"), "Porta do pátio para o corredor: abre depois da cena do mapa."),
    "room_1.porta": ("School/Doors/PortaRoom1/Interactable", dict(lock="room_available", room_id="room_1"), "Fecha atrás dela ao entrar; abre sozinha com a resposta certa."),
    "room_2.porta": ("School/Doors/PortaRoom2/Interactable", dict(lock="room_available", room_id="room_2"), "Abre quando Português termina."),
    "room_3.porta": ("School/Doors/PortaRoom3/Interactable", dict(lock="room_available", room_id="room_3"), "Abre quando Matemática termina."),
    "room_4.porta": ("School/Doors/PortaRoom4/Interactable", dict(lock="room_available", room_id="room_4"), "Abre quando Ciências termina."),
    "room_5.porta": ("School/Doors/PortaMusica/Interactable", dict(lock="room_available", room_id="room_5"), "Abre quando Geografia termina."),
    "sala_saida.porta": ("School/Doors/PortaInicial/Interactable", dict(lock="manual"), "Fim do corredor: abre quando Música termina."),
}

# ------------------------------------------------------------------ documentos (lore)
DOCUMENTS = [
    dict(id="doc_chamada", room_id="room_1", trigger_id="room_1.chamada", title="Lista de chamada — 3º ano B (2019)",
         lines=["01. Ana Beatriz Moura", "02. Caio Ferraz", "03. Davi Lins", "04. Elisa Prado",
                "05. Igor Mendes", "06. Laura Siqueira",
                "07. Yuko Tanaka ............ TRANSFERIDA PARA O PROGRAMA", "08. Mateus Rocha"],
         after=[(PROTAGONISTA, "Esse... é o meu nome. Eu estudei aqui?")], reveals=["yuko_aluna"]),
    dict(id="doc_diario", room_id="room_2", trigger_id="room_2.diario", title="Diário do Prof. Bruno Sá",
         lines=["Dia 3 — A direção mandou todos os professores tomarem a \"vitamina C-7\". Disseram que é para o cansaço.",
                "Dia 9 — Meus dedos estalam quando escrevo no quadro. Contei: agora são quatro articulações em cada dedo.",
                "Dia 12 — Os alunos do 3º B não voltaram do \"programa\". A diretora diz que foram transferidos."],
         after=[(PROTAGONISTA, "Vitamina C-7... fizeram isso com os próprios professores.")], reveals=["origem_criaturas"]),
    dict(id="doc_relatorio", room_id="room_3", trigger_id="room_3.relatorio", title="Projeto CRISÁLIDA — Relatório nº 3",
         lines=["Sujeito: Profª Marta Reis (Ciências). Dose: 12 ml de C-7.",
                "Resultado: duplicação dos membros superiores. Pernas atrofiadas.",
                "Comportamento: continua \"dando aula\". Escreve fórmulas por horas seguidas.",
                "Próxima etapa: observar a reação da PARTICIPANTE 07 ao ambiente. — O Observador"],
         after=[(PROTAGONISTA, "Participante 07... sou eu. Alguém está me observando.")], reveals=["vigilancia"]),
    dict(id="doc_foto", room_id="room_4", trigger_id="room_4.foto", title="Foto de turma — 3º B, 2019",
         lines=["Na segunda fila, uma garota de cabelo curto segura uma plaquinha: \"Nº 07\".",
                "Atrás da foto, à caneta: \"Participantes selecionados para a Fase 2.\""],
         after=[(PROTAGONISTA, "Sou eu nessa foto... por que eu não lembro de nada disso?")], reveals=["yuko_aluna"]),
    dict(id="doc_programa", room_id="room_5", trigger_id="room_5.programa", title="Programa do recital — 3º B (2019)",
         lines=["RECITAL DE ENCERRAMENTO — regência: Prof. Hélio Amaral",
                "1. Hino da escola (coro)",
                "2. Noturno nº 2 — ao piano: YUKO TANAKA (nº 07)",
                "Escrito à mão, embaixo: \"Cancelado. Os participantes da Fase 2 não podem se apresentar.\""],
         after=[(PROTAGONISTA, "Eu tocava piano? ...minhas mãos lembram. Eu não.")], reveals=["yuko_aluna"]),
]

# ------------------------------------------------------------------ escritos no mapa (substituem a voz)
# Aparecem no mapa (tecla M) e num pedaço de pergaminho no alto da tela.
# "area": perto de qual parte do mapa o texto fica escrito.
MAP_NOTES_FLOW = {
    # Salas com professor: enter, awake, calm, open, done. Sem professor: enter, open, done.
    "room_1": dict(enter="ELA QUASE NÃO ENXERGA.\nMAS OUVE TUDO.",
                   awake="ESCONDA-SE.", calm="ELA SE ACALMOU.\nTERMINE O QUE COMEÇOU.",
                   open="A PORTA ESTÁ ABERTA.\nCORRA.", done="BOA MENINA.\nA PRÓXIMA PORTA JÁ ESTÁ ABERTA."),
    "room_2": dict(enter="NÃO HÁ NINGUÉM AQUI.\nNÃO SE ACOSTUME.",
                   open="A PORTA ABRIU.", done="FALTAM TRÊS.\nEU NUNCA ESTIVE NESSA ESCOLA."),
    "room_3": dict(enter="NÃO TOQUE NOS FRASCOS SEM PENSAR.",
                   open="A PORTA ABRIU.", done="FALTAM DUAS."),
    "room_4": dict(enter="DESCUBRA PARA ONDE LEVARAM OS ALUNOS.",
                   open="A PORTA ABRIU.", done="SÓ FALTA UMA.\nA ÚLTIMA TEM DONO."),
    "room_5": dict(enter="ELE NÃO TEM OLHOS.\nSÓ OUVIDOS.",
                   awake="ELE TOCOU. AGORA ESCUTA.\nESCONDA-SE.", calm="O SILÊNCIO O ACALMOU.\nLEMBRA DA MELODIA?",
                   erro="DESAFINADO.\nESCONDA-SE.",
                   open="CORRA. NÃO OLHE PARA TRÁS.", done="A SAÍDA FICA NO FIM DO CORREDOR.\nEU ABRI PARA VOCÊ."),
}

# ------------------------------------------------------------------ cenas (filme)
def P(x, y, z):
    return [x, y, z]


def A(anchor, ox, oy, oz):
    return {"anchor": anchor, "offset": [ox, oy, oz]}


CUTSCENES = [
    dict(id="cena_abertura", room_id="patio", trigger="MANUAL", title="Abertura",
         steps=[
             dict(fade="black"),
             dict(pose="lying"),
             dict(title="TRÊS DIAS DEPOIS DO ACIDENTE", wait=3.2),
             # de cima da cerejeira, descendo até ela deitada nas pedras molhadas
             dict(cam={"from": {"pos": P(-6.0, 11.0, -63.0), "look": P(-14.0, 6.0, -67.0)}, "to": {"pos": P(-8.0, 3.6, -66.5), "look": P(-12.5, 0.3, -69.5)}, "time": 8.0}, fade="in"),
             dict(lines=[[PROTAGONISTA, "Frio... as pedras estão molhadas."], [PROTAGONISTA, "Onde... onde eu estou?"]]),
             dict(cam={"to": {"pos": A("player", 4.4, 2.4, 2.8), "look": A("player", 0, 0.8, 0)}, "time": 3.4}, pose="standing", pose_time=3.4),
             dict(cam={"to": {"pos": P(-4.8, 2.3, -77.0), "look": P(-17.0, 4.6, -64.5)}, "time": 3.6, "fov": 50}),
             dict(lines=[[PROTAGONISTA, "Uma cerejeira... um pátio. É uma escola."], [PROTAGONISTA, "Eu não lembro de ter vindo para cá."]]),
             dict(cam={"to": {"pos": P(-7.5, 3.4, -72.0), "look": P(-11.0, 1.2, -77.6)}, "time": 3.0}),
             dict(lines=[[PROTAGONISTA, "Tem alguma coisa em cima daquele banco."]]),
         ],
         effects=[dict(type="set_objective", text="Examine o banco do pátio."), dict(type="show_controls"), dict(type="checkpoint", reason="início")]),
    dict(id="cena_mapa", room_id="patio", trigger="INTERACTION", trigger_id="patio.mapa", title="O mapa",
         steps=[
             dict(cam={"from": {"pos": A("player", 4.0, 2.8, 2.6), "look": A("player", 0, 1.2, -1.0)}, "to": {"pos": A("player", 3.0, 2.4, 1.8), "look": A("player", 0, 1.2, -1.0)}, "time": 3.0}),
             dict(lines=[[PROTAGONISTA, "Um mapa da escola... alguém marcou cinco salas."],
                         [PROTAGONISTA, "Português, Matemática, Ciências, Geografia... Música."]]),
             dict(map_open=True),
             dict(lines=[[MAPA, "NÃO FAÇA BARULHO.\nELES AINDA NÃO SABEM QUE VOCÊ ACORDOU."]]),
             dict(lines=[[PROTAGONISTA, "Isso... não estava escrito aqui antes. A tinta ainda está molhada."]]),
             dict(lines=[[MAPA, "AS PORTAS SÓ ABREM NA ORDEM DO MAPA."],
                         [MAPA, "EM CADA SALA HÁ UMA PERGUNTA.\nEM DUAS DELAS HÁ ALGUÉM."],
                         [PROTAGONISTA, "Alguém? Quem está escrevendo isso?"],
                         [MAPA, "SE OUVIR PASSOS, ESCONDA-SE.\nEU VOU TE AJUDAR A SAIR DAÍ."]]),
             dict(map_close=True),
         ],
         effects=[dict(type="map_obtained"),
                  dict(type="open_door", door_id="patio.porta", toast="Mapa guardado — aperte [M] para abrir.\nA porta do pátio se abriu sozinha: o corredor fica logo à frente."),
                  dict(type="set_objective", text="Vá até a Sala de Português (1ª porta do corredor). [M] abre o mapa."),
                  dict(type="checkpoint", reason="mapa")]),
    # ---------------- Português (a Leitora)
    dict(id="cena_portugues", room_id="room_1", trigger="ROOM_ENTERED", trigger_id="room_1", title="A Leitora",
         steps=[
             dict(cam={"from": {"pos": P(-6.5, 5.0, -12.0), "look": P(-14.0, 1.4, -17.0)}, "to": {"pos": P(-10.0, 5.2, -21.0), "look": A("monster:reader", 0, 2.6, 0)}, "time": 5.0, "fov": 42}),
             dict(lines=[["A Leitora", "...a menina... assustada... abriu a porta... escura..."],
                         [PROTAGONISTA, "Ela não para de escrever. E fala sozinha."]]),
         ]),
    dict(id="cena_leitor_desperta", room_id="room_1", trigger="MONSTER_STATE", trigger_id="reader", trigger_state="AWAKENING", title="A Leitora desperta",
         steps=[
             dict(cam={"from": {"pos": A("monster:reader", 5.5, 3.2, 3.4), "look": A("monster:reader", 0, 2.8, 0)}, "to": {"pos": A("monster:reader", 6.8, 3.6, 4.0), "look": A("monster:reader", 0, 2.8, 0)}, "time": 2.2, "fov": 40}),
             dict(lines=[["A Leitora", "Quem está... fora da carteira?"]]),
         ]),
    # ---------------- salas sem professor
    dict(id="cena_matematica", room_id="room_2", trigger="ROOM_ENTERED", trigger_id="room_2", title="Matemática",
         steps=[
             dict(cam={"from": {"pos": P(-6.0, 5.2, -42.0), "look": P(-15.0, 1.4, -48.0)}, "to": {"pos": P(-7.0, 4.6, -44.0), "look": P(-21.5, 3.0, -48.0)}, "time": 4.0, "fov": 42}),
             dict(lines=[[PROTAGONISTA, "Ninguém... mas o giz ainda está no chão, quebrado."]]),
         ]),
    dict(id="cena_ciencias", room_id="room_3", trigger="ROOM_ENTERED", trigger_id="room_3", title="Ciências",
         steps=[
             dict(cam={"from": {"pos": P(-6.0, 5.0, -97.0), "look": P(-16.0, 1.4, -104.0)}, "to": {"pos": P(-8.0, 4.4, -99.5), "look": P(-21.5, 3.0, -104.2)}, "time": 4.0, "fov": 42}),
             dict(lines=[[PROTAGONISTA, "Fórmulas até o teto... alguém escreveu isso por dias."]]),
         ]),
    dict(id="cena_geografia", room_id="room_4", trigger="ROOM_ENTERED", trigger_id="room_4", title="Geografia",
         steps=[
             dict(cam={"from": {"pos": P(-6.0, 5.0, -122.0), "look": P(-16.0, 1.4, -128.0)}, "to": {"pos": P(-8.0, 4.4, -123.0), "look": P(-14.0, 1.5, -128.0)}, "time": 4.0, "fov": 42}),
             dict(lines=[[PROTAGONISTA, "Mapas riscados... todas as rotas terminam no mesmo lugar."]]),
         ]),
    # ---------------- Música (o Maestro)
    dict(id="cena_musica", room_id="room_5", trigger="ROOM_ENTERED", trigger_id="room_5", title="O Maestro",
         steps=[
             dict(cam={"from": {"pos": P(-6.0, 5.2, -172.0), "look": P(-14.0, 1.6, -176.0)}, "to": {"pos": P(-7.0, 5.0, -168.0), "look": A("monster:maestro", 0, 2.6, 0)}, "time": 5.0, "fov": 42}),
             dict(lines=[["O Maestro", "(os dedos dele tocam no ar um piano que não existe)"],
                         [PROTAGONISTA, "Ele não tem olhos... só escuta."]]),
         ]),
    # versão 5.7: o enigma da melodia. Cenas tocadas pelo diretor (director=True):
    # não são eventos de uma vez só — o piano pode ser pedido de novo.
    dict(id="cena_maestro_toca", room_id="room_5", director=True, title="A melodia do Maestro", luz=0.8,
         steps=[
             dict(fade="out", fade_time=0.6,
                  effects=[dict(type="monster_place", monster_id="maestro", pos=MUSIC_SEQUENCES["room_5"]["maestro_piano"]),
                           dict(type="player_place", pos=MUSIC_SEQUENCES["room_5"]["yuko_assiste"], look=[-15.5, 0.0, -181.0])]),
             dict(fade="in", fade_time=1.0,
                  cam={"from": {"pos": P(-10.6, 4.6, -179.4), "look": P(-15.5, 2.9, -181.2)}, "to": {"pos": P(-11.2, 4.3, -179.8), "look": P(-15.5, 3.1, -181.4)}, "time": 3.4, "fov": 48}),
             dict(lines=[["O Maestro", "(ele se senta ao piano. Os dedos compridos procuram as teclas.)"],
                         [PROTAGONISTA, "Ele vai tocar... e escrever na lousa. Uma vez só."]]),
             dict(cam={"from": {"pos": P(-8.0, 4.6, -174.6), "look": P(-23.3, 3.2, -175.4)}, "to": {"pos": P(-8.6, 4.5, -174.8), "look": P(-23.3, 3.2, -175.4)}, "time": 1.2, "fov": 34}),
             dict(sequencia="room_5"),
             dict(cam={"from": {"pos": P(-11.0, 4.6, -178.6), "look": A("monster:maestro", 0, 3.1, 0)}, "to": {"pos": P(-11.6, 4.3, -179.0), "look": A("monster:maestro", 0, 3.3, 0)}, "time": 2.4, "fov": 44},
                  effects=[dict(type="monster_pose", monster_id="maestro", pose="search")]),
             dict(lines=[["O Maestro", "(as mãos param no ar. A cabeça gira, devagar, para onde você está.)"],
                         ["O Maestro", "...Agora é a sua vez. Sem desafinar."]]),
         ],
         effects=[dict(type="music_awake", room_id="room_5")]),
    dict(id="cena_maestro_erro", room_id="room_5", director=True, title="Desafinado", luz=0.85,
         steps=[
             dict(effects=[dict(type="monster_pose", monster_id="maestro", pose="catch")],
                  cam={"from": {"pos": A("monster:maestro", 5.6, 3.3, 1.5), "look": A("monster:maestro", 0, 3.0, 0)}, "to": {"pos": A("monster:maestro", 4.8, 3.2, 1.2), "look": A("monster:maestro", 0, 3.2, 0)}, "time": 1.6, "fov": 48}),
             dict(lines=[["O Maestro", "DESAFINADO!"],
                         ["O Maestro", "(todas as cordas do piano rangem ao mesmo tempo)"]]),
         ],
         effects=[dict(type="music_wrong", room_id="room_5")]),
    # ---------------- a saída (fim do corredor)
    dict(id="cena_monitores", room_id="sala_saida", trigger="ROOM_ENTERED", trigger_id="sala_saida", title="Os monitores", luz=0.35,
         steps=[
             dict(cam={"from": {"pos": P(3.5, 4.6, -190.8), "look": P(-5.8, 4.4, -194.0)}, "to": {"pos": P(0.5, 4.0, -192.0), "look": P(-5.8, 4.5, -194.0)}, "time": 5.0, "fov": 46}),
             dict(lines=[[PROTAGONISTA, "Monitores... são as salas. Português... Matemática... Ciências... Geografia... Música."],
                         [PROTAGONISTA, "E esse aqui... é o pátio onde eu acordei."],
                         [PROTAGONISTA, "O horário da gravação: 02:14. Eu só acordei de manhã..."],
                         [PROTAGONISTA, "Alguém estava me olhando antes de eu acordar."]]),
         ],
         effects=[dict(type="set_objective", text="Leia a ficha em cima da mesa."), dict(type="checkpoint", reason="entrada: saída")]),
    dict(id="cena_final", room_id="sala_saida", trigger="INTERACTION", trigger_id="sala_saida.ficha", title="Final", luz=0.55,
         steps=[
             dict(cam={"from": {"pos": P(1.6, 2.7, -190.7), "look": P(-3.4, 1.9, -192.6)}, "to": {"pos": P(1.0, 2.4, -190.9), "look": P(-3.4, 1.8, -192.6)}, "time": 3.0, "fov": 48}),
             dict(lines=[["Ficha", "PROJETO CRISÁLIDA — PARTICIPANTE 07: Yuko Tanaka. Ex-aluna, turma de 2019. Fase 2: CONCLUÍDA. Status: em observação."],
                         [PROTAGONISTA, "Ex-aluna... Fase 2... o que fizeram comigo?"],
                         [PROTAGONISTA, "O mapa... está escrevendo de novo."]]),
             dict(map_open=True),
             dict(lines=[[MAPA, "PARABÉNS. VOCÊ CHEGOU ATÉ AQUI."],
                         [PROTAGONISTA, "Você disse que ia me ajudar a escapar!"],
                         [MAPA, "NÃO. EU DISSE QUE IA TE AJUDAR A SAIR DAÍ.\nDAQUELE PÁTIO."],
                         [MAPA, "E VOCÊ SAIU. EXATAMENTE COMO PLANEJADO."],
                         [MAPA, "OS TESTES ACABARAM, PARTICIPANTE 07.\nAGORA COMEÇA A PARTE INTERESSANTE."]]),
             dict(map_close=True),
             dict(cam={"to": {"pos": P(0.5, 4.0, -192.0), "look": P(-5.8, 4.5, -194.0)}, "time": 2.5, "fov": 42}),
             dict(lines=[[PROTAGONISTA, "Esse monitor... sou eu. De costas. Agora."]]),
             dict(fade="out", wait=1.5),
             dict(title="CONTINUA...", wait=3.5),
         ],
         effects=[dict(type="end_game")]),
]

# ------------------------------------------------------------------ mapa (desenho)
# Retângulos da planta (x0, z0, x1, z1) em metros. "requires": quando aparece.
MAP_AREAS = [
    dict(id="corredor", label="", rect=[-3.5, -190, 3.5, -4], requires="map", kind="corridor"),
    dict(id="patio", label="Pátio · onde acordei", rect=[-23.5, -83.5, -3.5, -58.5], requires="map", door=[-3.5, -71.0], icon="arvore", kind="patio"),
    dict(id="room_1", label="1 · Português", rect=[-23.5, -30.1, -3.5, -7.4], requires="map", door=[-3.5, -10.5], icon="livro"),
    dict(id="room_2", label="2 · Matemática", rect=[-23.5, -58.5, -3.5, -37.5], requires="map", door=[-3.5, -40.5], icon="angulo"),
    dict(id="room_3", label="3 · Ciências", rect=[-23.5, -116.2, -3.5, -92.3], requires="map", door=[-3.5, -95.5], icon="frasco"),
    dict(id="room_4", label="4 · Geografia", rect=[-23.5, -138, -3.5, -116.8], requires="map", door=[-3.5, -119.9], icon="globo"),
    dict(id="room_5", label="5 · Música", rect=[-23.5, -185, -3.5, -165], requires="map", door=[-3.5, -175.0], icon="nota"),
    dict(id="sala_saida", label="SAÍDA", rect=[-6, -198, 6, -190], requires="saida", door=[0.0, -190.0], icon="olho"),
]
MAP_TARGETS = [
    dict(until_room_completed="", needs="no_map", target=[-11.0, -77.6], text="O banco do pátio"),
    dict(until_room_completed="room_1", target=[-3.5, -10.5], text="Sala de Português"),
    dict(until_room_completed="room_2", target=[-3.5, -40.5], text="Sala de Matemática"),
    dict(until_room_completed="room_3", target=[-3.5, -95.5], text="Laboratório de Ciências"),
    dict(until_room_completed="room_4", target=[-3.5, -119.9], text="Sala de Geografia"),
    dict(until_room_completed="room_5", target=[-3.5, -175.0], text="Sala de Música"),
    dict(until_room_completed="", target=[0.0, -190.0], text="A saída"),
]

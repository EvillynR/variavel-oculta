# História de Yuko + correção da câmera (versão de entrega)

- **Base:** `VO_Ajustes.zip`. A cena original ficou guardada fora do projeto antes da reestruturação.
- **Testado:** Godot 4.7.1.
  - Testes de lógica: headless, `--fixed-fps 60`.
  - Capturas reais: Forward+ (Vulkan por software) e Compatibility.
- **Personagens:** continuam as cápsulas provisórias. O modelo final entra pelo `visual_scene` de cada monstro, como já era.

## 0. Versão 6.2.1 (sala de Português)

- A mesa da professora saiu da frente do quadro e foi para o canto, ao lado do armário (tools/layout_moveis.py). A gaveta com o cadeado e o esconderijo embaixo da mesa foram junto.
- A Leitora agora fica de costas para a sala, escrevendo na lousa (tools/build_story.py, MONSTER_HOMES).
- Luz nova "LuzLousa" (School/Room 1) para a lousa aparecer atrás dela; a ProfessorRoomLight1 foi apontada para a lousa.
- Navmesh da sala 1 refeito (tools/bake_all_navmesh.gd -- --force). Só o room_1_navmesh.tres mudou.
- tests/historia_completa_test.gd atualizado: a Yuko levanta com a animação "Levantando" (175 ok).
- Prints: tests/v621_lousa_capturas.gd.
- Morte no Maestro: ele só faz a Yuko levitar; quando ela não escapa, a tela de game over (checkpoint) aparece direto, com ela ainda no ar. A animação de morrer ficou só para a Leitora (scripts/monsters/game_over_manager.gd, tests/modelos_v62_test.gd).

## 0. Versão 6.2 — modelos novos da Ana (Yuko, Maestro e Leitora)

- **Arquivos**: `assets/characters/yuko/YukoRig.glb`, `assets/characters/maestro/MaestroRig.glb` (substituídos) e `assets/characters/leitora/LeitoraRig.glb` (novo). As texturas saíram do .glb (arquivos `*_texture_*.png` ao lado, compressão VRAM em alta qualidade, como as outras).
- **Leitora** (sala de Português): `MonsterRoster/Leitor/Visual` usa o `MonsterAnimator` com o modelo da Leitora (3,4 m): dormindo = *Escrevendo*, andando = *Andando*, perseguindo = *Correndo*, pegou a Yuko = *Matando*. Os textos da sala viraram "a Leitora / a professora".
- **Maestro**: persegue mais devagar (3,1 → 2,5 m/s, *Andando*). Quando ouve e começa a perseguir, para 1 s e vira a cabeça (*Atento.longe*). Ele não encosta mais: a 2,6 m ergue o braço (*Atacando*) e faz a Yuko levitar por 1,9 s. Enquanto ela sobe, ainda anda (cada vez mais devagar); se passar de 3,6 m, cai, escapa e ele fica parado 1,6 s. Se não escapar, ela morre. Ajustes no nó `MonsterRoster/Maestro` (Inspector, grupo "Versão 6.2"): `listen_pause`, `levitate_catch`, `levitate_range`, `levitate_release`, `levitate_time`, `levitate_stun`.
- **Yuko**: a abertura usa a animação *Levantando*. Quando é pega, a Yuko morre antes da tela de captura (`GameOverManager.death_time`, 2,2 s no máximo).
- **Atenção, "Morrend"**: a animação de morte veio sem movimento no arquivo (todos os ossos parados, T-pose). Enquanto não vier uma nova, o jogo usa *Levantando* de trás para frente (ela cai e fica deitada). Quando chegar um .glb com a morte certa, o jogo passa a usar sozinho.
- Teste novo: `tests/modelos_v62_test.gd` (21 verificações). Capturas: `tests/v62_capturas.gd`.

## 0h. Versão 6.1 — atalhos para a apresentação

- **Rodar cada sala sozinha:** `scenes/apresentacao/` tem seis cenas (`sala_1_portugues.tscn` … `sala_6_final_saida.tscn`).
  - Abra uma delas e aperte **F6**: o jogo começa no corredor, na frente da porta daquela sala, com as anteriores resolvidas.
  - O estado vem de `data/apresentacao/<sala>.json`, gravado jogando a história inteira (`historia_completa_test.gd -- --gerar-saves-apresentacao`).
  - Script: `scripts/core/apresentacao_sala.gd`.
- **Menu principal:** botão "Apresentação: ir para uma sala", com as mesmas seis opções.
- **Teste novo:** `tests/apresentacao_test.gd` (35 verificações): cada atalho abre a sala certa, com as anteriores resolvidas, e a sala começa normalmente.
- **Texturas desenhadas pelo projeto** (mapa da cidade, transferidor, pedra do pátio): mipmaps ligados, para não "tremerem" de longe.
- **`fluxo_menu_test`:** a conferência do brilho agora segue a base escura da 5.9 (Brilho × 0,85).
- **Guia completo do projeto:** documento à parte, com prints do editor e do jogo.

## 0g. Versão 6.0 — mais leve, sem tirar nada

Nenhum elemento, modelo ou textura saiu do jogo; a resolução das texturas continua 2K.
- **Memória de vídeo (o principal motivo dos travamentos):** 157 texturas eram carregadas SEM compressão de GPU (cerca de 1,9 GB de VRAM). Agora usam compressão de GPU de alta qualidade (BC7; mapas normais em RGTC). A memória medida com o jogo rodando caiu para cerca de 0,54 GB.
- **Texturas em dobro:** cada modelo (GLB) guardava as imagens dentro dele, e o Godot ainda extraía uma cópia ao lado. Agora o GLB aponta para a cópia extraída (`tools/glb_texturas_externas.py`; as 154 imagens foram conferidas pixel a pixel). São 53 MB a menos.
- **Documentação:** as capturas de tela (`docs/capturas`) viraram JPG (54,8 → 8,1 MB), e a pasta `docs` tem `.gdignore`, então o Godot não importa mais essas imagens como texturas.
- **Luzes:** as 28 luzes da escola desligam a sombra a partir de 28 m da câmera e a luz a partir de 40 m (a câmera fica a 10–16 m da Yuko, então nada visível muda).
- **Configurações → Qualidade gráfica:**
  - Alta (padrão, igual a hoje);
  - Equilibrada: 3D a 80% com nitidez FSR;
  - Leve: 3D a 67% e luzes sem sombra.

**Na primeira vez que abrir o projeto no editor**, o Godot vai reimportar as texturas com a nova compressão. Isso leva alguns minutos, uma vez só.

## 0f. Versão 5.9 — escola mais sombria

- **A linha no meio do mapa:** era o friso da parede (a 2,4 m de altura), na frente do mapa porque o quadro estava encostado demais. O mapa da cidade e o mapa-múndi agora ficam na frente do friso.
- **O mapa brilhando demais:** o mapa da cidade não brilha mais sozinho; uma lamparina fraca e quente ilumina só ele (dá para ler, no escuro). A mesa de cartas perdeu o azul vivo.
- **Atmosfera sombria na escola inteira:**
  - menos luz ambiente (0,45 → 0,30), exposição 0,92, mais contraste e cores mais apagadas;
  - névoa de profundidade azul-escura: o fundo das salas some no escuro;
  - luzes das salas e corredores com 70% da força; paredes de reboco mais escuras;
  - o "Brilho" das Configurações continua funcionando, sobre uma base mais escura.
- **Para continuar jogável:** a luz que acompanha a Yuko ficou um pouco mais forte (1,7 → 2,3, alcance 8,5 m). Ela anda numa poça de luz no meio do escuro.

## 0e. Versão 5.8 — ajustes depois do teste da 5.7

- **"Não encontrei o mapa para responder na Geografia":** o "mapa da cidade" era uma cópia do mapa-múndi, na parede sul, atrás do globo e quase de lado para a câmera.
  - Agora é um mapa da cidade de verdade (`assets/textures/mapa_cidade.png`, gerado por `tools/gerar_mapa_cidade.py`): quadriculado A–F × 1–6, a escola em D2, a rota de evacuação riscada só até a metade, rosa dos ventos e legenda. A resposta não aparece no mapa.
  - Ele fica na parede do fundo (oeste), ao lado do mapa-múndi, de frente para a câmera e na altura dos olhos.
- **Móveis "com problema de renderização" quando ela passa atrás:** o móvel ficava só 50% transparente, e os móveis escuros e altos viravam uma mancha preta que engolia a Yuko. Agora ficam 75% transparentes.
  - O globo estava em cima de uma mesinha de 2,25 m (mais alta que ela) e o pé dele parecia flutuar. Agora o globo, com o pé dele, fica direto no chão.
- **Armário no meio da pilastra (corredor de Português):** o 2º armário de alunos atravessava a pilastra da porta (z −28). Foi para z −25,6.
- **O Maestro tocava muito de longe:** o banquinho foi tirado do modelo do piano (`assets/models/piano.glb`), e a colisão do piano agora é só o piano. Na cena da melodia o Maestro fica em pé, colado ao teclado.

## 0d. Versão 5.7 — o enigma da melodia (Sala de Música, o Maestro)

**Fluxo da Música agora:** entra → a porta fecha → lê as pistas (lousa, partitura, bilhete) → **E no piano** → cena: o Maestro se senta e toca; cada nota aparece **sozinha** na lousa (na altura certa da pauta, com o nome e o número, e com o som do piano) e some → no fim a lousa fica vazia → ele para, observa e **acorda** → ela se esconde embaixo da mesa (≥ 30 s) → "ele se acalmou" → **teclado numérico ao lado da porta**.
- **Certo (3784):** som de destravar, o pedestal fica verde ("ABERTO"), a porta abre sozinha e o Maestro acorda para a fuga (como antes).
- **Errado:** o painel fecha, som desafinado, cena curta "Desafinado!" (o Maestro avança), ele volta a caçar. O jogo não tem vidas: a consequência é a caçada, e ser pega volta ao último checkpoint (como em todo o jogo). Com ele calmo de novo dá para tentar outra vez — ou pedir a melodia de novo no piano (ele toca e acorda outra vez).
- **Sequência:** Dó = 3, Mi = 7, Si = 8, Ré = 4 → **3784**. Ela fica em `tools/story_content.py → MUSIC_SEQUENCES` (notas, números, sons, altura na pauta, tempo de cada nota). A senha do teclado é montada dessas notas: trocar a melodia não exige mexer em código, só rodar `tools/build_story.py`.
- **Separação pedida:** apresentação = `LousaNotas` (scripts/world/lousa_notas.gd); memorização = do jogador (a pista "A melodia do Maestro" não tem números e a lousa fica vazia); validação = `PuzzleManager` (pergunta `mus_teclado`, a mesma de todas as salas); quem decide quando cada coisa acontece = `StoryDirector`.
- **Reaproveitado (nada duplicado):** fluxo da sala (fases busca/acordado/calmo/fuga), cenas de filme (`CutscenePlayer`, com dois passos novos: `effects` e `sequencia`), `PuzzleUI`, portas, esconderijo, checkpoints. O cadeado do armário de partituras saiu (o armário continua como móvel).
- **Clima:** som ambiente em laço só dentro da Música (drone grave, vento, rangidos); notas de piano velho, desafinadas de leve; cena com luz baixa. Sons gerados por `tools/gerar_sons.py` (`assets/audio/`).
- **Teclado da porta:** pedestal de ferro com 12 teclas, visor (mostra o que ela digita) e luz vermelha/verde (`scripts/world/teclado_porta.gd`), do lado de dentro, perto da porta, à vista da câmera da sala.

**Todas as salas — onde escrever a resposta:**
- Códigos (Português, Matemática, Música): o painel agora tem um **teclado numérico na tela** com o visor "_ _ _ _". Clique nos números ou use o teclado do computador (Backspace apaga). Com os 4 dígitos ele confere sozinho. Errou: "ERRADO" e o visor limpa.
- Alternativas (Ciências, Geografia): clique ou aperte 1, 2, 3, 4.
- Fluxo conferido em teste: só Português e Música têm professor; Matemática, Ciências e Geografia seguem pistas → pergunta → porta.

**Respostas para testar:** Português **2212** · Matemática **5450** · Ciências **4** (Leite de magnésia, pH 10) · Geografia **2** (B5) · Música **3784**.

**Testes:** novo `tests/musica_enigma_test.gd` (66 verificações: notas uma a uma, na ordem, com som; lousa vazia no fim; piano bloqueado antes das pistas; erro → reação e caçada; ouvir de novo; 3784 pelo teclado do computador abre a porta; todas as salas têm onde responder). `historia_completa_test`, `esconderijo_test` e os demais atualizados e passando.

## 0c. Versão 5.6 — cenas de filme revisadas (pátio, câmeras, clima de suspense)

- **"Cadê a cerejeira, as janelas e os elementos visuais":** o "sono" do pátio (5.4, desempenho) começava dormindo e só acordava com o jogo rodando. A abertura pausa o jogo, então a cena mostrava só a parede.
  - Agora ele roda também com o jogo pausado.
  - Ele acorda se a Yuko **ou a câmera** (de jogo ou de cinema) estiver perto.
  - Teste novo `patio_visivel_test`: a cerejeira, as lanternas, a lua, as janelas, os telhados, o banco, o entulho e o luar aparecem na abertura.
- **Névoa baixa do pátio:** voltou. Ela depende da névoa volumétrica, que agora liga só enquanto o pátio está acordado.
- **Cerejeira:** a copa de esferas parecia um cacho de balões. Agora são ~200 tufos de flores (folhas cruzadas com textura de flores gerada no jogo) e um miolo escuro para dar volume.
- **Abertura:** o plano "Uma cerejeira... um pátio" agora é aberto. Mostra a árvore inteira contra a fachada, com janelas acesas e a lanterna de pedra, e a Yuko pequena no primeiro plano.
- **Madeira dos enfeites** (banco, molduras das janelas, beirais): passou de cor lisa para a mesma madeira gasta das paredes.
- **Matemática:** o "disco escuro" que tapava a cena era o transferidor (pista). Agora é um transferidor de verdade, com graus e o bilhete preso com fita (`assets/textures/transferidor.png`).
- **Maestro despertando:** a câmera cortava a cabeça dele. Agora aparece de corpo inteiro.
  - A legenda também mudou: o modelo não segura batuta, então agora diz "os dedos dele tocam no ar um piano que não existe".
- **Sala dos monitores:** a luz estourava as paredes de branco. Agora é escura, com o brilho frio das TVs.
- **Final:** a câmera ficava atrás da Yuko, colada no batente. Agora é um plano lateral: ela de perfil diante do painel de TVs.
- **Auditoria:** a história inteira foi rodada desenhando, com um quadro salvo a cada ~1,2 s de cada cena de filme, e cada câmera conferida contra os móveis (nenhuma fica dentro de móvel).

## 0b. Versão 5.5 — recursos completos e modelos em alta qualidade

- **Nada do jogo foi reduzido.**
  - As texturas originais de parede e chão voltaram em 2K.
  - As capturas da pasta `docs` voltaram como eram.
  - O que encolheu na 5.4 foi desfeito; da 5.4 ficaram só as correções de fluidez, que não mudam o visual.
- **Modelos em alta qualidade.**
  - Texturas em até 2048 px; reduzidas só as de 4K.
  - Polígonos originais. As exceções são o globo (250 mil) e o crânio de tigre (580 mil triângulos), que foram para 60 mil cada, bem acima do que a câmera do jogo consegue mostrar.
  - Os modelos ocupam ~53 MB em `assets/models/`.
- **Revisão das peças, sala por sala, com fotos de perto:**
  - **Calculadora:** estava escondida dentro do diário (uma pista) na mesa de Matemática. Foi para o outro lado da mesa, deitada, com as teclas para cima e do tamanho do diário.
  - **Vidrarias de Ciências:** maiores.
  - **Verificação automática nova** em `tools/layout_moveis.py`: nenhum enfeite em cima de móvel pode cobrir o marcador de uma pista.

## 0a. Versão 5.4 — fluidez, esconderijo só na mesa, cadeado de Música e modelos 3D

- **"Ela não está andando fluida":** a causa principal era o projeto rodar sem interpolação de física.
  - A Yuko anda no passo da física (60 Hz), mas a tela desenha no ritmo do monitor. Num monitor de 144 Hz, ela ficava parada em 87 de 150 quadros enquanto andava ("aos trancos").
  - **Agora** `physics/common/physics_interpolation` está ligado. A câmera, que já seguia a posição interpolada dela, ficou fora da interpolação, e a câmera das cenas também.
  - No teste novo `fluidez_test`, a 144 Hz, não sobra nenhum quadro parado e a variação do passo cai de 118% para ~14%.
  - Ganhos de desempenho que entraram junto:
    - a névoa volumétrica (ligada sem densidade na versão 5) foi desligada;
    - o pátio "dorme" quando a Yuko está longe (luz do luar com sombra, lanternas, pétalas caindo e enfeites), em `scripts/world/deco/patio_sono.gd`;
    - as peças dos enfeites japoneses foram juntadas em uma malha por material (`DecoUtil.merge`): no corredor, de ~570 para ~150 desenhos por quadro;
    - a textura de pedra do pátio virou imagem fixa.
- **Esconderijo só embaixo da mesa do professor**, em todas as salas.
  - Os armários extras da versão 5.2 saíram, e os armários altos agora são só móveis.
  - O objetivo diz "Esconda-se embaixo da mesa do professor".
- **Cadeado de Música:** a jogadora não achava onde digitar a senha.
  - O cadeado agora fica na porta do **armário de partituras**, no fundo da sala, na altura dos olhos. Antes ficava no pé da estante.
  - O objetivo de cada sala diz onde está a pergunta. Exemplo: "Agora abra o cadeado do armário de partituras, no fundo da sala (aperte E perto dele) e digite a resposta."
- **Modelos 3D enviados**, convertidos com Blender e reduzidos: de ~500 MB de arquivos originais para 8,9 MB em `assets/models/`.
  - Os polígonos foram reduzidos (tigre de 580 mil e globo de 250 mil triângulos, para menos de 12 mil) e as texturas ficaram em até 1024 px.
  - Texturas soltas foram ligadas aos modelos, e as imagens foram regravadas sem perfil ICC (o leitor JPEG do Godot recusava).
  - O encaixe é feito por `scripts/world/modelo_prop.gd`, que ajusta o modelo dentro da caixa do móvel, e as cenas são geradas por `tools/props_modelos.py` e `tools/modelos_cena_v54.py`.
  - Onde cada modelo ficou:

    | Lugar | Modelos |
    |---|---|
    | Pátio | lanterna de pedra (tōrō) |
    | Português | livros antigos na mesa do professor; livros em cima das estantes |
    | Matemática | calculadora na mesa; relógio de parede com os ponteiros na hora real do computador |
    | Ciências | bancada de pesquisa com crânio de tigre (o "tigre" é um crânio); frasco e vidrarias nas bancadas; porta de laboratório na parede; aranha que anda entre as bancadas (só ambientação, não ataca) |
    | Geografia | globo antigo sobre a mesinha; estante antiga com livros |
    | Música | piano empoeirado com banquinho; Cantigas de Santa Maria em cima do piano; escrivaninha do compositor com partituras e papel amassado |
    | Saída | os 6 monitores viraram TVs antigas, com a estática na tela |
    | Todas as salas | o armário alto virou o armário antigo |

  - Ficou de fora: a "estante lineare" (.3ds), porque o Blender 5 não tem mais importador de 3DS. Ela pode ser reenviada em .fbx, .obj ou .glb.
- **Tamanho do projeto (desfeito na 5.5):** de 162 MB para 49 MB, já com os modelos.
  - As texturas de parede e chão foram de 2048 px PNG/JPG para 1024 px JPG (~70 MB → 2 MB).
  - As capturas da pasta `docs` foram de PNG para JPG (51 MB → 5 MB).
  - A pasta `docs` agora é ignorada pelo Godot (`docs/.gdignore`), então não entra no jogo exportado.
- Capturas em `docs/capturas/v5_4/`.

## 0b. Versão 5 — pátio, escola japonesa, só dois professores

**Nova ordem:** pátio (acorda) → Português (o Leitor) → Matemática → Ciências → Geografia → Música (o Maestro) → salinha dos monitores no fim do corredor (saída) → final.

- **Pátio a céu aberto** no lugar da antiga 3ª sala (a maior, entre Matemática e Ciências):
  - noite com lua, cerejeira com pétalas no chão e caindo, duas lanternas de pedra (tōrō) acesas;
  - chão de pedra com entulho (tábuas, papéis, poças, carteira tombada) e névoa baixa;
  - fachadas de madeira com janelas em grade e beiral de telhas.
  - Ela acorda **deitada de lado debaixo da cerejeira**. O mapa fica no banco, e o aviso no quadro do pátio. A porta do pátio para o corredor só destranca depois da cena do mapa.
- **Escola japonesa** (pelas referências):
  - corredor com janelas altas em grade e luminárias pendentes;
  - janelas altas nas salas (luar);
  - lambri de madeira escura.
- **Só duas salas com professor:**
  - **Português (o Leitor):** a primeira sala.
  - **Música (o Maestro):** a última sala. A pista barulhenta é o piano; a pergunta é o cadeado do armário de partituras (senha **2343**).
  - Matemática, Ciências e Geografia mantêm pistas, pergunta e porta (fecha atrás dela, abre na resposta certa), mas **sem monstro e sem perseguição**.
- **A saída** virou a salinha no fim do corredor, depois de Música. Ela fica escondida no mapa até Música terminar, e lá estão os monitores.
- **Erro do "já foi examinado":** usar a pergunta antes da hora mostrava "explore os outros elementos" e, na segunda vez, travava em "Você já examinou este objeto".
  - Agora o motivo aparece de novo a cada tentativa (`interaction_router.gd`).
  - A pergunta abre normalmente quando as pistas estão completas.
  - Verificado no teste da história completa.
- **Monstro parado / pouco tempo ativo:**
  - Antes, ele investigava uns 4 s, voltava ao posto e ficava parado.
  - Agora, depois que acorda, ele **caça a Yuko de verdade**: vai atrás da última posição dela a cada 0,6 s.
  - Com ela escondida, ele ronda os arredores do esconderijo.
  - Só se acalma depois de **no mínimo 30 s acordado** e de ela ficar 5 s escondida. Se ela for vista entrando no esconderijo, ele continua indo atrás.
  - No teste: o Leitor andou cerca de 12 m procurando e se acalmou aos ~40 s; o Maestro também cumpre o mínimo de 30 s.
- O roteiro (`ROTEIRO.md`), o mapa (pátio com a cerejeira, nota musical em Música, saída em vermelho) e as navmeshes foram refeitos.

**Versão 5.3 — o Maestro de verdade:**
- `assets/characters/maestro/MaestroRig.glb` entrou no lugar da cápsula, com o script novo `scripts/monsters/monster_animator.gd`. O script é genérico e serve também para o Leitor quando o modelo dele chegar.
- Altura ajustada para 4,2 m, igual ao colisor. O GLB olha para +Z; o modelo é girado para andar para a frente.
- **Animação por estado:**

  | Situação | Animação |
  |---|---|
  | Dormindo no posto | Tocando |
  | Acordando com o barulho | Erro (uma vez; termina assim que ele começa a andar) |
  | Andando / perseguindo | Correndo, no ritmo da velocidade (mais devagar ao andar) |
  | Procurando parado | Atento.longe |
  | Parado depois de desistir | Tocando.longe |
  | Pegou a Yuko | Atacando |

- *Andando.ate.piano* não foi usada: ela gira o corpo 90° dentro do clipe e não serve como passo em loop.
- **Para aparecer na sala escura:** ganhou uma luz fraca e avermelhada na frente do rosto, que anda com ele.
- O posto dele foi para (−15, −170,5), virado para a câmera. Antes ficava de costas, olhando o quadro, e a câmera do jogo cortava a parte de cima dele no fundo da sala.
- A câmera da cena "Maestro desperta" caía dentro do armário novo da parede norte (5.2). Ela foi refeita, e agora um verificador confere que nenhuma câmera de cena fica dentro de móvel.
- Teste novo: `maestro_animacao_test`.
- Capturas em `docs/capturas/v5/maestro/`.

**Correção 5.2 — "mesmo escondida, o monstro a encontra":**
- **Causa:** o professor corre atrás dela o tempo todo. Quando ela se escondia com ele logo atrás, a regra de "viu entrar no esconderijo" valia em qualquer distância; ele sabia onde ela estava e a pegava dentro do móvel.
- **Agora:**
  - Ele só a encontra escondida se estiver **colado nela (até 3,5 m) e olhando** no momento em que ela entra (pega no flagra).
  - Com qualquer folga, esconder-se funciona: ele perde o rastro, ronda o esconderijo, desiste e aparece "ele se acalmou" (mínimo de 30 s).
- **Mais esconderijos:** Português e Música agora têm **4 cada**: a mesa do professor e 3 armários altos (fundo, parede norte e parede sul).
- Teste novo, `esconderijo_test`:
  - nas duas salas, ela se esconde com o professor a 5 m. Ele chega a 1,9 m do móvel, não a encontra e se acalma aos 38–40 s;
  - a 2 m, olhando, ele a pega no flagra;
  - todos os 8 esconderijos funcionam.

**Correção 5.1 — "ela não sai pelo pátio":**
- A porta do pátio para o corredor fica do lado da câmera, que olha do corredor para o pátio. Por isso a porta não aparecia na tela, nem o aviso "E Abrir", e a Yuko parecia bater numa parede invisível.
- Agora a porta **abre sozinha no fim da cena do mapa**, com o aviso "A porta do pátio se abriu sozinha: o corredor fica logo à frente."
- Pelo mesmo motivo, a porta da saída também abre sozinha quando Música termina.
- Teste novo: `saida_patio_test`. A Yuko anda só com as teclas, sem teleporte e sem apertar E, do banco até o corredor e segue até a porta de Português.

## 0a. Versão 4 — ajustes desta rodada

- **Ela acordando:** deitada de bruços, o rosto ficava enterrado no chão. Agora ela começa **deitada de lado, encolhida, virada para a câmera da cena**; apoia no braço, fica de joelhos recuperando o fôlego e levanta.
- **Itens brancos "flutuando":** eram os papéis/livros em cima de um móvel que a câmera deixava transparente (o móvel sumia e o papel ficava). Agora cada objeto de pista fica tão transparente quanto o móvel em que está (`scripts/world/follow_fade.gd`).
- **Móveis sumindo de perto:** o móvel na frente dela ficava 78% transparente (quase invisível). Agora fica **meio transparente (50%)** — continua dando para ver a Yuko, mas o móvel não desaparece.
- **Sem esconderijo na sala onde ela acorda:** o armário saiu da sala inicial.
- **Aviso "E Esconder-se" enorme e de longe:** os esconderijos herdavam a escala dos móveis — a área de interação e o texto ficavam 2–3× maiores. Agora o texto tem tamanho normal (menor que antes) e só aparece **quando ela chega perto** (cerca de 1 m da frente do móvel). Os avisos das pistas também diminuíram e o alcance caiu de 1,3 m para 1,0 m.
- **Móveis 3× maiores** (eram 2×): estante e armário ~6,9 m (quase no teto de 7 m), carteira com tampo a 2,2 m (acima da cabeça dela), mesa do professor 6 m de largura. Quadros/mapas de parede ficam em 2× (em 3× passariam do teto) e, no corredor, armários de alunos e entulho ficam em 2× (em 3× fechariam o corredor de 7 m). As salas foram redesenhadas para caber (menos carteiras, uma estante por parede) e o script continua parando com erro se algo se sobrepõe. Os objetos das pistas cresceram junto (1,5×).
- **Pistas agora são presas ao móvel pelo próprio script** (`R.pin(...)`): se a escala mudar de novo, os pontos se recalculam sozinhos.
- **Câmera:** a lente fica a pelo menos 2,6 m das paredes laterais da sala (onde ficam as estantes altas).
- **Blocos claros soltos em Português:** eram três caixas antigas (`StudentDesk01–03`) que sobraram da cena original dentro da geometria da sala — removidas. A perna da cadeira das carteiras (que em 3× virava um bloco azul-claro) e os livros das estantes (cor de papel) ganharam cores escuras.
- **Brilho dos objetos de pista** bem mais fraco: com brilho forte o papel aparecia "flutuando" no escuro quando o móvel em volta não estava iluminado.

## 0. Versão 3

**1. Móveis no lugar.** As caixas brancas soltas (marcadores de pista) sumiram. Cada pista agora é um objeto pequeno preso a um móvel de verdade: papel em cima da mesa, livro na estante, cadeado na gaveta, frascos na prateleira, foto na parede. Todos os móveis foram reposicionados por `tools/layout_moveis.py`, que confere sozinho (e para com erro) se algum móvel invade outro, sai da sala, bloqueia a porta ou se o ponto onde a Yuko fica para pegar a pista cai dentro de um móvel. Resultado: 41 móveis, 0 sobreposições, 24 pontos de pista.

**2. Proporção Little Nightmares.** (Versão 3: 2×; na versão 4 passou para **3×**, ver 0a.) A Yuko continua com 1,70 m. Estantes e armários passam de 4 m; a carteira fica na altura do peito dela. Os navmeshes foram refeitos com os móveis novos.

**3. Ela acordando.** Antes o corpo inteiro girava como uma tábua. Agora (`YukoAnimator.wake_up`) ela começa **de bruços**, apoia as mãos (pose agachada inclinada), fica de cócoras recuperando o fôlego (balança de leve) e só então fica de pé, misturando para a respiração parada. As poses e tempos ficam na tabela `WAKE_KEYS`, fácil de ajustar. As carteiras da sala inicial saíram do meio para ela acordar à vista da câmera.

**4. A voz virou o mapa.** Não existe mais telefone na história (a tecla T foi desligada e saiu das configurações). Tudo o que a voz dizia agora **aparece escrito no mapa**, em letra de mão que não é da Yuko, como se alguém escrevesse do outro lado:
- na cena do mapa, o mapa abre na tela e as frases se escrevem sozinhas, letra por letra (a tinta fica mais escura enquanto "seca");
- com o mapa fechado, a frase aparece num pedaço de pergaminho rasgado no alto da tela e o aviso "[M] Mapa · algo novo foi escrito" pisca;
- no final, o mapa revela quem escrevia ("OS TESTES ACABARAM, PARTICIPANTE 07").

O mapa foi redesenhado no estilo do exemplo (mapa de tabuleiro): pergaminho com borda queimada e manchas, moldura dupla vermelha, cartela de título "A ESCOLA", rosa dos ventos, salas a nanquim com ícone de cada matéria (livro, transferidor, frasco, globo) e selo vermelho numerado, salas concluídas riscadas com X vermelho, objetivo circulado à mão e os escritos embaixo, ligados à sala por um fio de tinta. Fontes livres (OFL) incluídas em `assets/fonts/`: IM Fell English (títulos de mapa antigo) e Caveat (letra de mão).

**5. Fluxo de cada sala** (exatamente o fluxograma pedido; `StoryDirector`, seção "fluxo da sala"):

1. Ela entra → cena de entrada → **a porta fecha e tranca atrás dela** (assim que ela sai do vão).
2. Procura as pistas nas paredes, estantes e armários.
3. **Uma pista específica faz barulho** e acorda o professor: o livro preso que derruba a pilha (Português), a régua de metal que despenca (Matemática), os frascos que tilintam e quebram (Ciências), o globo que range (Geografia). Cena do despertar + escrito "ESCONDA-SE.".
4. Ela se esconde. Quando o professor volta ao posto sem encontrá-la, ele "dorme" de novo e aparece o aviso **"ELE SE ACALMOU."** (escrito no mapa + objetivo + checkpoint).
5. A pergunta fica na **última pista**, e só abre com o professor dormindo ("Agora não — ele está te procurando").
6. Resposta certa → **a porta abre sozinha** e o professor acorda de novo → "CORRA.".
7. Quando ela sai, **a porta fecha atrás dela**, o professor volta ao posto e o mapa escreve o recado de saída. A próxima porta destranca.

**Uma pergunta por sala** (a sala inteira leva a ela; a pista barulhenta é obrigatória para responder):

| Sala | Pistas (★ = barulhenta) | Pergunta (última pista) | Resposta |
|---|---|---|---|
| Português | quadro, caderno, ★ livro preso | cadeado da gaveta: classes de palavras da frase | 2212 |
| Matemática | quadro, prova, transferidor, ★ comanda (régua cai) | cofre de provas: suco, lanche e menor ângulo | 5450 |
| Ciências | cartaz de pH, caderno, ★ frascos | lacre ácido do armário | leite de magnésia |
| Geografia | rosa dos ventos, plano de evacuação, ★ globo | mapa da cidade: ponto de encontro | B5 |

**6. Saída.** É a 5ª porta do corredor, depois de Geografia, com o mesmo tipo de sala das outras (a antiga Sala de Monitoramento, com os monitores, foi trazida para ela; o subsolo foi removido). No mapa ela **só aparece quando Geografia termina**, junto com a porta destrancada.

## 1. Bug da câmera ao entrar nas salas

**O que acontecia (vídeo `IMG_7855.mov`)**

Ao passar da sala inicial para o corredor e entrar numa sala, apareciam blocos escuros e barras verticais (pedaços do corredor) na frente da Yuko.

**Causas encontradas** (reproduzidas no Godot com o mesmo trajeto do vídeo):

1. O corte só escondia a parede que cruzava o raio entre a lente e a Yuko. Pedaços do corredor e das paredes vizinhas sobravam nas bordas do quadro.
2. Dentro da sala, a câmera seguia a Yuko para além das paredes laterais e mostrava o vazio de fora da maquete.
3. As folhas da porta da sala inicial abrem viradas para a lente e viravam um bloco preto no primeiro plano.
4. Armários-esconderijo e objetos sem colisão não ficavam transparentes quando cobriam a Yuko.
5. Havia uma zona de câmera duplicada no laboratório (`Room1Camera_A_Original`) com outro ângulo. Ela fazia o enquadramento pular.

**Correção: cada cômodo virou um "palco" de maquete** (`scripts/camera_controller.gd`, seção "palco")

- **Corte de palco:** tudo o que fica inteiro entre a lente e a frente do cômodo some com um fade de 0,22 s: corredor, parede da frente, armários do corredor, portas. O chão fica, senão a base do quadro vira um buraco.
- **Quadro preso no cômodo:** dentro de uma sala, a mira não passa das paredes laterais. A profundidade acompanha a Yuko pela metade (`stage_depth_follow`), no estilo diorama.
- **Palco atual:** é a zona que contém a Yuko, com histerese de 0,6 m na soleira. Não alterna mais no meio da porta.
- **Transparência pela tela:** móveis, portas e esconderijos que cobrem a Yuko na tela ficam translúcidos, mesmo sem colisão.
- **Troca de enquadramento mais curta:** 1,0 s em vez de 1,6 s, suavização 0,7 s em vez de 1,25 s (pedido: "a troca me incomoda um pouco").
- **Configuração por zona** (`scripts/camera_zone.gd`): `stage_mode` (AUTO / ROOM / CORRIDOR) e `stage_side_margin`.

Capturas de antes e depois: `docs/capturas/historia/camera_antes.jpg` e `camera_depois.jpg` (mesmo trajeto do vídeo). As outras salas, o corredor 5, a rampa e o subsolo estão em `camera_sala*.jpg` e `camera_corredor5_subsolo.jpg`.

## 2. Quatro salas

| Porta no corredor | Sala | Monstro | Como desperta |
|---|---|---|---|
| 1ª | Português (`room_1`) | O Leitor | Livro preso derruba a pilha |
| 2ª | Matemática (`room_2`) | O Ângulo | Régua de metal despenca |
| — | Artes (antiga) | — | Removida; a porta virou parede |
| 3ª | Ciências (`room_3`) | O Polvo | Frascos tilintam e quebram |
| 4ª | Geografia (`room_4`) | O Cartógrafo | Globo enferrujado range |
| 5ª | Saída (`sala_saida`, monitores) | — | Destranca e aparece no mapa depois de Geografia |

- **Removidas:** Artes, Música, os monstros Pintora e Maestro, as zonas de câmera, os volumes, os navmeshes e as portas delas. As portas viraram parede.
- **Móveis:** refeitos na versão 3 (seção 0), em escala 2×.
- **Navmeshes:** foram refeitos (`tools/bake_all_navmesh.gd`).

## 3. A história como um filme

**Novos sistemas** (pasta `scripts/story/`)

- **`StoryDirector`:** escuta o `NarrativeManager` e executa uma coisa de cada vez: cenas, documentos e efeitos. Nada se sobrepõe ao telefone, ao enigma ou à tela de captura.
- **`CutscenePlayer`:**
  - câmera própria e barras pretas;
  - legendas com o nome de quem fala (falas do "Mapa" não são legenda: se escrevem no mapa);
  - cartelas de título e fades;
  - poses da Yuko (deitada / de pé).
  - O jogo pausa durante a cena, e **não dá para pular** (pergunta 13).
- **`DocumentUI`:** pistas e documentos aparecem como papel na tela. Depois de alguns documentos, a Yuko comenta em legenda.
- **Luz de cinema:** uma luz suave fica presa à câmera da cena, e outra fica sobre o que está em foco. Sem elas as salas e os monstros escuros sumiam.
- **`MapUI` (tecla M):**
  - mostra onde a Yuko está, o próximo objetivo circulado e as salas concluídas riscadas;
  - guarda os escritos (é a "voz" do jogo);
  - a saída só aparece depois de Geografia.

**Eventos e efeitos**

- **Tipo de evento novo:** `CUTSCENE`. O roteiro de cada cena fica em `data/story.json`.
- **Efeito novo de objeto:** `open_puzzle`. O enigma agora abre no mecanismo da sala (cadeado, cofre, transferidor) e não mais sozinho.

**A "voz"** (versão 3): não há telefone. O que ela diria aparece escrito no mapa (seção 0, item 4).

**Roteiro completo**

Para ler, está em **`ROTEIRO.md`**, gerado automaticamente. Para editar, está em `tools/story_content.py`, junto com os enigmas e as posições dos objetos. Para mudar uma fala, um enigma ou uma posição, edite esse arquivo e rode `python3 tools/build_story.py`. O script regera `data/game_data.json`, `data/story.json` e o nó `Gameplay` da cena. Depois, rode `python3 tools/export_roteiro.py` para atualizar o `ROTEIRO.md`.

## 4. Perguntas (ensino fundamental II)

Uma por sala (tabela da seção 0). Cada resposta certa mostra a explicação da solução. Cada sala tem também um documento de história: lista de chamada, diário, relatório do Projeto Crisálida e foto da turma.

## 5. Checkpoints (pergunta 17: último checkpoint)

Checkpoints gravados:

- na abertura e depois do mapa;
- ao entrar em cada sala e quando a porta fecha atrás dela;
- quando aparece "ele se acalmou" (só depois que ela sai do esconderijo);
- na conclusão de cada sala (porta fechada, professor dormindo);
- na entrada da saída.

O estado do fluxo da sala (fase, porta trancada pelo roteiro, escritos do mapa) vai junto no checkpoint. Quando a Yuko é pega, "Tentar do checkpoint" recarrega a cena no último ponto gravado. As cenas já vistas não repetem.

## 6. Personagem animada: Yuko (`YukoRig.glb`)

A cápsula provisória da protagonista foi trocada pelo modelo animado. As cenas, a câmera, o mapa, o esconderijo e o checkpoint continuam iguais.

**Arquivos novos**

| Arquivo | O que é |
|---|---|
| `assets/characters/yuko/YukoRig.glb` | Modelo (≈1,70 m, pés na origem, olhando para +Z), esqueleto de 23 ossos e 6 animações |
| `scenes/player/yuko_model.tscn` | O modelo com o script `scripts/player/yuko_animator.gd` |
| `scenes/player/player.tscn` | O nó `Visual` virou um Node3D com a Yuko dentro. A colisão não mudou |

**Animações usadas** (recortadas em loops perfeitos no próprio jogo)

| Estado | Animação do GLB | Ciclo | Velocidade natural do passo |
|---|---|---|---|
| Parada (respiração) | `"Parada"` | 2,5 s | — |
| Andando | `Andandoofc` | 1,2 s, a partir de 0,133 s | ≈1,4 m/s |
| Correndo | `Correndoofc` | 0,8 s, a partir de 0,233 s | ≈2,8 m/s |
| Agachada (andando) | `Agachada` | 2,4 s, a partir de 0,033 s | ≈1,25 m/s |
| Agachada (parada) | `Agachada` | segura a pose | — |

**Por que recortar os loops:** no GLB, o primeiro quadro não faz parte do ciclo e o fim não encaixa no começo. Tocadas inteiras, as animações dariam um "pulo" a cada 4,9 s.

**Animações não usadas:**

- `Andando.lan.ofc` é idêntica a `Andandoofc`.
- `Andando.001` tem só 1 s e não fecha ciclo.

**Como a animação acompanha o jogo**

- **Velocidade:** a animação toca na proporção da velocidade real da Yuko, para o pé não patinar. A 3,5 m/s, a caminhada toca cerca de 2,5× mais rápido que o original. Se quiserem um passo mais calmo, no estilo Little Nightmares, basta baixar `walking_speed` no `player.gd` (por exemplo, para 2,2).
- **Transição:** 0,18 s entre estados.
- **Direção:** ela vira para onde anda.
- **Esconderijo:** o modelo some.
- **Jogo pausado** (cena de filme, enigma, documento, pausa): ela respira parada, em vez de congelar no meio do passo.
- **Abertura:** ela começa deitada no chão e se levanta antes de a cena terminar.

**Teste novo:** `tests/yuko_animacao_test.gd`, com 20 verificações:

- os 4 loops fecham sem pulo;
- parada, andar, correr e agachar (andando e parado);
- a velocidade da animação acompanha a dela;
- ela vira para onde anda;
- respira com o jogo pausado;
- some no esconderijo.

As capturas estão em `docs/capturas/yuko/`.

**Corrigido junto:** o aviso "AGACHADA" do HUD aparecia com uma letra por linha, por causa da quebra de linha automática.

## Testes (Godot 4.7.1 headless, `--fixed-fps 60`)

| Teste | Resultado |
|---|---|
| `patio_visivel_test` (5.6: cerejeira, janelas, lanternas, lua e névoa visíveis na abertura; o pátio dorme longe e acorda de novo) | 17/17 |
| `fluidez_test` (5.4: a 144 Hz com física a 60 Hz, nenhum quadro parado; rodar sem --fixed-fps) | 4/4 |
| `maestro_animacao_test` (5.3: modelo, altura, direção e animação de cada estado) | 10/10 |
| `esconderijo_test` (5.2/5.4: escondida embaixo da mesa com o professor a 5 m ele não a encontra e se acalma; no flagra a 2 m, sim) | 18/18 |
| `saida_patio_test` (5.1: anda do pátio até o corredor só com as teclas; a porta abre sozinha depois do mapa) | 5/5 |
| `historia_completa_test` (v5: pátio → 5 salas → saída; porta fecha/abre em todas; professor só em Português e Música, caçando ≥ 30 s e se mexendo; erro do "já examinou" conferido; 23 papéis) | 176/176 |
| `checkpoint_historia_test` (pega com o professor acordado → volta com a porta trancada e ele dormindo) | 16/16 |
| `fluxo_menu_test` (mapa no lugar do telefone) | 35/35 |
| `camera_occlusion_test` | sem bloqueios |
| `camera_behavior_test` | 10/10 |
| `legado_orbita/camera_geometry_sweep_test` (câmera de órbita, não usada no jogo) | encosta nas estantes 3× — sem efeito no jogo |
| `moveis_colisao_test` (medida em metros reais com os móveis 2×) | 3/3 |
| `player_wall_movement_test` | 20/20 |
| `yuko_animacao_test` | 20/20 |

- **Testes do layout antigo:** foram para `tests/legado_6_salas/`. Eles testavam as 6 salas, o Polvo na Room 1 e os enigmas de teste. O motivo está no README da pasta.
- **`tests/test_input.gd`:** `fade_target` agora olha a malha das peças de porta (verga), e não o corpo de colisão, que é sempre invisível.

**Capturas** (renderização real) em `docs/capturas/historia/`:

- versão 5 em `docs/capturas/v5/`: Yuko acordando no pátio, aviso do pátio, cena do mapa, corredor com janelas, Português (Leitor desperta e procurando), Música (Maestro), mapa com a saída, monitores, final e o mapa novo;

- versão 3 em `docs/capturas/v3/`: Yuko acordando (4 quadros), mapa escrevendo, mapa com a saída, porta fechando + escrito, móveis 2× em cada sala, pista barulhenta, despertar, "esconda-se", "ele se acalmou", monitores, final;
- câmera antes e depois, e a caminhada por cada sala.

## Também corrigido no caminho

- **Rotinas novas seguras na troca de cena:** se a cena muda (voltar ao menu, recarregar o checkpoint) com uma cena de filme ou um documento aberto, as rotinas encerram sem erro.
- **Avisos que não cobrem as cenas:** objetos que disparam uma cena ou um documento não mostram mais o aviso de interação por cima dela.
- **Pontos de interação:** ficam no chão livre, na frente do móvel, onde a Yuko para; o marcador visual fica no móvel.
- **Esconder não conclui a sala:** escondida, a Yuko ficava sem colisão e "saía" da sala; com a resposta certa a sala se concluía na hora. Agora a sala atual não muda enquanto ela está escondida.
- **Quadros de parede sem colisão:** a câmera encostava no mapa da cidade (2×) na parede norte de Geografia; quadros/mapas de parede não têm mais corpo físico e o mapa da cidade foi para a parede sul.
- **Voz falsa do Leitor:** o Leitor imita vozes ("Yuko? Sou eu... pode sair") quando investiga um som — é o único que "fala" fora das cenas.
- **Teclas no começo:** um aviso mostra as teclas logo depois da abertura.

## Pendências conhecidas

- **Modelos dos monstros:** continuam cápsulas.
- **Levantar do chão:** é procedural (poses do GLB inclinadas). Uma animação própria "levantando" no `YukoRig.glb` fica ainda melhor; basta trocar `wake_up`.
- **Áudio:** não há sons. O barulho das pistas barulhentas está no texto da pista; um som de livros caindo/vidro/rangido encaixa no efeito `activate_monster`.
- **Teste em hardware real:** as capturas foram feitas com renderização por software. Vale conferir o brilho das cenas num PC com placa de vídeo.

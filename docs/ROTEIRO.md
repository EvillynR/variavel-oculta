# Roteiro — a história de Yuko

Gerado de `tools/story_content.py` (edite lá e rode `python3 tools/build_story.py` e `python3 tools/export_roteiro.py`).

**Ordem do jogo:** acorda no pátio (escola japonesa, à noite, debaixo da cerejeira) → mapa (o que estava escrito nele começa a mudar) → Português → Matemática → Ciências → Geografia → Música → a saída (salinha no fim do corredor) → final.

**Não há voz.** Tudo o que "alguém" diz aparece **escrito no mapa** (em letra que não é da Yuko), marcado abaixo como **Mapa**. Com o mapa fechado, a frase surge num pedaço de pergaminho no alto da tela.

**Só duas salas têm professor: Português (a primeira) e Música (a última).** Nelas: entra → a porta fecha e tranca atrás dela → procura pistas → **uma pista faz barulho** e acorda o professor → ele caça a Yuko por **pelo menos 30 segundos** → ela se esconde → aparece escrito *ele se acalmou* → responde a pergunta da última pista → a porta abre sozinha e o professor acorda de novo → ela foge → ao sair, a porta fecha.

**Matemática, Ciências e Geografia** não têm professor nem perseguição: entra → a porta fecha atrás dela → pistas → pergunta → a porta abre → ao sair, a porta fecha.


## 1. O pátio onde Yuko acorda


**Cena: Abertura** _(gatilho: MANUAL)_

> _(Yuko deitada no chão)_
> **[CARTELA]** TRÊS DIAS DEPOIS DO ACIDENTE
> **Yuko:** Frio... as pedras estão molhadas.
> **Yuko:** Onde... onde eu estou?
> _(Yuko se levanta)_
> **Yuko:** Uma cerejeira... um pátio. É uma escola.
> **Yuko:** Eu não lembro de ter vindo para cá.
> **Yuko:** Tem alguma coisa em cima daquele banco.

Objetivo na tela: _Examine o banco do pátio._

Aviso no quadro do pátio (opcional): "Yuko, amanhã é a AVALIAÇÃO ESPECIAL. Não falte. Quem faltar perde a vaga no programa." — Coordenação

**Cena: O mapa** _(gatilho: INTERACTION patio.mapa)_

> **Yuko:** Um mapa da escola... alguém marcou cinco salas.
> **Yuko:** Português, Matemática, Ciências, Geografia... Música.
> _(o mapa abre na tela)_
> **Mapa** _(escreve-se sozinho)_: NÃO FAÇA BARULHO. / ELES AINDA NÃO SABEM QUE VOCÊ ACORDOU.
> **Yuko:** Isso... não estava escrito aqui antes. A tinta ainda está molhada.
> **Mapa** _(escreve-se sozinho)_: AS PORTAS SÓ ABREM NA ORDEM DO MAPA.
> **Mapa** _(escreve-se sozinho)_: EM CADA SALA HÁ UMA PERGUNTA. / EM DUAS DELAS HÁ ALGUÉM.
> **Yuko:** Alguém? Quem está escrevendo isso?
> **Mapa** _(escreve-se sozinho)_: SE OUVIR PASSOS, ESCONDA-SE. / EU VOU TE AJUDAR A SAIR DAÍ.

Objetivo na tela: _Vá até a Sala de Português (1ª porta do corredor). [M] abre o mapa._

## 2. Sala de Português — O Leitor


**Cena: A Leitora** _(gatilho: ROOM_ENTERED room_1)_

> **A Leitora:** ...a menina... assustada... abriu a porta... escura...
> **Yuko:** Ela não para de escrever. E fala sozinha.

**Pistas** (na ordem que o jogador costuma achar):

- A última lição no quadro — _Ler o quadro_
- Caderno da professora — _Pegar o caderno_
- **[PISTA BARULHENTA]** Livro de gramática — _Puxar o livro_

**Cena: A Leitora desperta** _(gatilho: MONSTER_STATE reader)_

> **A Leitora:** Quem está... fora da carteira?

**Enigma — A gaveta da professora** (senha de 4 dígitos)

A gaveta da mesa tem um cadeado de 4 números.  
Conte as classes de palavras da frase do caderno, na ordem do quadro  
(SUBSTANTIVOS · ADJETIVOS · VERBOS · ARTIGOS), e digite os 4 números.

Resposta: **2212**

Pistas: _A última lição no quadro_, _Caderno da professora_, _Livro de gramática_

Explicação mostrada ao acertar: "A menina assustada abriu a porta escura": substantivos menina e porta (2); adjetivos assustada e escura (2); verbo abriu (1); artigos A e a (2). Senha 2212.

**Documento — Lista de chamada — 3º ano B (2019)**

> 01. Ana Beatriz Moura
> 02. Caio Ferraz
> 03. Davi Lins
> 04. Elisa Prado
> 05. Igor Mendes
> 06. Laura Siqueira
> 07. Yuko Tanaka ............ TRANSFERIDA PARA O PROGRAMA
> 08. Mateus Rocha

_Yuko comenta:_ "Esse... é o meu nome. Eu estudei aqui?"

**Escritos no mapa nesta sala**

- _ao entrar (a porta fecha atrás dela):_ ELA QUASE NÃO ENXERGA. / MAS OUVE TUDO.
- _quando o professor acorda:_ ESCONDA-SE.
- _quando ele se acalma:_ ELA SE ACALMOU. / TERMINE O QUE COMEÇOU.
- _resposta certa: a porta abre:_ A PORTA ESTÁ ABERTA. / CORRA.
- _ao sair (a porta fecha):_ BOA MENINA. / A PRÓXIMA PORTA JÁ ESTÁ ABERTA.

## 3. Sala de Matemática — sem professor


**Cena: Matemática** _(gatilho: ROOM_ENTERED room_2)_

> **Yuko:** Ninguém... mas o giz ainda está no chão, quebrado.

**Pistas** (na ordem que o jogador costuma achar):

- Quadro: ângulos — _Ler o quadro_
- Prova esquecida — _Ler a prova_
- Comanda da cantina — _Puxar o papel_
- Bilhete no transferidor — _Ler o bilhete_

**Enigma — O cofre de provas** (senha de 4 dígitos)

O cofre de provas pede uma senha numérica.  
Use a prova, a comanda da cantina e o bilhete do transferidor.

Resposta: **5450**

Pistas: _Quadro: ângulos_, _Prova esquecida_, _Comanda da cantina_, _Bilhete no transferidor_

Explicação mostrada ao acertar: Ângulos: x + y = 180 e y = 2x + 30, então x = 50°. Cantina: 3s + 2l = 23 e s + 2l = 13; subtraindo, 2s = 10, s = 5 e l = 4. Senha 5 | 4 | 50 = 5450.

**Documento — Diário do Prof. Bruno Sá**

> Dia 3 — A direção mandou todos os professores tomarem a "vitamina C-7". Disseram que é para o cansaço.
> Dia 9 — Meus dedos estalam quando escrevo no quadro. Contei: agora são quatro articulações em cada dedo.
> Dia 12 — Os alunos do 3º B não voltaram do "programa". A diretora diz que foram transferidos.

_Yuko comenta:_ "Vitamina C-7... fizeram isso com os próprios professores."

**Escritos no mapa nesta sala**

- _ao entrar (a porta fecha atrás dela):_ NÃO HÁ NINGUÉM AQUI. / NÃO SE ACOSTUME.
- _resposta certa: a porta abre:_ A PORTA ABRIU.
- _ao sair (a porta fecha):_ FALTAM TRÊS. / EU NUNCA ESTIVE NESSA ESCOLA.

## 4. Sala de Ciências — sem professor


**Cena: Ciências** _(gatilho: ROOM_ENTERED room_3)_

> **Yuko:** Fórmulas até o teto... alguém escreveu isso por dias.

**Pistas** (na ordem que o jogador costuma achar):

- Cartaz: escala de pH — _Ler o cartaz_
- Caderno de laboratório — _Ler o caderno_
- Prateleira de frascos — _Pegar os frascos_

**Enigma — O lacre ácido** (múltipla escolha)

O armário de reagentes está lacrado com um gel ácido (pH 2).  
Qual dos frascos que sobraram neutraliza o lacre?

- Suco de limão (pH 2)
- Vinagre (pH 3)
- Água destilada (pH 7)
- Leite de magnésia (pH 10)  ← **correta**

Pistas: _Cartaz: escala de pH_, _Caderno de laboratório_, _Prateleira de frascos_

Explicação mostrada ao acertar: Para neutralizar um ácido é preciso uma BASE. O leite de magnésia (pH 10) é básico.

**Documento — Projeto CRISÁLIDA — Relatório nº 3**

> Sujeito: Profª Marta Reis (Ciências). Dose: 12 ml de C-7.
> Resultado: duplicação dos membros superiores. Pernas atrofiadas.
> Comportamento: continua "dando aula". Escreve fórmulas por horas seguidas.
> Próxima etapa: observar a reação da PARTICIPANTE 07 ao ambiente. — O Observador

_Yuko comenta:_ "Participante 07... sou eu. Alguém está me observando."

**Escritos no mapa nesta sala**

- _ao entrar (a porta fecha atrás dela):_ NÃO TOQUE NOS FRASCOS SEM PENSAR.
- _resposta certa: a porta abre:_ A PORTA ABRIU.
- _ao sair (a porta fecha):_ FALTAM DUAS.

## 5. Sala de Geografia — sem professor


**Cena: Geografia** _(gatilho: ROOM_ENTERED room_4)_

> **Yuko:** Mapas riscados... todas as rotas terminam no mesmo lugar.

**Pistas** (na ordem que o jogador costuma achar):

- Rosa dos ventos — _Examinar o chão_
- Plano de evacuação — _Ler o plano_
- Etiqueta embaixo do globo — _Girar o globo_

**Enigma — O ponto de encontro** (múltipla escolha)

O mapa da cidade ocupa a parede. Alguém riscou a rota de evacuação até a metade.  
Em qual quadrado fica o ponto de encontro dos alunos?

- F5
- B5  ← **correta**
- D5
- B1

Pistas: _Rosa dos ventos_, _Plano de evacuação_, _Etiqueta embaixo do globo_

Explicação mostrada ao acertar: De D2, 3 quadras para o sul chegam à linha 5 (D5); 2 quadras para o oeste chegam à coluna B. Ponto de encontro: B5.

**Documento — Foto de turma — 3º B, 2019**

> Na segunda fila, uma garota de cabelo curto segura uma plaquinha: "Nº 07".
> Atrás da foto, à caneta: "Participantes selecionados para a Fase 2."

_Yuko comenta:_ "Sou eu nessa foto... por que eu não lembro de nada disso?"

**Escritos no mapa nesta sala**

- _ao entrar (a porta fecha atrás dela):_ DESCUBRA PARA ONDE LEVARAM OS ALUNOS.
- _resposta certa: a porta abre:_ A PORTA ABRIU.
- _ao sair (a porta fecha):_ SÓ FALTA UMA. / A ÚLTIMA TEM DONO.

## 6. Sala de Música — O Maestro


**Cena: O Maestro** _(gatilho: ROOM_ENTERED room_5)_

> **O Maestro:** (os dedos dele tocam no ar um piano que não existe)
> **Yuko:** Ele não tem olhos... só escuta.

**Pistas** (na ordem que o jogador costuma achar):

- A lousa de música — _Ler a lousa_
- Partitura na estante — _Ler a partitura_
- Bilhete na estante de partituras — _Ler o bilhete_
- A melodia do Maestro — _aparece sozinha quando o Maestro termina de tocar (sem números)_

**O enigma da melodia** (configurável em `MUSIC_SEQUENCES`): com as pistas lidas, ela aperta E no piano. O Maestro se senta e toca 4 notas, uma de cada vez; cada nota aparece na lousa com o número dela e some. Depois ele para, observa e acorda: ela se esconde, guarda a melodia na cabeça e, com ele calmo, digita no teclado ao lado da porta. Sequência: Dó = 3, Mi = 7, Si = 8, Ré = 4 → senha **3784**. Errou: som desafinado, o Maestro grita e caça de novo (captura = volta ao checkpoint); dá para pedir a melodia de novo no piano (ele acorda outra vez).


**Cena: A melodia do Maestro** _(tocada pelo diretor; pode repetir)_

> _(a tela escurece)_
> **O Maestro:** (ele se senta ao piano. Os dedos compridos procuram as teclas.)
> **Yuko:** Ele vai tocar... e escrever na lousa. Uma vez só.
> _(as notas aparecem uma a uma na lousa, cada uma com o seu número e o seu som, e somem)_
> **O Maestro:** (as mãos param no ar. A cabeça gira, devagar, para onde você está.)
> **O Maestro:** ...Agora é a sua vez. Sem desafinar.

**Cena: Desafinado** _(tocada pelo diretor; pode repetir)_

> **O Maestro:** DESAFINADO!
> **O Maestro:** (todas as cordas do piano rangem ao mesmo tempo)

**Enigma — O teclado da porta** (senha de 4 dígitos)

Um teclado numérico ao lado da porta, coberto de pó de giz.  
Digite a melodia do Maestro: o NÚMERO de cada nota, na ORDEM em que ele tocou.

Resposta: **3784**

Pistas: _A lousa de música_, _Partitura na estante_, _Bilhete na estante de partituras_, _A melodia do Maestro_

Explicação mostrada ao acertar: Ele tocou Dó (3), Mi (7), Si (8), Ré (4). Na ordem: 3784.

**Documento — Programa do recital — 3º B (2019)**

> RECITAL DE ENCERRAMENTO — regência: Prof. Hélio Amaral
> 1. Hino da escola (coro)
> 2. Noturno nº 2 — ao piano: YUKO TANAKA (nº 07)
> Escrito à mão, embaixo: "Cancelado. Os participantes da Fase 2 não podem se apresentar."

_Yuko comenta:_ "Eu tocava piano? ...minhas mãos lembram. Eu não."

**Escritos no mapa nesta sala**

- _ao entrar (a porta fecha atrás dela):_ ELE NÃO TEM OLHOS. / SÓ OUVIDOS.
- _quando o professor acorda:_ ELE TOCOU. AGORA ESCUTA. / ESCONDA-SE.
- _quando ele se acalma:_ O SILÊNCIO O ACALMOU. / LEMBRA DA MELODIA?
- _resposta certa: a porta abre:_ CORRA. NÃO OLHE PARA TRÁS.
- _ao sair (a porta fecha):_ A SAÍDA FICA NO FIM DO CORREDOR. / EU ABRI PARA VOCÊ.

## 7. A saída (salinha dos monitores, no fim do corredor)

Aparece no mapa e destranca só quando Música termina.

**Cena: Os monitores** _(gatilho: ROOM_ENTERED sala_saida)_

> **Yuko:** Monitores... são as salas. Português... Matemática... Ciências... Geografia... Música.
> **Yuko:** E esse aqui... é o pátio onde eu acordei.
> **Yuko:** O horário da gravação: 02:14. Eu só acordei de manhã...
> **Yuko:** Alguém estava me olhando antes de eu acordar.

Objetivo na tela: _Leia a ficha em cima da mesa._

**Cena: Final** _(gatilho: INTERACTION sala_saida.ficha)_

> **Ficha:** PROJETO CRISÁLIDA — PARTICIPANTE 07: Yuko Tanaka. Ex-aluna, turma de 2019. Fase 2: CONCLUÍDA. Status: em observação.
> **Yuko:** Ex-aluna... Fase 2... o que fizeram comigo?
> **Yuko:** O mapa... está escrevendo de novo.
> _(o mapa abre na tela)_
> **Mapa** _(escreve-se sozinho)_: PARABÉNS. VOCÊ CHEGOU ATÉ AQUI.
> **Yuko:** Você disse que ia me ajudar a escapar!
> **Mapa** _(escreve-se sozinho)_: NÃO. EU DISSE QUE IA TE AJUDAR A SAIR DAÍ. / DAQUELE PÁTIO.
> **Mapa** _(escreve-se sozinho)_: E VOCÊ SAIU. EXATAMENTE COMO PLANEJADO.
> **Mapa** _(escreve-se sozinho)_: OS TESTES ACABARAM, PARTICIPANTE 07. / AGORA COMEÇA A PARTE INTERESSANTE.
> **Yuko:** Esse monitor... sou eu. De costas. Agora.
> _(a tela escurece)_
> **[CARTELA]** CONTINUA...

Tela final: **FIM DO CAPÍTULO 1** → menu principal.

